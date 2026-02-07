import SwiftUI

struct TodoItemView: View {
    let item: TodoItem
    let fileName: String
    let isFlashing: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                .foregroundColor(item.isCompleted ? .secondary : .primary)
                .font(.system(size: 13))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13))
                    .strikethrough(item.isCompleted)
                    .foregroundColor(item.isCompleted ? .secondary : .primary)
                    .lineLimit(2)

                if !item.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(item.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(3)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isFlashing ? Color.accentColor : Color.clear, lineWidth: 2)
                .animation(.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true), value: isFlashing)
        )
        .textSelection(.enabled)
    }
}
