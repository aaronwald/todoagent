package main

import (
	"testing"
)

// Helper to count all items recursively in a section
func countAllItems(s TodoSection) int {
	n := len(s.Items)
	for _, sub := range s.Subsections {
		n += countAllItems(sub)
	}
	return n
}

func TestParseSimpleCheckboxes(t *testing.T) {
	markdown := "## Tasks\n- [ ] Uncompleted task\n- [x] Completed task"
	sections := Parse(markdown)

	if len(sections) != 1 {
		t.Fatalf("expected 1 section, got %d", len(sections))
	}
	if sections[0].Heading != "Tasks" {
		t.Errorf("expected heading 'Tasks', got %q", sections[0].Heading)
	}
	if sections[0].Level != 2 {
		t.Errorf("expected level 2, got %d", sections[0].Level)
	}
	if len(sections[0].Items) != 2 {
		t.Fatalf("expected 2 items, got %d", len(sections[0].Items))
	}
	if sections[0].Items[0].Completed {
		t.Error("expected first item to be uncompleted")
	}
	if sections[0].Items[0].Title != "Uncompleted task" {
		t.Errorf("expected title 'Uncompleted task', got %q", sections[0].Items[0].Title)
	}
	if !sections[0].Items[1].Completed {
		t.Error("expected second item to be completed")
	}
	if sections[0].Items[1].Title != "Completed task" {
		t.Errorf("expected title 'Completed task', got %q", sections[0].Items[1].Title)
	}
}

func TestParseNestedHeadings(t *testing.T) {
	markdown := "## SSMD\n### Active\n- [ ] Task A\n### Pending\n- [ ] Task B\n- [ ] Task C"
	sections := Parse(markdown)

	if len(sections) != 1 {
		t.Fatalf("expected 1 section, got %d", len(sections))
	}
	if sections[0].Heading != "SSMD" {
		t.Errorf("expected heading 'SSMD', got %q", sections[0].Heading)
	}
	if len(sections[0].Subsections) != 2 {
		t.Fatalf("expected 2 subsections, got %d", len(sections[0].Subsections))
	}
	if sections[0].Subsections[0].Heading != "Active" {
		t.Errorf("expected subsection heading 'Active', got %q", sections[0].Subsections[0].Heading)
	}
	if len(sections[0].Subsections[0].Items) != 1 {
		t.Errorf("expected 1 item in Active, got %d", len(sections[0].Subsections[0].Items))
	}
	if sections[0].Subsections[1].Heading != "Pending" {
		t.Errorf("expected subsection heading 'Pending', got %q", sections[0].Subsections[1].Heading)
	}
	if len(sections[0].Subsections[1].Items) != 2 {
		t.Errorf("expected 2 items in Pending, got %d", len(sections[0].Subsections[1].Items))
	}
}

func TestParseBoldTitleAndTags(t *testing.T) {
	markdown := "## Work\n- [ ] **Multi-exchange secmaster** [ssmd] - Feb 7"
	sections := Parse(markdown)

	if len(sections) != 1 {
		t.Fatalf("expected 1 section, got %d", len(sections))
	}
	if len(sections[0].Items) != 1 {
		t.Fatalf("expected 1 item, got %d", len(sections[0].Items))
	}
	item := sections[0].Items[0]
	if item.Title != "Multi-exchange secmaster" {
		t.Errorf("expected title 'Multi-exchange secmaster', got %q", item.Title)
	}
	if len(item.Tags) != 1 || item.Tags[0] != "ssmd" {
		t.Errorf("expected tags [ssmd], got %v", item.Tags)
	}
}

func TestParseAllCompletedSection(t *testing.T) {
	markdown := "## Done\n- [x] Task A\n- [x] Task B"
	sections := Parse(markdown)

	if len(sections) != 1 {
		t.Fatalf("expected 1 section, got %d", len(sections))
	}
	if !sections[0].AllCompleted {
		t.Error("expected AllCompleted to be true")
	}
}

func TestParseLineNumbers(t *testing.T) {
	markdown := "## Section\n- [ ] First\n- [ ] Second"
	sections := Parse(markdown)

	if len(sections) != 1 {
		t.Fatalf("expected 1 section, got %d", len(sections))
	}
	if len(sections[0].Items) != 2 {
		t.Fatalf("expected 2 items, got %d", len(sections[0].Items))
	}
	if sections[0].Items[0].Line != 2 {
		t.Errorf("expected line 2, got %d", sections[0].Items[0].Line)
	}
	if sections[0].Items[1].Line != 3 {
		t.Errorf("expected line 3, got %d", sections[0].Items[1].Line)
	}
}

func TestIgnoreNonCheckboxContent(t *testing.T) {
	markdown := "## Summary\n| Col1 | Col2 |\n|------|------|\n| a    | b    |\n\nSome paragraph text.\n\n- [ ] Real task"
	sections := Parse(markdown)

	if len(sections) != 1 {
		t.Fatalf("expected 1 section, got %d", len(sections))
	}
	if len(sections[0].Items) != 1 {
		t.Fatalf("expected 1 item, got %d", len(sections[0].Items))
	}
	if sections[0].Items[0].Title != "Real task" {
		t.Errorf("expected title 'Real task', got %q", sections[0].Items[0].Title)
	}
}

func TestParseDeeplyNested(t *testing.T) {
	markdown := "## Domain\n### Category\n#### Subcategory\n- [ ] Deep task"
	sections := Parse(markdown)

	if len(sections) != 1 {
		t.Fatalf("expected 1 section, got %d", len(sections))
	}
	if sections[0].Heading != "Domain" {
		t.Errorf("expected heading 'Domain', got %q", sections[0].Heading)
	}
	if len(sections[0].Subsections) != 1 {
		t.Fatalf("expected 1 subsection, got %d", len(sections[0].Subsections))
	}
	if sections[0].Subsections[0].Heading != "Category" {
		t.Errorf("expected subsection heading 'Category', got %q", sections[0].Subsections[0].Heading)
	}
	if len(sections[0].Subsections[0].Subsections) != 1 {
		t.Fatalf("expected 1 sub-subsection, got %d", len(sections[0].Subsections[0].Subsections))
	}
	sub := sections[0].Subsections[0].Subsections[0]
	if sub.Heading != "Subcategory" {
		t.Errorf("expected sub-subsection heading 'Subcategory', got %q", sub.Heading)
	}
	if len(sub.Items) != 1 {
		t.Fatalf("expected 1 item, got %d", len(sub.Items))
	}
	if sub.Items[0].Title != "Deep task" {
		t.Errorf("expected title 'Deep task', got %q", sub.Items[0].Title)
	}
}

func TestParseEmptyContent(t *testing.T) {
	sections := Parse("")
	if len(sections) != 0 {
		t.Errorf("expected 0 sections, got %d", len(sections))
	}
}

func TestParseRealWorldTodo(t *testing.T) {
	markdown := `# My Todo List
## Work
### Active
- [ ] **Multi-exchange secmaster** [ssmd] - Feb 7
- [ ] **API integration** [api/v2] - Feb 10
### Completed
- [x] **Setup CI pipeline** [devops]
- [x] Code review for PR #42
## Personal
- [ ] Buy groceries
- [x] Pay electric bill
## Archive
- [x] Old task A
- [x] Old task B`

	sections := Parse(markdown)

	// Should have 3 top-level sections: Work, Personal, Archive
	if len(sections) != 3 {
		t.Fatalf("expected 3 sections, got %d", len(sections))
	}

	// Work section
	work := sections[0]
	if work.Heading != "Work" {
		t.Errorf("expected 'Work', got %q", work.Heading)
	}
	if len(work.Subsections) != 2 {
		t.Fatalf("expected 2 subsections in Work, got %d", len(work.Subsections))
	}
	if work.AllCompleted {
		t.Error("Work section should not be all completed")
	}

	// Work > Active
	active := work.Subsections[0]
	if active.Heading != "Active" {
		t.Errorf("expected 'Active', got %q", active.Heading)
	}
	if len(active.Items) != 2 {
		t.Fatalf("expected 2 items in Active, got %d", len(active.Items))
	}
	if active.Items[0].Title != "Multi-exchange secmaster" {
		t.Errorf("expected 'Multi-exchange secmaster', got %q", active.Items[0].Title)
	}
	if len(active.Items[0].Tags) != 1 || active.Items[0].Tags[0] != "ssmd" {
		t.Errorf("expected tags [ssmd], got %v", active.Items[0].Tags)
	}
	if active.Items[1].Title != "API integration" {
		t.Errorf("expected 'API integration', got %q", active.Items[1].Title)
	}
	if len(active.Items[1].Tags) != 1 || active.Items[1].Tags[0] != "api/v2" {
		t.Errorf("expected tags [api/v2], got %v", active.Items[1].Tags)
	}

	// Work > Completed
	completed := work.Subsections[1]
	if completed.Heading != "Completed" {
		t.Errorf("expected 'Completed', got %q", completed.Heading)
	}
	if len(completed.Items) != 2 {
		t.Fatalf("expected 2 items in Completed, got %d", len(completed.Items))
	}
	if !completed.AllCompleted {
		t.Error("Completed subsection should be all completed")
	}

	// Personal section
	personal := sections[1]
	if personal.Heading != "Personal" {
		t.Errorf("expected 'Personal', got %q", personal.Heading)
	}
	if len(personal.Items) != 2 {
		t.Fatalf("expected 2 items in Personal, got %d", len(personal.Items))
	}
	if personal.AllCompleted {
		t.Error("Personal section should not be all completed")
	}

	// Archive section — all completed
	archive := sections[2]
	if archive.Heading != "Archive" {
		t.Errorf("expected 'Archive', got %q", archive.Heading)
	}
	if !archive.AllCompleted {
		t.Error("Archive section should be all completed")
	}
}

func TestParseDetails(t *testing.T) {
	markdown := "## Section\n- [ ] Task with details\n  Some detail line\n  Another detail"
	sections := Parse(markdown)

	if len(sections[0].Items) != 1 {
		t.Fatalf("expected 1 item, got %d", len(sections[0].Items))
	}
	item := sections[0].Items[0]
	if len(item.Details) != 2 {
		t.Fatalf("expected 2 details, got %d", len(item.Details))
	}
	if item.Details[0] != "Some detail line" {
		t.Errorf("detail[0] = %q, want %q", item.Details[0], "Some detail line")
	}
	if item.Details[1] != "Another detail" {
		t.Errorf("detail[1] = %q, want %q", item.Details[1], "Another detail")
	}
}

func TestParseDetailsFlushOnNewCheckbox(t *testing.T) {
	markdown := "## Section\n- [ ] First task\n  Detail for first\n- [ ] Second task"
	sections := Parse(markdown)

	if len(sections[0].Items) != 2 {
		t.Fatalf("expected 2 items, got %d", len(sections[0].Items))
	}
	if len(sections[0].Items[0].Details) != 1 {
		t.Errorf("expected 1 detail on first item, got %d", len(sections[0].Items[0].Details))
	}
	if sections[0].Items[0].Details[0] != "Detail for first" {
		t.Errorf("detail = %q", sections[0].Items[0].Details[0])
	}
	if len(sections[0].Items[1].Details) != 0 {
		t.Errorf("expected 0 details on second item, got %d", len(sections[0].Items[1].Details))
	}
}

func TestItemCountAcrossNesting(t *testing.T) {
	markdown := `## Root
- [ ] Root item
### Sub A
- [x] Sub A item 1
- [x] Sub A item 2
### Sub B
- [ ] Sub B item 1
#### Deep
- [x] Deep item`

	sections := Parse(markdown)

	if len(sections) != 1 {
		t.Fatalf("expected 1 section, got %d", len(sections))
	}
	root := sections[0]

	// Root should have 1 direct item
	if len(root.Items) != 1 {
		t.Errorf("expected 1 direct item in Root, got %d", len(root.Items))
	}

	// Root should have 2 subsections
	if len(root.Subsections) != 2 {
		t.Fatalf("expected 2 subsections, got %d", len(root.Subsections))
	}

	// Sub A: 2 items, all completed
	subA := root.Subsections[0]
	if len(subA.Items) != 2 {
		t.Errorf("expected 2 items in Sub A, got %d", len(subA.Items))
	}
	if !subA.AllCompleted {
		t.Error("Sub A should be all completed")
	}

	// Sub B: 1 direct item, 1 subsection
	subB := root.Subsections[1]
	if len(subB.Items) != 1 {
		t.Errorf("expected 1 item in Sub B, got %d", len(subB.Items))
	}
	if len(subB.Subsections) != 1 {
		t.Fatalf("expected 1 subsection in Sub B, got %d", len(subB.Subsections))
	}

	// Sub B > Deep: 1 item, completed
	deep := subB.Subsections[0]
	if len(deep.Items) != 1 {
		t.Errorf("expected 1 item in Deep, got %d", len(deep.Items))
	}
	if !deep.AllCompleted {
		t.Error("Deep should be all completed")
	}

	// Sub B is NOT all completed (Sub B item 1 is uncompleted, even though Deep items are completed)
	if subB.AllCompleted {
		t.Error("Sub B should not be all completed (has uncompleted item)")
	}

	// Root is NOT all completed
	if root.AllCompleted {
		t.Error("Root should not be all completed")
	}

	// Total items across entire tree
	total := countAllItems(root)
	if total != 5 {
		t.Errorf("expected 5 total items, got %d", total)
	}
}
