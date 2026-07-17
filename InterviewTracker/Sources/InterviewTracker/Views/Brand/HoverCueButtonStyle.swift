import SwiftUI
import AppKit

enum HoverCueKind {
    /// Strong floating cue for open chrome (toolbar icons, chips).
    case float
    /// Soft in-place cue that stays inside parent clips (list rows in cards).
    case contained
}

struct HoverCueButtonStyle: ButtonStyle {
    var kind: HoverCueKind = .float

    func makeBody(configuration: Configuration) -> some View {
        HoverCueBody(configuration: configuration, kind: kind)
    }

    private struct HoverCueBody: View {
        let configuration: Configuration
        let kind: HoverCueKind

        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovering = false
        @State private var isCursorPushed = false

        var body: some View {
            configuration.label
                .background {
                    RoundedRectangle(cornerRadius: kind == .contained ? 12 : 10, style: .continuous)
                        .fill(AppTheme.accent.opacity(fillOpacity))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: kind == .contained ? 12 : 10, style: .continuous)
                        .stroke(AppTheme.accent.opacity(strokeOpacity), lineWidth: kind == .contained ? 1 : 1.5)
                }
                .scaleEffect(scale)
                .offset(y: floatOffset)
                .brightness(isHovering && isEnabled ? (kind == .contained ? 0.06 : 0.12) : 0)
                .shadow(
                    color: AppTheme.accent.opacity(shadowOpacity),
                    radius: kind == .contained ? 0 : 12,
                    y: kind == .contained ? 0 : 4
                )
                .opacity(isEnabled ? 1 : 0.55)
                .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isHovering)
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
                .onHover { hovering in
                    isHovering = hovering
                    updateCursor(hovering: hovering)
                }
                .onDisappear {
                    restoreCursor()
                }
        }

        private var fillOpacity: Double {
            guard isHovering && isEnabled else { return 0 }
            return kind == .contained ? 0.06 : 0.14
        }

        private var strokeOpacity: Double {
            guard isHovering && isEnabled else { return 0 }
            return kind == .contained ? 0.28 : 0.65
        }

        private var shadowOpacity: Double {
            guard kind == .float, isHovering && isEnabled else { return 0 }
            return 0.38
        }

        private var floatOffset: CGFloat {
            guard kind == .float, isHovering && isEnabled, !configuration.isPressed else { return 0 }
            return -2
        }

        private var scale: CGFloat {
            guard isEnabled else { return 1 }
            if configuration.isPressed { return kind == .contained ? 0.985 : 0.96 }
            guard isHovering else { return 1 }
            return kind == .contained ? 1 : 1.04
        }

        private func updateCursor(hovering: Bool) {
            if hovering && isEnabled && !isCursorPushed {
                NSCursor.pointingHand.push()
                isCursorPushed = true
            } else if (!hovering || !isEnabled) && isCursorPushed {
                restoreCursor()
            }
        }

        private func restoreCursor() {
            guard isCursorPushed else { return }
            NSCursor.pop()
            isCursorPushed = false
        }
    }
}

extension ButtonStyle where Self == HoverCueButtonStyle {
    static var hoverCue: HoverCueButtonStyle { HoverCueButtonStyle(kind: .float) }
    static var hoverCueContained: HoverCueButtonStyle { HoverCueButtonStyle(kind: .contained) }
}

private struct InteractiveCardHoverModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        AppTheme.accent.opacity(isHovering ? 0.75 : 0),
                        lineWidth: 2
                    )
            }
            .scaleEffect(isHovering ? 1.018 : 1)
            .offset(y: isHovering ? -3 : 0)
            .shadow(
                color: AppTheme.accent.opacity(isHovering ? 0.32 : 0),
                radius: 18,
                y: 8
            )
            .animation(.spring(response: 0.28, dampingFraction: 0.76), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

extension View {
    func interactiveCardHover() -> some View {
        modifier(InteractiveCardHoverModifier())
    }
}
