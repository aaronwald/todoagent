import Testing
@testable import TodoAgent

@Test func parseSimpleCheckboxes() {
    let markdown = """
    ## Tasks
    - [ ] Uncompleted task
    - [x] Completed task
    """
    let sections = MarkdownParser.parse(content: markdown)
    #expect(sections.count == 1)
    #expect(sections[0].heading == "Tasks")
    #expect(sections[0].level == 2)
    #expect(sections[0].items.count == 2)
    #expect(sections[0].items[0].isCompleted == false)
    #expect(sections[0].items[0].title == "Uncompleted task")
    #expect(sections[0].items[1].isCompleted == true)
}

@Test func parseNestedHeadings() {
    let markdown = """
    ## SSMD
    ### Active
    - [ ] Task A
    ### Pending
    - [ ] Task B
    - [ ] Task C
    """
    let sections = MarkdownParser.parse(content: markdown)
    #expect(sections.count == 1)
    #expect(sections[0].heading == "SSMD")
    #expect(sections[0].subsections.count == 2)
    #expect(sections[0].subsections[0].heading == "Active")
    #expect(sections[0].subsections[0].items.count == 1)
    #expect(sections[0].subsections[1].heading == "Pending")
    #expect(sections[0].subsections[1].items.count == 2)
}

@Test func parseBoldTitleAndTags() {
    let markdown = """
    ## Work
    - [ ] **Multi-exchange secmaster** [ssmd] - Feb 7
    """
    let sections = MarkdownParser.parse(content: markdown)
    #expect(sections[0].items[0].title == "Multi-exchange secmaster")
    #expect(sections[0].items[0].tags == ["ssmd"])
}

@Test func parseAllCompletedSection() {
    let markdown = """
    ## Done
    - [x] Task A
    - [x] Task B
    """
    let sections = MarkdownParser.parse(content: markdown)
    #expect(sections[0].allCompleted == true)
}

@Test func parseLineNumbers() {
    let markdown = """
    ## Section
    - [ ] First
    - [ ] Second
    """
    let sections = MarkdownParser.parse(content: markdown)
    #expect(sections[0].items[0].line == 2)
    #expect(sections[0].items[1].line == 3)
}

@Test func ignoreNonCheckboxContent() {
    let markdown = """
    ## Summary
    | Col1 | Col2 |
    |------|------|
    | a    | b    |

    Some paragraph text.

    - [ ] Real task
    """
    let sections = MarkdownParser.parse(content: markdown)
    #expect(sections[0].items.count == 1)
    #expect(sections[0].items[0].title == "Real task")
}

@Test func parseDeeplyNested() {
    let markdown = """
    ## Domain
    ### Category
    #### Subcategory
    - [ ] Deep task
    """
    let sections = MarkdownParser.parse(content: markdown)
    #expect(sections[0].heading == "Domain")
    #expect(sections[0].subsections[0].heading == "Category")
    #expect(sections[0].subsections[0].subsections[0].heading == "Subcategory")
    #expect(sections[0].subsections[0].subsections[0].items[0].title == "Deep task")
}

@Test func parseEmptyContent() {
    let sections = MarkdownParser.parse(content: "")
    #expect(sections.isEmpty)
}
