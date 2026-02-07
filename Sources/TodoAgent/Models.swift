import Foundation

struct TodoItem: Identifiable, Equatable, Sendable {
    let id = UUID()
    let title: String
    let isCompleted: Bool
    let line: Int
    let tags: [String]

    static func == (lhs: TodoItem, rhs: TodoItem) -> Bool {
        lhs.title == rhs.title && lhs.isCompleted == rhs.isCompleted && lhs.line == rhs.line
    }
}

struct TodoSection: Identifiable, Sendable {
    let id = UUID()
    let heading: String
    let level: Int
    let items: [TodoItem]
    let subsections: [TodoSection]
    let allCompleted: Bool
}

struct TodoFile: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let path: String
    let sections: [TodoSection]
}
