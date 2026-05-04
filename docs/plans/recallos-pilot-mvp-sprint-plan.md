# RecallOS Pilot MVP Sprint Plan

Created: 2026-05-04

## Summary

RecallOS will ship toward a Pilot MVP through milestone-sprints, not fixed calendar weeks. The current native SwiftUI scaffold is the base: Core tokens, models, reusable components, macOS/iOS shells, Convex schema stubs, task filters, and store-backed board movement exist. The next goal is to replace sample-only app surfaces with repository-backed data flow, then add real sync, capture, transcription, AI enhancement, search, iOS companion completion, and pilot QA.

## Sprint Backlog

### Sprint 0: Stabilize Planning Baseline

- Refresh feature and UI/code audits after task-store and repository-boundary work.
- Keep README, `SPEC.md`, and `UI_UX_DESIGN.md` aligned with what is actually implemented.
- Validate Core tests and both Xcode targets.

### Sprint 1: App State and Convex Data Boundary

- Add repository protocols for meetings, tasks, transcript segments, screenshots, people/topics/decisions, settings, and search.
- Add sync-backed model identifiers via optional `convexID` while preserving UUID local identity.
- Add fixture repositories and shared stores so app shells render from stores instead of direct fixtures.
- Add `ConvexMobile` dependency and an app-layer `ConvexRecallOSRepository` boundary.
- Add DTO mapping tests that keep Convex document IDs separate from local UUID-backed model identity.

### Sprint 2: Convex Schema and Sync Completeness

- Expand Convex functions into full CRUD/query boundaries for core entities.
- Add dev seed data for the sample meeting.
- Implement live Convex subscriptions and task move mutations through `ConvexRecallOSRepository`.
- Add optimistic update rollback and sync error UI for failed mutations.

### Sprint 3: Calendar and Meeting Lifecycle

- Add EventKit-backed calendar source store on macOS.
- Implement scheduled, detected, recording, enhancing, and completed lifecycle state flow.
- Connect sidebar, recording status bar, and banner transitions to lifecycle state.

### Sprint 4: Recording and Capture

- Add macOS microphone capture through AVFoundation.
- Add screenshot capture through ScreenCaptureKit.
- Add iOS quick voice memo capture through AVFoundation.
- Persist capture artifacts locally with upload hooks.

### Sprint 5: Transcription and Hybrid Notes

- Add transcription provider protocol with hybrid-cloud default and mock/local test providers.
- Persist transcript segments with speaker, timestamps, and confidence.
- Wire transcript rail and timestamp links to repository-backed transcript data.
- Add live notes storage and enhancement-ready note blocks.

### Sprint 6: AI Enhancement and Task Extraction

- Add AI provider protocol for summaries, hybrid note additions, decisions, topics, and tasks.
- Add task extraction review with accept, reject, edit, and short undo.
- Persist accepted AI output and provenance through repositories.

### Sprint 7: Second Brain Search

- Implement search over meetings, transcript segments, tasks, people, topics, and decisions.
- Return result cards with source, snippet, timestamp, and meeting navigation target.
- Wire macOS Ask rail and iOS Brain tab to the shared search store.

### Sprint 8: iOS Companion Completion

- Replace remaining iOS static text with synced Today, Meetings, Tasks, and Brain data.
- Add quick voice memo save flow that creates transcript/task candidates.
- Keep iOS meeting view read-only for Pilot MVP.

### Sprint 9: Pilot QA and Release Readiness

- Add screenshot previews for macOS shell, banner states, iOS Today, iOS Tasks, and Brain.
- Add accessibility checks for timestamp links, recording state, task rows, and keyboard navigation.
- Add privacy/settings surfaces for capture, transcription, AI provider, retention, and vocabulary.
- Run final feature audit against `SPEC.md` and `UI_UX_DESIGN.md`.

## Acceptance Baseline

- Core tests pass with repository/store coverage.
- macOS and iOS builds pass after every sprint.
- Convex checks pass once live backend implementation begins.
- No feature is marked complete without code and validation evidence.
