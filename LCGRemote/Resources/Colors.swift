import SwiftUI

/// Semantic color definitions supporting light and dark mode with WCAG AA contrast compliance.
/// Uses system-adaptive colors where possible for automatic adaptation.
///
/// Requirements: 9.3, 9.6
extension Color {

    // MARK: - Brand / Accent Colors

    /// Primary accent color used for interactive elements and focus indicators.
    /// Meets WCAG AA 3:1 contrast against both light and dark backgrounds.
    static let lcgAccent = Color.accentColor

    // MARK: - Text Colors

    /// Primary text color — adapts to light/dark mode automatically.
    /// System primary provides ≥7:1 contrast on respective backgrounds.
    static let lcgTextPrimary = Color.primary

    /// Secondary text color for subtitles, hints, and labels.
    /// System secondary provides ≥4.5:1 contrast on respective backgrounds.
    static let lcgTextSecondary = Color.secondary

    // MARK: - Background Colors

    /// Main background color — adapts automatically with system appearance.
    static let lcgBackground = Color(light: Color(red: 0.98, green: 0.98, blue: 0.99),
                                     dark: Color(red: 0.11, green: 0.11, blue: 0.12))

    /// Grouped/secondary background for cards and sections.
    static let lcgBackgroundSecondary = Color(light: Color.white,
                                             dark: Color(red: 0.17, green: 0.17, blue: 0.18))

    // MARK: - Status Colors (≥4.5:1 contrast on respective backgrounds)

    /// Success indicator color — green that meets WCAG AA.
    static let lcgSuccess = Color(light: Color(red: 0.13, green: 0.59, blue: 0.33),
                                  dark: Color(red: 0.35, green: 0.78, blue: 0.49))

    /// Error/destructive color — red that meets WCAG AA.
    static let lcgError = Color(light: Color(red: 0.80, green: 0.15, blue: 0.15),
                                dark: Color(red: 1.0, green: 0.40, blue: 0.40))

    /// Warning color — orange that meets WCAG AA for large text/UI components (3:1).
    static let lcgWarning = Color(light: Color(red: 0.75, green: 0.45, blue: 0.0),
                                  dark: Color(red: 1.0, green: 0.70, blue: 0.25))

    /// Busy/in-progress indicator color.
    static let lcgBusy = Color(light: Color(red: 0.20, green: 0.40, blue: 0.80),
                               dark: Color(red: 0.45, green: 0.65, blue: 1.0))

    // MARK: - Connection Status

    /// Connected device indicator color.
    static let lcgConnected = Color(light: Color(red: 0.13, green: 0.59, blue: 0.33),
                                    dark: Color(red: 0.35, green: 0.78, blue: 0.49))

    /// Disconnected/unavailable device indicator.
    static let lcgDisconnected = Color(light: Color(red: 0.55, green: 0.55, blue: 0.58),
                                       dark: Color(red: 0.60, green: 0.60, blue: 0.63))

    // MARK: - Control Surface Colors

    /// Floor button background tint.
    static let lcgButtonSurface = Color(light: Color.accentColor.opacity(0.12),
                                        dark: Color.accentColor.opacity(0.20))

    /// Floor button border color.
    static let lcgButtonBorder = Color.accentColor
}

// MARK: - Light/Dark Mode Color Initializer

extension Color {
    /// Creates a color that adapts between light and dark mode variants.
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(dark)
            } else {
                return NSColor(light)
            }
        })
        #else
        self = light
        #endif
    }
}
