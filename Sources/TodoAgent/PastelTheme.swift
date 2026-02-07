import SwiftUI

enum PastelTheme {
    static let colors: [Color] = [
        Color(red: 0.68, green: 0.85, blue: 0.95),  // soft blue
        Color(red: 0.70, green: 0.93, blue: 0.73),  // soft green
        Color(red: 1.00, green: 0.85, blue: 0.73),  // soft peach
        Color(red: 0.80, green: 0.73, blue: 0.95),  // soft lavender
        Color(red: 0.68, green: 0.95, blue: 0.88),  // soft mint
        Color(red: 0.98, green: 0.73, blue: 0.78),  // soft rose
        Color(red: 0.95, green: 0.93, blue: 0.68),  // soft yellow
        Color(red: 0.88, green: 0.78, blue: 0.95),  // soft orchid
    ]

    static func color(for index: Int) -> Color {
        colors[index % colors.count]
    }

    static func lightened(_ color: Color, by amount: Double = 0.3) -> Color {
        color.opacity(1.0 - amount)
    }
}
