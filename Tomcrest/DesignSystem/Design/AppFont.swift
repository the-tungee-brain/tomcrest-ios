import SwiftUI
import UIKit

/// Typography aligned with web `app/layout.tsx` — Inter for UI, JetBrains Mono for data.
enum AppFont {
    enum Inter {
        static let regular = "Inter-Regular"
        static let medium = "Inter-Medium"
        static let semiBold = "Inter-SemiBold"
        static let bold = "Inter-Bold"
    }

    enum JetBrainsMono {
        static let regular = "JetBrainsMono-Regular"
        static let medium = "JetBrainsMono-Medium"
        static let semiBold = "JetBrainsMono-SemiBold"
    }

    static func uiFont(name: String, size: CGFloat, weight: UIFont.Weight? = nil) -> UIFont {
        if let font = UIFont(name: name, size: size) {
            return font
        }
        if let weight {
            return UIFont.systemFont(ofSize: size, weight: weight)
        }
        return UIFont.systemFont(ofSize: size)
    }

    static func inter(size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black:
            name = Inter.bold
        case .semibold:
            name = Inter.semiBold
        case .medium:
            name = Inter.medium
        default:
            name = Inter.regular
        }
        return Font.custom(name, size: size, relativeTo: textStyle)
    }

    static func jetbrainsMono(size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle) -> Font {
        let name: String
        switch weight {
        case .semibold, .bold, .heavy, .black:
            name = JetBrainsMono.semiBold
        case .medium:
            name = JetBrainsMono.medium
        default:
            name = JetBrainsMono.regular
        }
        return Font.custom(name, size: size, relativeTo: textStyle)
    }

    static func uiJetBrainsMono(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let name: String
        switch weight {
        case .semibold, .bold, .heavy, .black:
            name = JetBrainsMono.semiBold
        case .medium:
            name = JetBrainsMono.medium
        default:
            name = JetBrainsMono.regular
        }
        return uiFont(name: name, size: size, weight: weight)
    }
}
