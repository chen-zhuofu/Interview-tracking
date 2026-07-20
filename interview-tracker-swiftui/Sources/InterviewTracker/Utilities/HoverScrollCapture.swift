import AppKit
import SwiftUI

// MARK: - Kill NSScrollView scrollers (not just hide indicators)

/// Walks up to the enclosing `NSScrollView` and turns scrollers off so layout
/// never reserves gutter space (avoids left/right jitter).
final class ScrollViewScrollerKillerView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        killScrollers()
    }

    override func layout() {
        super.layout()
        killScrollers()
    }

    func killScrollers() {
        var node: NSView? = self
        while let current = node {
            if let scroll = current as? NSScrollView {
                scroll.hasVerticalScroller = false
                scroll.hasHorizontalScroller = false
                scroll.autohidesScrollers = true
                scroll.scrollerStyle = .overlay
                scroll.verticalScroller?.isHidden = true
                scroll.horizontalScroller?.isHidden = true
                scroll.verticalScroller?.alphaValue = 0
                scroll.horizontalScroller?.alphaValue = 0
                scroll.verticalScroller?.controlSize = .mini
                scroll.horizontalScroller?.controlSize = .mini
                // Prevent scroller from reserving layout gutter.
                scroll.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
                return
            }
            node = current.superview
        }
        // Also search descendants once attached under SwiftUI hosting.
        for sub in subviews {
            findAndKill(in: sub)
        }
    }

    private func findAndKill(in view: NSView) {
        if let scroll = view as? NSScrollView {
            scroll.hasVerticalScroller = false
            scroll.hasHorizontalScroller = false
            scroll.autohidesScrollers = true
            scroll.verticalScroller?.isHidden = true
            scroll.horizontalScroller?.isHidden = true
            return
        }
        for child in view.subviews {
            findAndKill(in: child)
        }
    }
}

struct ScrollViewScrollerKiller: NSViewRepresentable {
    func makeNSView(context: Context) -> ScrollViewScrollerKillerView {
        ScrollViewScrollerKillerView()
    }

    func updateNSView(_ nsView: ScrollViewScrollerKillerView, context: Context) {
        nsView.killScrollers()
    }
}

// MARK: - Click outside a view’s bounds

final class OutsideClickMonitorView: NSView {
    var isEnabled = false
    var onOutsideClick: (() -> Void)?
    private var monitor: Any?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshMonitor()
    }

    override func viewDidHide() {
        super.viewDidHide()
        removeMonitor()
    }

    func refreshMonitor() {
        if isEnabled, window != nil {
            installMonitor()
        } else {
            removeMonitor()
        }
    }

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self, self.isEnabled, let window = self.window else { return event }
            guard event.window == window else { return event }

            let loc = event.locationInWindow
            let local = self.convert(loc, from: nil)
            if !self.bounds.contains(local) {
                DispatchQueue.main.async {
                    self.onOutsideClick?()
                }
            }
            return event
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

struct OutsideClickMonitor: NSViewRepresentable {
    var isEnabled: Bool
    var onOutsideClick: () -> Void

    func makeNSView(context: Context) -> OutsideClickMonitorView {
        let view = OutsideClickMonitorView()
        view.isEnabled = isEnabled
        view.onOutsideClick = onOutsideClick
        view.refreshMonitor()
        return view
    }

    func updateNSView(_ nsView: OutsideClickMonitorView, context: Context) {
        nsView.isEnabled = isEnabled
        nsView.onOutsideClick = onOutsideClick
        nsView.refreshMonitor()
    }
}

// MARK: - Scroll isolation (consume wheel over a region)

/// Blocks parent/sibling ScrollView scrolling while the pointer is over this view’s bounds.
/// Clicks still pass through to SwiftUI content.
final class ScrollIsolationView: NSView {
    var onVerticalScroll: ((CGFloat) -> Void)?
    /// How much vertical delta must accumulate before firing `onVerticalScroll`.
    var trip: CGFloat = 36
    private var monitor: Any?
    private var accumulated: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // Transparent; we only need bounds + event monitor.
        wantsLayer = true
        layer?.backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Let clicks reach SwiftUI views above/below; we only care about scroll monitoring.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            installMonitor()
        } else {
            removeMonitor()
        }
    }

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.window != nil else { return event }
            guard self.isPointerInside() else { return event }

            let dy = event.scrollingDeltaY
            let dx = event.scrollingDeltaX
            guard abs(dy) > abs(dx), abs(dy) > 0.1 else { return event }

            self.accumulated += dy
            let trip = max(self.trip, 1)
            if self.accumulated >= trip || self.accumulated <= -trip {
                let value = self.accumulated
                self.accumulated = 0
                let callback = self.onVerticalScroll
                DispatchQueue.main.async {
                    callback?(value)
                }
            }
            // Consume so the big page scrollbar does not move.
            return nil
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        accumulated = 0
    }

    private func isPointerInside() -> Bool {
        guard let window else { return false }
        let mouseInWindow = window.mouseLocationOutsideOfEventStream
        let local = convert(mouseInWindow, from: nil)
        return bounds.contains(local)
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

struct ScrollIsolationOverlay: NSViewRepresentable {
    var onVerticalScroll: ((CGFloat) -> Void)?
    var trip: CGFloat = 36

    func makeNSView(context: Context) -> ScrollIsolationView {
        let view = ScrollIsolationView()
        view.onVerticalScroll = onVerticalScroll
        view.trip = trip
        return view
    }

    func updateNSView(_ nsView: ScrollIsolationView, context: Context) {
        nsView.onVerticalScroll = onVerticalScroll
        nsView.trip = trip
    }
}

extension View {
    /// Isolate trackpad/mouse-wheel scrolling to this region (optional callback for vertical deltas).
    func isolateScroll(
        trip: CGFloat = 36,
        onVerticalScroll: ((CGFloat) -> Void)? = nil
    ) -> some View {
        background {
            ScrollIsolationOverlay(onVerticalScroll: onVerticalScroll, trip: trip)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
    }

    /// Remove enclosing NSScrollView scrollers so they never steal layout width.
    func withoutScrollers() -> some View {
        background {
            ScrollViewScrollerKiller()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
    }

    /// When `enabled`, any left-click outside this view’s bounds calls `action`.
    func onClickOutside(enabled: Bool, perform action: @escaping () -> Void) -> some View {
        background {
            OutsideClickMonitor(isEnabled: enabled, onOutsideClick: action)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
    }
}
