import SwiftUI
import UIKit

private extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

private extension Color {
    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

enum AstraTheme {
    // Astra design tokens from the checked-in Figma exports.
    static let ink = Color(light: UIColor(hex: 0x172033), dark: UIColor(hex: 0xF4F7FC))
    static let muted = Color(light: UIColor(hex: 0x7D879B), dark: UIColor(hex: 0xAAB6C8))
    static let blue = Color(light: UIColor(hex: 0x6F82FF), dark: UIColor(hex: 0x8A99FF))
    static let green = Color(light: UIColor(hex: 0x329A63), dark: UIColor(hex: 0x7DDBA8))
    static let mint = Color(light: UIColor(hex: 0xE2F7EB), dark: UIColor(hex: 0x203A34))
    static let softBlue = Color(light: UIColor(hex: 0xEAF2FF), dark: UIColor(hex: 0x202E4A))
    static let canvas = Color(light: UIColor(hex: 0xF6F8FC), dark: UIColor(hex: 0x0E1728))
    static let surface = Color(light: UIColor(hex: 0xFFFFFF), dark: UIColor(hex: 0x17243A))
    static let surfaceElevated = Color(light: UIColor(hex: 0xFFFFFF), dark: UIColor(hex: 0x1E2B42))
    static let line = Color(light: UIColor(hex: 0xE5EAF2), dark: UIColor(hex: 0x2A3A51))
    static let sidebar = Color(light: UIColor(hex: 0x0E1728), dark: UIColor(hex: 0x08101E))
    static let sidebarActive = Color(light: UIColor(hex: 0x26364A), dark: UIColor(hex: 0x26364A))
    static let amber = Color(light: UIColor(hex: 0xB56A16), dark: UIColor(hex: 0xF2B866))
    static let danger = Color(light: UIColor(hex: 0xC84B5C), dark: UIColor(hex: 0xFF9AA8))
}

struct AstraCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(16)
            .background(AstraTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AstraTheme.line, lineWidth: 1))
            .shadow(color: AstraTheme.ink.opacity(0.07), radius: 14, y: 6)
    }
}

struct MetricTile: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(AstraTheme.muted)
            Text(value).font(.title3.weight(.bold)).foregroundStyle(AstraTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.13))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(tint.opacity(0.16), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension Double {
    var compact: String { formatted(.number.precision(.fractionLength(0...1))) }
}

extension Optional where Wrapped == Double {
    var display: String { map(\.compact) ?? "—" }
}
