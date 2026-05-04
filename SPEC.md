# RecallOS Specification

## Goal

Build a native macOS and iOS app called RecallOS: a calm meeting second brain that captures meetings, supports user-authored notes, enhances notes with AI additions, extracts tasks, and makes prior meetings searchable by person, topic, decision, and action item.

## Source Artifact

Primary design artifact:

- `/Users/jcrmacstudio/Desktop/open-design/.od/projects/8cf51484-1b6c-4588-adcb-0afebf87b658/recallos-meeting-second-brain.html`

Secondary entry file:

- `/Users/jcrmacstudio/Desktop/open-design/.od/projects/8cf51484-1b6c-4588-adcb-0afebf87b658/index.html`

The artifact is a reference for visual hierarchy, interaction intent, copy, and feature coverage. The native app must use SwiftUI/AppKit/UIKit patterns rather than porting the HTML.

## Product Principles

- Calm by default.
- Content is the interface.
- SF/system typography only.
- Use only regular `400` and medium `500` weights.
- Deep teal accent: `#0F4C5C`.
- No gradients, no shadows, no heavy chrome.
- User text is primary system text.
- AI additions are gray, left-barred, and include timestamp provenance in `↗ MM:SS` format.

## Functional Requirements

### Shared Core

- Design tokens: `Color.appAccent`, `Color.appAccentDark`, `AppFont`, `AppSpacing`, `AppCorners`, `AppMotion`.
- Models: `Meeting`, `TranscriptSegment`, `MeetingTask`, `MeetingScreenshot`, `CalendarEvent`, `Person`, `Topic`, `MeetingDecision`.
- Reusable views: hybrid note block, timestamp link, task row, search result card, recording banner, task board.

Evidence: implemented under `packages/RecallOSCore`.

### macOS App

- Three-pane layout: sidebar, meeting notes editor, right rail.
- Sidebar groups: Coming up, Library, Folders.
- Meeting editor with metadata, summary block, hybrid note blocks, enhancement preview.
- Right rail tabs: Transcript, Ask, Tasks.
- Recording status bar.
- Floating AppKit `NSPanel` banner, top-right, 16 px from visible screen edges.
- Banner states: pre-meeting, in-progress, recording, ad-hoc.
- Recording state: red pulsing dot, elapsed timer, pause and stop actions, no dismiss action.

Evidence: implemented under `apps/RecallOSMac`.

### Notes

- Live notes view.
- Raw transcript rail.
- Hybrid enhanced notes view.
- Summary block.
- Timestamp links.
- Screenshot model and placeholder surface.

Evidence: UI and models implemented; real capture and enhancement are not wired.

### Tasks

- Task extraction review surface.
- Filters for Today, This week, All open, Done.
- Grouped list: Overdue, Today, Done today.
- Source meeting badge/provenance.
- Priority pills.
- Keyboard shortcut intent: `j/k`, `x`, `e`, `n`.
- Optional Kanban board with drag-ready cards.

Evidence: list and board UI implemented with sample data; persistence and drag mutations are not wired.

### iOS App

- Tabs: Today, Meetings, Tasks, Brain.
- Today screen.
- Quick voice memo capture.
- Read-only meeting view.
- Tasks tab.
- Brain search tab.

Evidence: implemented under `apps/RecallOSiOS`; real recording and sync are not wired.

### Convex Backend

Tables required:

- meetings
- transcriptSegments
- tasks
- screenshots
- documents
- templates
- recipes
- calendarSources
- folders
- vocabulary
- settings
- people
- topics
- decisions

Evidence: schema and starter functions exist under `convex`.

## Validation Requirements

- Generate Xcode project with XcodeGen.
- Build macOS target.
- Build iOS target.
- Run Swift package unit tests.
- Add screenshot previews for key screens.
- Run feature audit against this file and `UI_UX_DESIGN.md`.

## Phased Plan

Phase 1: Native shell and model foundation.

Phase 2: Persistence and Convex integration.

Phase 3: Recording, screenshot capture, transcription provider protocols, and local transcript lifecycle.

Phase 4: AI enhancement, task extraction review, undo, and provenance linking.

Phase 5: Second brain search, people/topic/decision graph, and iOS sync.

Phase 6: production QA: accessibility, performance, privacy, screenshots, real meeting scenarios.
