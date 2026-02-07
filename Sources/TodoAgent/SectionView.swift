import SwiftUI

struct SectionView: View {
    let section: TodoSection
    let fileName: String
    let colorIndex: Int
    let depth: Int
    let changedItemKeys: Set<String>

    @Environment(AppState.self) private var appState: AppState?
    @State private var isExpanded: Bool = false

    private var hasChangedDescendant: Bool {
        let fileBase = URL(fileURLWithPath: fileName).lastPathComponent
        return allItems(in: section).contains { item in
            changedItemKeys.contains("\(fileBase):\(item.title)")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 14)

                    Text(section.heading)
                        .font(.system(size: depth == 0 ? 14 : 13, weight: depth == 0 ? .semibold : .medium))
                        .foregroundColor(section.allCompleted ? .secondary : .primary)

                    Spacer()

                    let stats = itemStats(section)
                    Text("\(stats.unchecked)/\(stats.total)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(hasChangedDescendant && !isExpanded ? Color.accentColor : Color.clear, lineWidth: 2)
                    .animation(.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true), value: hasChangedDescendant)
            )

            if isExpanded {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(section.items) { item in
                        let fileBase = URL(fileURLWithPath: fileName).lastPathComponent
                        let key = "\(fileBase):\(item.title)"
                        TodoItemView(
                            item: item,
                            fileName: fileName,
                            isFlashing: changedItemKeys.contains(key)
                        )
                        .padding(.leading, CGFloat(depth) * 8 + 16)
                    }

                    ForEach(Array(section.subsections.enumerated()), id: \.element.id) { _, sub in
                        SectionView(
                            section: sub,
                            fileName: fileName,
                            colorIndex: colorIndex,
                            depth: depth + 1,
                            changedItemKeys: changedItemKeys
                        )
                        .padding(.leading, 8)
                    }
                }
            }
        }
        .background(
            PastelTheme.color(for: colorIndex)
                .opacity(section.allCompleted ? 0.05 : (depth == 0 ? 0.15 : 0.08))
        )
        .cornerRadius(depth == 0 ? 6 : 4)
        .onChange(of: appState?.collapseAllToggle) { _, _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded = false
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
}
