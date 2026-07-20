import SwiftUI
import AppKit

/// 富文本存取：把「可点链接的富文本」存进原来的 String 字段（用 RTF 编码），
/// 纯文本仍按纯文本存。这样不改数据库结构、不迁移、备份照常。
enum RichTextStore {
    static let baseFontSize: CGFloat = 13

    static var baseFont: NSFont { .systemFont(ofSize: baseFontSize) }
    static var textColor: NSColor { NSColor.white.withAlphaComponent(0.94) }
    static var accentColor: NSColor { NSColor(calibratedRed: 0.18, green: 0.80, blue: 0.72, alpha: 1) }

    /// 存进字段的字符串是不是 RTF（富文本）。纯文本不会以这个开头。
    static func isRTF(_ string: String) -> Bool {
        string.hasPrefix("{\\rtf")
    }

    // MARK: - String <-> NSAttributedString（编辑器用）

    /// 字段字符串 → 可显示的富文本（统一成主题字体/颜色，链接高亮）。
    static func attributed(from stored: String) -> NSAttributedString {
        if isRTF(stored), let data = stored.data(using: .utf8),
           let attr = NSAttributedString(rtf: data, documentAttributes: nil) {
            return normalized(attr)
        }
        return normalized(NSAttributedString(
            string: stored,
            attributes: [.font: baseFont, .foregroundColor: textColor]
        ))
    }

    /// 富文本 → 字段字符串：没有链接就存纯文本，有链接才存 RTF。
    static func store(from attributed: NSAttributedString) -> String {
        if hasLink(attributed) {
            let range = NSRange(location: 0, length: attributed.length)
            if let data = try? attributed.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            ), let rtf = String(data: data, encoding: .utf8) {
                return rtf
            }
        }
        return attributed.string
    }

    // MARK: - AI「整理」用的 markdown 互转

    /// 发给模型前：把存储内容变成带 `[文字](网址)` 的 markdown，模型才看得懂链接。
    static func modelInput(_ stored: String, isCode: Bool) -> String {
        if isCode { return stored }
        if !isRTF(stored) { return stored }
        let attr = attributed(from: stored)
        var out = ""
        attr.enumerateAttributes(in: NSRange(location: 0, length: attr.length)) { attrs, range, _ in
            let text = (attr.string as NSString).substring(with: range)
            if let url = linkURL(attrs) {
                out += "[\(text)](\(url))"
            } else {
                out += text
            }
        }
        return out
    }

    /// 模型返回的 markdown → 存回字段（非代码转成富文本，代码保持纯文本）。
    static func storeModelResult(_ text: String, isCode: Bool) -> String {
        if isCode { return text }
        let attr = attributedFromMarkdown(text)
        return store(from: attr)
    }

    /// markdown 字符串 → 富文本（保留换行、加粗、链接）。
    static func attributedFromMarkdown(_ markdown: String) -> NSAttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let attributed = try? AttributedString(markdown: markdown, options: options) {
            return normalized(NSAttributedString(attributed))
        }
        return normalized(NSAttributedString(
            string: markdown,
            attributes: [.font: baseFont, .foregroundColor: textColor]
        ))
    }

    // MARK: - 归一化：统一字体/颜色，保留粗斜体，链接高亮，识别裸链接

    /// 复制一份并归一化（用于粘贴：套主题色，保留链接，识别裸网址）。
    static func normalizedCopy(of attributed: NSAttributedString) -> NSAttributedString {
        normalized(attributed)
    }

    private static func normalized(_ input: NSAttributedString) -> NSAttributedString {
        let m = NSMutableAttributedString(attributedString: input)
        let full = NSRange(location: 0, length: m.length)

        // 1) 字体统一成主题字号，但保留原有的粗体/斜体。
        m.enumerateAttribute(.font, in: full) { value, range, _ in
            let traits = (value as? NSFont)?.fontDescriptor
                .symbolicTraits
                .intersection([.bold, .italic]) ?? []
            let descriptor = baseFont.fontDescriptor.withSymbolicTraits(traits)
            let font = NSFont(descriptor: descriptor, size: baseFontSize) ?? baseFont
            m.addAttribute(.font, value: font, range: range)
        }

        // 2) 先给所有文字套上主题正文色。
        m.addAttribute(.foregroundColor, value: textColor, range: full)

        // 3) 补识别裸网址（http/https），没链接属性的加上。
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            for match in detector.matches(in: m.string, range: NSRange(m.string.startIndex..., in: m.string)) {
                guard let url = match.url, m.attribute(.link, at: match.range.location, effectiveRange: nil) == nil else { continue }
                m.addAttribute(.link, value: url, range: match.range)
            }
        }

        // 4) 链接段落：强调色 + 下划线。
        m.enumerateAttribute(.link, in: full) { value, range, _ in
            guard value != nil else { return }
            m.addAttribute(.foregroundColor, value: accentColor, range: range)
            m.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        return m
    }

    private static func hasLink(_ attributed: NSAttributedString) -> Bool {
        var found = false
        attributed.enumerateAttribute(.link, in: NSRange(location: 0, length: attributed.length)) { value, _, stop in
            if value != nil { found = true; stop.pointee = true }
        }
        return found
    }

    private static func linkURL(_ attrs: [NSAttributedString.Key: Any]) -> String? {
        switch attrs[.link] {
        case let url as URL: return url.absoluteString
        case let s as String: return s
        default: return nil
        }
    }
}

/// SwiftUI 里用的富文本编辑器。绑定一个 String（RTF 或纯文本），
/// 粘贴保留链接、点链接直接跳转、深色主题下文字可见。
struct RichTextEditor: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var minHeight: CGFloat = 110

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = ThemedTextView()
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.font = RichTextStore.baseFont
        textView.textColor = RichTextStore.textColor
        textView.insertionPointColor = RichTextStore.accentColor
        textView.isAutomaticLinkDetectionEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.linkTextAttributes = [
            .foregroundColor: RichTextStore.accentColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand
        ]
        textView.placeholderString = placeholder
        textView.textStorage?.setAttributedString(RichTextStore.attributed(from: text))
        context.coordinator.lastEmitted = text

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        textView.autoresizingMask = [.width]
        return scroll
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ThemedTextView else { return }
        if textView.placeholderString != placeholder {
            textView.placeholderString = placeholder
        }
        // 只有外部改了 text（比如 AI 整理）才回填，避免打断用户输入。
        if text != context.coordinator.lastEmitted {
            let selected = textView.selectedRange()
            textView.textStorage?.setAttributedString(RichTextStore.attributed(from: text))
            textView.setSelectedRange(NSRange(location: min(selected.location, textView.string.count), length: 0))
            context.coordinator.lastEmitted = text
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: RichTextEditor
        var lastEmitted: String = ""

        init(_ parent: RichTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let storage = textView.textStorage else { return }
            let value = RichTextStore.store(from: storage)
            lastEmitted = value
            parent.text = value
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            let url: URL?
            switch link {
            case let u as URL: url = u
            case let s as String: url = URL(string: s)
            default: url = nil
            }
            if let url { NSWorkspace.shared.open(url); return true }
            return false
        }
    }
}

/// 带占位符、粘贴归一化的 NSTextView。
final class ThemedTextView: NSTextView {
    var placeholderString: String = "" { didSet { needsDisplay = true } }

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        var attributed: NSAttributedString?
        if let objects = pasteboard.readObjects(forClasses: [NSAttributedString.self], options: [:]) as? [NSAttributedString],
           let first = objects.first {
            attributed = first
        } else if let plain = pasteboard.string(forType: .string) {
            attributed = NSAttributedString(string: plain)
        }
        guard let attributed else { super.paste(sender); return }

        let normalized = RichTextStore.normalizedCopy(of: attributed)
        let range = selectedRange()
        guard shouldChangeText(in: range, replacementString: normalized.string) else { return }
        textStorage?.replaceCharacters(in: range, with: normalized)
        setSelectedRange(NSRange(location: range.location + normalized.length, length: 0))
        didChangeText()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholderString.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: RichTextStore.baseFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.35)
        ]
        let origin = NSPoint(x: textContainerInset.width + 5, y: textContainerInset.height)
        placeholderString.draw(at: origin, withAttributes: attrs)
    }
}
