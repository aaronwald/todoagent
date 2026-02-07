import Testing
@testable import TodoAgent

@Test func todoItemCreation() {
    let item = TodoItem(title: "Fix bug", isCompleted: false, line: 5, tags: ["ssmd"])
    #expect(item.title == "Fix bug")
    #expect(item.isCompleted == false)
    #expect(item.line == 5)
    #expect(item.tags == ["ssmd"])
}

@Test func todoSectionCreation() {
    let item = TodoItem(title: "Task 1", isCompleted: false, line: 3, tags: [])
    let section = TodoSection(
        heading: "Active",
        level: 3,
        items: [item],
        subsections: [],
        allCompleted: false
    )
    #expect(section.heading == "Active")
    #expect(section.level == 3)
    #expect(section.items.count == 1)
}

@Test func todoFileCreation() {
    let file = TodoFile(
        name: "TODO.md",
        path: "/tmp/TODO.md",
        sections: []
    )
    #expect(file.name == "TODO.md")
}
