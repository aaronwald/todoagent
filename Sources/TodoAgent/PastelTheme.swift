import SwiftUI

enum PastelTheme {
    static let colors: [Color] = [
        Color(red: 0.40, green: 0.70, blue: 0.92),  // blue
        Color(red: 0.35, green: 0.80, blue: 0.45),  // green
        Color(red: 0.95, green: 0.60, blue: 0.35),  // peach
        Color(red: 0.60, green: 0.45, blue: 0.90),  // lavender
        Color(red: 0.30, green: 0.85, blue: 0.72),  // mint
        Color(red: 0.92, green: 0.40, blue: 0.50),  // rose
        Color(red: 0.90, green: 0.82, blue: 0.30),  // yellow
        Color(red: 0.75, green: 0.50, blue: 0.90),  // orchid
    ]

    static func color(for index: Int) -> Color {
        colors[index % colors.count]
    }

    static func lightened(_ color: Color, by amount: Double = 0.3) -> Color {
        color.opacity(1.0 - amount)
    }
}
