import Testing
@testable import TodoAgent

@Test func parseRealWorldTodo() {
    let markdown = """
    # Project Roadmap

    ## SSMD (Market Data)

    ### Active
    - [ ] **Multi-exchange secmaster** [ssmd] - Feb 7
    - [ ] **Spread capture research** [ssmd] - Feb 1

    ### Pending

    #### Data Pipeline
    - [ ] Kraken Futures WebSocket connector [ssmd]
    - [x] Pair ID namespace prefix migration [ssmd] - Feb 7

    #### Agent & Signals
    - [ ] SQLite checkpointer

    ### Completed (Recent)
    - [x] **Polymarket connector** [ssmd/varlab] - Feb 6
    - [x] **Momentum signal research** [ssmd] - Feb 1

    ## Platform Infrastructure

    ### Pending
    - [ ] Migrate Velero backups to Temporal
    - [ ] Disaster Recovery validation

    ### Completed (Recent)
    - [x] Sync Google Drive to Brooklyn NAS
    """

    let sections = MarkdownParser.parse(content: markdown)

    // Top-level sections
    #expect(sections.count == 2)
    #expect(sections[0].heading == "SSMD (Market Data)")
    #expect(sections[1].heading == "Platform Infrastructure")

    // SSMD subsections
    #expect(sections[0].subsections.count == 3)
    #expect(sections[0].subsections[0].heading == "Active")
    #expect(sections[0].subsections[0].items.count == 2)

    // Pending has sub-subsections
    let pending = sections[0].subsections[1]
    #expect(pending.heading == "Pending")
    #expect(pending.subsections.count == 2)
    #expect(pending.subsections[0].heading == "Data Pipeline")
    #expect(pending.subsections[0].items.count == 2)

    // Completed section should be allCompleted
    let completed = sections[0].subsections[2]
    #expect(completed.heading == "Completed (Recent)")
    #expect(completed.allCompleted == true)

    // Tags parsed correctly
    #expect(sections[0].subsections[0].items[0].tags == ["ssmd"])
    #expect(sections[0].subsections[0].items[0].title == "Multi-exchange secmaster")

    // Platform infra
    #expect(sections[1].subsections[0].heading == "Pending")
    #expect(sections[1].subsections[0].items.count == 2)
    #expect(sections[1].subsections[1].allCompleted == true)
}

@Test func itemCountAcrossNesting() {
    let markdown = """
    ## Root
    - [ ] A
    ### Sub1
    - [ ] B
    - [x] C
    #### Deep
    - [ ] D
    """
    let sections = MarkdownParser.parse(content: markdown)
    #expect(sections[0].allCompleted == false)
    #expect(sections[0].items.count == 1)
    #expect(sections[0].subsections[0].items.count == 2)
    #expect(sections[0].subsections[0].subsections[0].items.count == 1)
}
