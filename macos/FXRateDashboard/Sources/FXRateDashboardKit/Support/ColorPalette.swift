import SwiftUI

public enum ColorPalette {
    public static let brandBrightGreen = Color(hex: 0x9FE870)
    public static let brandForestGreen = Color(hex: 0x163300)

    public static let panelBackgroundOnline = Color(hex: 0xFCFCFA)
    public static let panelBackgroundOffline = Color(hex: 0xD2D9CA)
    public static let surfaceAltOnline = Color(hex: 0xF5F6EF)
    public static let surfaceAltOffline = Color(hex: 0xE1E5DE)
    public static let accentOnline = Color(hex: 0x9FE870)
    public static let accentOffline = Color(hex: 0xB7BEB2)
    public static let primaryTextOnline = Color(hex: 0x163300)
    public static let primaryTextOffline = Color(hex: 0x52584F)
    public static let mutedTextOnline = Color(hex: 0x6A745F)
    public static let mutedTextOffline = Color(hex: 0x7D8479)
    public static let positive = Color(hex: 0x6C9A54)
    public static let negative = Color(hex: 0xD97A68)
    public static let warning = Color(hex: 0xC69200)
    public static let offlineTrend = Color(hex: 0x8E9689)
    public static let panelEdge = Color(hex: 0x163300, alpha: 0.12)
    public static let statusChipBackgroundOnline = Color.white.opacity(0.92)
    public static let statusChipBackgroundOffline = Color.white.opacity(0.58)
    public static let widgetTopGlow = Color(hex: 0xF6FAEE, alpha: 0.85)
    public static let widgetBottomGlow = Color.white.opacity(0.72)
    public static let widgetShadow = Color.black.opacity(0.11)

    public static let settingsWindowBackground = Color(hex: 0xFCFCFA)
    public static let settingsWindowBorder = Color(hex: 0xDEE5D8)
    public static let settingsCardTop = Color.white
    public static let settingsCardBottom = Color(hex: 0xF6F8F1)
    public static let settingsCardBorder = Color(hex: 0xDEE5D8)
    public static let settingsInputBackground = Color.white
    public static let settingsInputBorder = Color(hex: 0xD7DED0)
    public static let settingsPrimaryText = Color(hex: 0x192332)
    public static let settingsMutedText = Color(hex: 0x74806E)
    public static let settingsAccent = Color(hex: 0x59C64A)
    public static let settingsAccentDark = Color(hex: 0x46B03A)
    public static let validationBackground = Color(red: 1.0, green: 0.93, blue: 0.93)
    public static let validationBorder = Color(hex: 0xF3C8CD)
    public static let validationText = Color(hex: 0x9C2E34)
}

public extension Color {
    init(hex: Int, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
