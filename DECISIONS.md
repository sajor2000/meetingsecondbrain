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

## 2026-05-04: Explicit Demo Runtime Until Live Convex Adapter Exists

The macOS and iOS apps run with fixture-backed demo data by default for the foundation PR. `RECALLOS_USE_LIVE_CONVEX=1` is an explicit opt-in, but it now produces a visible configuration error until the Swift Convex adapter has real list/query/mutation behavior.

Rationale: the Pilot MVP plan keeps live Convex disabled until repository methods are implemented and tested. A requested live mode must not silently fall back to fixtures, because that hides deployment/configuration mistakes.

## 2026-05-04: RecallOS Convex Tables Are The Pilot Namespace

The `recallOS*` Convex tables are the canonical Pilot MVP namespace for the new native RecallOS client. Existing unprefixed meeting/task/document tables remain legacy data until a dedicated migration/deprecation sprint decides whether to backfill, quarantine, or remove them.

Rationale: PR #11 introduces RecallOS side by side with the older implementation. The new public RecallOS functions read and mutate only the `recallOS*` tables, so future schema work should treat cross-namespace migration as explicit Sprint 2+ work rather than assuming both models stay in sync automatically.
