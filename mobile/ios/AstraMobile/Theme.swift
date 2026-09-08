import SwiftUI

enum AstraTheme {
    static let ink = Color(red: 0.09, green: 0.13, blue: 0.20)
    static let muted = Color(red: 0.45, green: 0.50, blue: 0.60)
    static let blue = Color(red: 0.43, green: 0.51, blue: 1.0)
    static let green = Color(red: 0.20, green: 0.60, blue: 0.39)
    static let mint = Color(red: 0.88, green: 0.97, blue: 0.92)
    static let canvas = Color(red: 0.96, green: 0.97, blue: 0.98)
}

struct AstraCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 14, y: 6)
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
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension Double {
    var compact: String { formatted(.number.precision(.fractionLength(0...1))) }
}

extension Optional where Wrapped == Double {
    var display: String { map(\.compact) ?? "—" }
}
