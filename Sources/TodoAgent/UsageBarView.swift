import SwiftUI

struct UsageBarView: View {
    @ObservedObject var usage: ClaudeUsageWatcher

    var body: some View {
        HStack(spacing: 12) {
            quotaBar(label: "5h", pct: usage.fiveHourUtil, reset: usage.fiveHourReset)
            quotaBar(label: "7d", pct: usage.sevenDayUtil, reset: usage.sevenDayReset)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.06))
    }

    private func quotaBar(label: String, pct: Double, reset: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                Text("\(Int(pct))%")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(barColor(for: pct))
                if !reset.isEmpty {
                    Text(reset)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: pct))
                        .frame(width: geo.size.width * min(pct / 100.0, 1.0))
                }
            }
            .frame(height: 4)
        }
    }

    private func barColor(for pct: Double) -> Color {
        if pct >= 80 { return .red }
        if pct >= 50 { return .orange }
        return .green
    }
}
