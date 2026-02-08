import SwiftUI

struct TodoItemView: View {
    let item: TodoItem
    let fileName: String
    let isFlashing: Bool
    var onAcknowledge: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                .foregroundColor(item.isCompleted ? .secondary : .primary)
                .font(.system(size: 13))

            Text(item.title)
                .font(.system(size: 13, weight: isFlashing ? .semibold : .regular))
                .strikethrough(item.isCompleted)
                .foregroundColor(item.isCompleted ? .secondary : .primary)
                .lineLimit(2)

            ForEach(item.tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 10))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(3)
            }

            Spacer()

            if isFlashing {
                Text("changed")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(3)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isFlashing ? Color.orange.opacity(0.12) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isFlashing ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .textSelection(.enabled)
        .onTapGesture(count: 2) {
            if isFlashing {
                onAcknowledge?()
            }
        }
    }
}
