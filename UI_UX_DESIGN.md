# RecallOS UI/UX Design

## Visual Thesis

RecallOS is a quiet, document-first Apple workspace: white and warm-gray surfaces, restrained hairlines, system typography, and deep teal used only for action, selection, and live recording state.

## Native Translation Rules

- Do not port HTML or CSS directly.
- Use SwiftUI layout, AppKit only where required for macOS banner behavior.
- Use SF/system typography only.
- Use regular and medium weights only.
- Prefer content density and scanability over dashboard decoration.
- Use hairlines, spacing, and typography instead of shadows or gradients.
- Cards are allowed for repeated interactive items: tasks, search results, board cards, and modal-like review units.

## Core Tokens

- Accent: `#0F4C5C`
- Accent dark: `#1A6F86`
- Page title: 22 medium
- Section header: 15 medium
- Body: 14 regular
- Secondary: 13 regular
- Metadata: 12 regular
- Tiny label: 11 medium

Implemented in `Packages/RecallOSCore/Sources/RecallOSCore/Design`.

## macOS Layout

### Sidebar

Width: approximately 228 px.

Groups:

- Coming up
- Library
- Folders

Selected meeting row uses deep teal fill. Non-selected rows should feel like text rows, not heavy cards.

### Notes Editor

The notes editor is the primary surface. It includes:

- Meeting title and metadata.
- Summary block.
- User-authored note sections.
- AI additions with gray text, left vertical bar, and timestamp link.
- Enhancement preview actions.
- Screenshot placeholder/caption area.

### Right Rail

Tabs:

- Transcript
- Ask
- Tasks

Tasks is the default working panel in the design. Transcript and Ask remain immediately accessible.

### Recording Status Bar

Bottom bar states the capture engine and exposes pause/stop-enhance actions. It should stay visually quieter than the floating banner.

## Floating Recording Banner

Technology: AppKit `NSPanel` hosting SwiftUI.

Placement: top-right of visible screen frame, 16 px from top and right edges.

Material: native popover/regular material. No custom shadow.

States:

- Pre-meeting: meeting title, time, Record, dismiss.
- In-progress: mic detected, Record, dismiss.
- Recording: red pulsing dot, elapsed timer, Pause, Stop, no dismiss.
- Ad-hoc: unscheduled call, Record, dismiss.

## iOS Companion

Tabs:

- Today
- Meetings
- Tasks
- Brain

Today is the default tab and should show the next meeting, meeting-derived tasks, and recent meeting context. Quick voice memo capture is a first-class action.

## Task Experience

Default task experience is list-first and Things-inspired:

- Today
- This week
- All open
- Done

List sections:

- Overdue
- Today
- Done today

Task rows must preserve source meeting context and timestamp provenance where available.

Board mode is optional and meant for meeting-derived workflow triage. It is not the default task experience.

## Second Brain

Search-first interface:

- One primary search field.
- Suggestion chips.
- Result cards with source, snippet, and “Show full meeting.”
- Results can point to meetings, transcript segments, tasks, people, topics, and decisions.

## Accessibility

- Use native controls wherever possible.
- Maintain visible focus states.
- Ensure timestamp buttons have accessible labels.
- Avoid relying on color alone for task completion or recording state.
