import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("TodoAgent")
                .font(.title2.bold())

            Text("A menu bar todo viewer for markdown files")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            Text("\u{00A9} 2026 899bushwick")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text("MIT License")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(24)
        .frame(width: 300)
    }
}
