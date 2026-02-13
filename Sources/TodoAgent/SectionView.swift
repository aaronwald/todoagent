import SwiftUI

struct SectionView: View {
    let section: TodoSection
    let fileName: String
    let colorIndex: Int
    let depth: Int
    let changedItemKeys: Set<String>
    let itemChangeKeys: [String: String]
    var onAcknowledge: ((Set<String>) -> Void)?

    @Environment(AppState.self) private var appState: AppState?
    @State private var isExpanded: Bool = false

    private var hasChangedDescendant: Bool {
        allItems(in: section).contains { item in
            guard let key = itemChangeKeys[item.id] else { return false }
            return changedItemKeys.contains(key)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                if isExpanded, hasChangedDescendant {
                    let keys = Set(allItems(in: section).compactMap { itemChangeKeys[$0.id] })
                    onAcknowledge?(keys)
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 14)

                    Text(section.heading)
                        .font(.system(size: depth == 0 ? 14 : 13, weight: depth == 0 ? .semibold : .medium))
                        .foregroundColor(section.allCompleted ? .secondary : .primary)

                    Spacer()

                    if hasChangedDescendant {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundColor(.orange)
                    }

                    let stats = itemStats(section)
                    Text("\(stats.unchecked)/\(stats.total)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "" : tooltipText(for: section))

            if isExpanded {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(section.items) { item in
                        let key = itemChangeKeys[item.id] ?? ""
                        TodoItemView(
                            item: item,
                            fileName: fileName,
                            isFlashing: changedItemKeys.contains(key),
                            onAcknowledge: {
                                onAcknowledge?(Set([key]))
                            }
                        )
                        .padding(.leading, CGFloat(depth) * 8 + 16)
                    }

                    ForEach(Array(section.subsections.enumerated()), id: \.element.id) { _, sub in
                        SectionView(
                            section: sub,
                            fileName: fileName,
                            colorIndex: colorIndex,
                            depth: depth + 1,
                            changedItemKeys: changedItemKeys,
                            itemChangeKeys: itemChangeKeys,
                            onAcknowledge: onAcknowledge
                        )
                        .padding(.leading, 8)
                    }
                }
            }
        }
        .background(
            PastelTheme.color(for: colorIndex)
                .opacity(section.allCompleted ? 0.10 : (depth == 0 ? 0.30 : 0.18))
        )
        .cornerRadius(depth == 0 ? 6 : 4)
        .onChange(of: appState?.collapseAllToggle) { _, _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded = false
            }
        }
        .onChange(of: hasChangedDescendant) { _, hasChanges in
            if hasChanges {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = true
                }
            }
        }
    }

    private func itemStats(_ section: TodoSection) -> (unchecked: Int, total: Int) {
        let items = allItems(in: section)
        let total = items.count
        let unchecked = items.filter { !$0.isCompleted }.count
        return (unchecked, total)
    }

    private func allItems(in section: TodoSection) -> [TodoItem] {
        section.items + section.subsections.flatMap { allItems(in: $0) }
    }

    private func tooltipText(for section: TodoSection) -> String {
        let items = allItems(in: section)
        if items.isEmpty { return "" }
        let lines = items.map { item in
            "\(item.isCompleted ? "\u{2611}" : "\u{2610}") \(item.title)"
        }
        return lines.joined(separator: "\n")
    }
}
