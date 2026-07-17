import SwiftUI

/// Full-window deep-space backdrop.
///
/// Layers, back to front:
/// 1. Solid deep ink (fallback if the image is missing).
/// 2. The Gargantua-style black hole render, dimmed.
/// 3. A dark scrim so foreground content stays readable.
/// 4. A procedural star layer that briefly streaks outward (a small
///    "warp" burst) whenever `warpTrigger` changes, then settles back
///    into static points.
struct DeepSpaceBackground: View {
    /// Bump this to fire one warp burst (e.g. on every route change).
    var warpTrigger: Int

    @State private var warpStart: Date?

    private static let warpDuration: Double = 0.55

    var body: some View {
        ZStack {
            AppTheme.backgroundDeep

            if let image = Self.backdrop {
                GeometryReader { geo in
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .opacity(0.55)
            }

            // Scrim: keeps the image at roughly 20–30% perceived brightness.
            AppTheme.background.opacity(0.5)

            starLayer
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onChange(of: warpTrigger) { _, _ in
            warpStart = Date()
        }
    }

    // MARK: - Stars

    private var starLayer: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: warpStart == nil)) { timeline in
            Canvas { context, size in
                let warp = warpIntensity(at: timeline.date)
                drawStars(in: context, size: size, warp: warp)
            }
            .onChange(of: timeline.date) { _, now in
                if let start = warpStart, now.timeIntervalSince(start) >= Self.warpDuration {
                    warpStart = nil
                }
            }
        }
    }

    /// 0 when idle; rises to 1 mid-warp and eases back to 0.
    private func warpIntensity(at now: Date) -> Double {
        guard let start = warpStart else { return 0 }
        let t = min(max(now.timeIntervalSince(start) / Self.warpDuration, 0), 1)
        return sin(t * .pi)
    }

    private func drawStars(in context: GraphicsContext, size: CGSize, warp: Double) {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.45)
        let maxRadius = hypot(size.width, size.height) * 0.5

        for star in Self.stars {
            let radius = star.radius * maxRadius
            // Outer stars get pushed outward slightly more — warp parallax.
            let push = 1 + 0.05 * warp * star.radius
            let x = center.x + cos(star.angle) * radius * push
            let y = center.y + sin(star.angle) * radius * push

            if warp > 0.01 {
                // Streak pointing back toward the center.
                let length = warp * star.radius * 80
                var path = Path()
                path.move(to: CGPoint(x: x - cos(star.angle) * length, y: y - sin(star.angle) * length))
                path.addLine(to: CGPoint(x: x, y: y))
                context.stroke(
                    path,
                    with: .color(star.color.opacity(star.brightness * 0.85)),
                    lineWidth: star.size * 0.8
                )
            }

            let dot = CGRect(x: x - star.size / 2, y: y - star.size / 2, width: star.size, height: star.size)
            context.fill(Path(ellipseIn: dot), with: .color(star.color.opacity(star.brightness)))
        }
    }

    // MARK: - Static data

    private static let backdrop: NSImage? = Bundle.module
        .url(forResource: "DeepSpace", withExtension: "png")
        .flatMap { NSImage(contentsOf: $0) }

    private struct Star {
        let angle: Double
        let radius: Double
        let size: Double
        let brightness: Double
        let color: Color
    }

    /// Deterministic star field so the sky doesn't reshuffle between launches.
    private static let stars: [Star] = {
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        func next() -> Double {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return Double(state % 10_000) / 10_000
        }
        let palette: [Color] = [
            .white, .white, .white,
            Color(red: 0.75, green: 0.88, blue: 1.0),
            Color(red: 1.0, green: 0.85, blue: 0.68)
        ]
        return (0..<120).map { _ in
            Star(
                angle: next() * 2 * .pi,
                radius: 0.15 + next() * 0.85,
                size: 0.8 + next() * 1.8,
                brightness: 0.12 + next() * 0.45,
                color: palette[Int(next() * Double(palette.count)) % palette.count]
            )
        }
    }()
}
