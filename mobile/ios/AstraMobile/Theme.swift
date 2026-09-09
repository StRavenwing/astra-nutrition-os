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
    // Native tokens mapped to the supplied 390x771 mobile reference.
    static let ink = Color(light: UIColor(hex: 0x1A1A1A), dark: UIColor(hex: 0xFAFAF8))
    static let muted = Color(light: UIColor(hex: 0xA09E9B), dark: UIColor(hex: 0xA0A0A0))
    static let blue = Color(light: UIColor(hex: 0xE8732A), dark: UIColor(hex: 0xFF9153))
    static let green = Color(light: UIColor(hex: 0xE8732A), dark: UIColor(hex: 0xFF9153))
    static let mint = Color(light: UIColor(hex: 0xFFF1E8), dark: UIColor(hex: 0x3A251B))
    static let softBlue = Color(light: UIColor(hex: 0xFFF1E8), dark: UIColor(hex: 0x3A251B))
    static let canvas = Color(light: UIColor(hex: 0xFFFFFF), dark: UIColor(hex: 0x0A0908))
    static let surface = Color(light: UIColor(hex: 0xFFFFFF), dark: UIColor(hex: 0x161513))
    static let surfaceElevated = Color(light: UIColor(hex: 0xFFFFFF), dark: UIColor(hex: 0x1A1A1A))
    static let line = Color(light: UIColor(hex: 0xF0EEEA), dark: UIColor(hex: 0x3A332E))
    static let sidebar = Color(light: UIColor(hex: 0x1A1A1A), dark: UIColor(hex: 0x0D0C0B))
    static let sidebarActive = Color(light: UIColor(hex: 0x3A332E), dark: UIColor(hex: 0x3A332E))
    static let amber = Color(light: UIColor(hex: 0xE8732A), dark: UIColor(hex: 0xFF9153))
    static let danger = Color(light: UIColor(hex: 0xFF3B30), dark: UIColor(hex: 0xFF7B73))
}

struct AstraCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(16)
            .background(AstraTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AstraTheme.line, lineWidth: 1))
            .shadow(color: AstraTheme.ink.opacity(0.06), radius: 10, y: 4)
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
        .background(tint.opacity(0.10))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AstraTheme.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension Double {
    var compact: String { formatted(.number.precision(.fractionLength(0...1))) }
}

extension Optional where Wrapped == Double {
    var display: String { map(\.compact) ?? "—" }
}
