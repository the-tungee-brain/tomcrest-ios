import SwiftUI
import UIKit

@MainActor
enum WatchlistFolderCompositionCache {
    private final class CacheEntry: NSObject {
        let image: UIImage

        init(_ image: UIImage) {
            self.image = image
        }
    }

    private static let cache = NSCache<NSString, CacheEntry>()

    static func cachedImage(
        swatch: WatchlistSwatch,
        accentHex: UInt32?,
        size: CGSize,
        colorScheme: ColorScheme
    ) -> UIImage? {
        let key = cacheKey(
            swatchID: swatch.id,
            composition: swatch.composition,
            accentHex: accentHex ?? swatch.accent,
            colorScheme: colorScheme,
            size: size
        )
        return cache.object(forKey: key as NSString)?.image
    }

    static func render(
        swatch: WatchlistSwatch,
        accent: Color,
        accentHex: UInt32?,
        size: CGSize,
        colorScheme: ColorScheme
    ) -> UIImage? {
        guard size.width > 1, size.height > 1 else { return nil }

        let key = cacheKey(
            swatchID: swatch.id,
            composition: swatch.composition,
            accentHex: accentHex ?? swatch.accent,
            colorScheme: colorScheme,
            size: size
        )

        if let cached = cache.object(forKey: key as NSString)?.image {
            return cached
        }

        let content = WatchlistFolderCompositionRenderer(swatch: swatch, accent: accent)
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, colorScheme)

        let renderer = ImageRenderer(content: content)
        renderer.scale = UITraitCollection.current.displayScale

        guard let image = renderer.uiImage else { return nil }
        cache.setObject(CacheEntry(image), forKey: key as NSString)
        return image
    }

    private static func cacheKey(
        swatchID: String,
        composition: WatchlistFolderComposition,
        accentHex: UInt32,
        colorScheme: ColorScheme,
        size: CGSize
    ) -> String {
        let width = Int((size.width / 8).rounded(.toNearestOrAwayFromZero)) * 8
        let height = Int((size.height / 8).rounded(.toNearestOrAwayFromZero)) * 8
        let scheme = colorScheme == .dark ? "dark" : "light"
        return "\(swatchID)|\(composition.rawValue)|\(accentHex)|\(scheme)|\(width)x\(height)"
    }
}
