// tui/watcher.go
package main

import (
	"os"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/fsnotify/fsnotify"
)

// FileUpdatedMsg is sent when the watched file changes.
type FileUpdatedMsg struct {
	Sections []TodoSection
}

// FileErrorMsg is sent when there's an error reading the file.
type FileErrorMsg struct {
	Err error
}

// ReadAndParse reads a file and parses it into sections.
func ReadAndParse(path string) ([]TodoSection, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return Parse(string(data)), nil
}

// WatchFile returns a tea.Cmd that watches a file for changes and sends
// FileUpdatedMsg or FileErrorMsg when the file is modified.
func WatchFile(path string) tea.Cmd {
	return func() tea.Msg {
		watcher, err := fsnotify.NewWatcher()
		if err != nil {
			return FileErrorMsg{Err: err}
		}

		if err := watcher.Add(path); err != nil {
			watcher.Close()
			return FileErrorMsg{Err: err}
		}

		// Debounce: wait for events to settle
		var timer *time.Timer
		done := make(chan tea.Msg, 1)

		go func() {
			for {
				select {
				case event, ok := <-watcher.Events:
					if !ok {
						return
					}
					if event.Op&(fsnotify.Write|fsnotify.Create) != 0 {
						if timer != nil {
							timer.Stop()
						}
						timer = time.AfterFunc(100*time.Millisecond, func() {
							sections, err := ReadAndParse(path)
							if err != nil {
								done <- FileErrorMsg{Err: err}
							} else {
								done <- FileUpdatedMsg{Sections: sections}
							}
						})
					}
				case err, ok := <-watcher.Errors:
					if !ok {
						return
					}
					done <- FileErrorMsg{Err: err}
					return
				}
			}
		}()

		return <-done
	}
}
