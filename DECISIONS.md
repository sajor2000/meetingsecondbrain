# RecallOS Decisions

## 2026-05-03: HTML Artifact Is Reference Only

The files at `/Users/jcrmacstudio/Desktop/open-design/.od/projects/8cf51484-1b6c-4588-adcb-0afebf87b658/index.html` and `/Users/jcrmacstudio/Desktop/open-design/.od/projects/8cf51484-1b6c-4588-adcb-0afebf87b658/recallos-meeting-second-brain.html` are treated as high-fidelity design artifacts, not source code for the app. The implementation is native SwiftUI with AppKit only for the floating macOS recording panel.

## 2026-05-03: Shared Core Package

Design tokens, domain models, fixtures, and reusable SwiftUI components live in `Packages/RecallOSCore`. Both app targets import this package.

## 2026-05-03: MeetingTask Code Name

The product model is “Task,” but the Swift type is `MeetingTask` to avoid ambiguity with Swift concurrency's generic `Task` type.

## 2026-05-03: Board Mode Approved As Optional Task View

Board mode for meeting-derived task workflow is approved, not the default task experience.

Rationale: the artifact and current product direction include a Kanban-style board for drag-and-drop workflow triage. This deviates from the earlier “not Trello” constraint, so the default task surface remains the Things-style list. Board mode is an optional view for meeting-derived tasks where status movement, owner clarity, and source provenance benefit from columns.

## 2026-05-03: Recording Banner Uses NSPanel

The floating macOS recording banner uses `NSPanel` with a SwiftUI-hosted `RecordingBannerView`. This gives the app correct top-right positioning, all-space behavior, and native macOS material while keeping most UI reusable.

## 2026-05-03: Convex First, Capture Later

Convex schema and stubs are created before real AVFoundation/ScreenCaptureKit capture. This keeps product entities and sync boundaries explicit before implementing provider-specific capture pipelines.
