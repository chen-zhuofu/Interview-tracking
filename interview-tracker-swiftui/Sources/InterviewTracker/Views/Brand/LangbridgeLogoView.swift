import SwiftUI
import AppKit

/// Langbridge mark next to the Interview Tracker wordmark.
struct LangbridgeLogoView: View {
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let image = Self.cachedImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                // Fallback if resource missing
                Image(systemName: "seal.fill")
                    .font(.system(size: size * 0.7))
                    .foregroundStyle(Color(red: 0.25, green: 0.49, blue: 0.92))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private static let cachedImage: NSImage? = {
        let names = [("Langbridge_Graph", "png"), ("Langbridge_Graph", "svg")]
        let bundles = [AppResourceBundle.bundle, Bundle.main]
        for (name, ext) in names {
            for bundle in bundles {
                if let url = bundle.url(forResource: name, withExtension: ext),
                   let image = NSImage(contentsOf: url),
                   image.size.width > 0 {
                    return image
                }
            }
        }
        return nil
    }()
}
