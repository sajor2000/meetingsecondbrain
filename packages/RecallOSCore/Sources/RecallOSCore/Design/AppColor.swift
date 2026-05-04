import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

public extension Color {
    static let appAccent = Color(hex: 0x0F4C5C)
    static let appAccentDark = Color(hex: 0x1A6F86)
    static let appDanger = Color(red: 0.88, green: 0.18, blue: 0.18)

    #if os(macOS)
    static let appBackground = Color(nsColor: .windowBackgroundColor)
    static let appSurface = Color(nsColor: .underPageBackgroundColor)
    static let appSecondarySurface = Color(nsColor: .controlBackgroundColor)
    static let appHairline = Color(nsColor: .separatorColor)
    static let appMutedText = Color(nsColor: .secondaryLabelColor)
    static let appAISuggestionText = Color(nsColor: .tertiaryLabelColor)
    #else
    static let appBackground = Color(uiColor: .systemBackground)
    static let appSurface = Color(uiColor: .secondarySystemBackground)
    static let appSecondarySurface = Color(uiColor: .tertiarySystemBackground)
    static let appHairline = Color(uiColor: .separator)
    static let appMutedText = Color(uiColor: .secondaryLabel)
    static let appAISuggestionText = Color(uiColor: .tertiaryLabel)
    #endif

    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}
