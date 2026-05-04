# RecallOS Sprint 2 Local Persistence Plan

Created: 2026-05-04
Status: completed

## Summary

Sprint 2 turns RecallOS from a fixture-backed native shell into a local-first Mac app that can create, record with mock transcript streaming, stop, enhance, extract tasks, quit, reopen, and recover the same meeting data. This plan intentionally defers live Convex reads/writes, real audio engines, and broad iOS polish. The durable boundary is still `RecallOSRepository`; the next implementation should add a SwiftData-backed repository in the app layer while keeping `packages/RecallOSCore` portable and provider-based.

This updates the older `docs/plans/recallos-pilot-mvp-sprint-plan.md` sequencing: Convex remains important, but it should not be Sprint 2 until the Mac local flow is reliable.

## Problem Frame

The current app starts cleanly and demonstrates the Mac-first recording workflow with fixtures and mock providers. That is enough for UI iteration, but not enough for a product surface: a user can create or enhance a meeting and then lose it after restart. The next useful product milestone is persistence that survives app relaunch without coupling Core to SwiftData or pretending Convex is live.

## Scope

In scope:

- Add local SwiftData persistence for meetings, transcript segments, note blocks, AI additions, tasks, screenshots metadata, decisions, topics, people, calendar events, and settings needed by the existing repository protocol.
- Keep `RecallOSAppStore` and UI callers talking to `RecallOSRepository`.
- Make `RecallOSStoreFactory` choose the local persistent repository by default, with fixture fallback for previews/tests.
- Preserve UUID local identity and optional `convexID` fields so future Convex sync can attach without a migration rewrite.
- Add tests or verification coverage for reload persistence and repository behavior.

Out of scope:

- Live Convex implementation or subscriptions.
- Real AVFoundation, ScreenCaptureKit, Parakeet, WhisperKit, OpenRouter, Cognee, or Mac Studio services.
- Cloud sync conflict resolution.
- Authentication or multi-user data sharing.
- Reworking the visual design beyond what persistence wiring requires.

## Key Decisions

1. Put SwiftData in `apps/Shared`, not `packages/RecallOSCore`.

   Rationale: Core currently builds as a portable Swift package for macOS and iOS with simple `Codable`, `Sendable` domain models. Adding `@Model` annotations there would couple domain models to persistence mechanics and make future repository adapters harder.

2. Use persistence DTOs that map to Core models.

   Rationale: SwiftData models can be optimized for relationships, cascade behavior, and storage constraints while Core models remain stable API types for UI, providers, tests, and future sync.

3. Seed sample data only when the local store is empty.

   Rationale: The app should still feel alive on first launch, but user-created local data must not be overwritten by fixtures.

4. Keep all write paths repository-backed.

   Rationale: `RecallOSAppStore` already centralizes create, select, record, enhance, task move, and search flows. Persistence should slot under that layer rather than leaking SwiftData calls into views.

5. Keep local search provider in memory for this sprint.

   Rationale: `LocalSecondBrainSearchProvider` already searches the app store's loaded meetings and tasks. A persisted full-text index can wait until the data survives restart.

## Existing Patterns To Follow

- Repository contract: `packages/RecallOSCore/Sources/RecallOSCore/Repositories/RecallOSRepositories.swift`
- Store orchestration: `packages/RecallOSCore/Sources/RecallOSCore/Stores/RecallOSAppStore.swift`
- Fixture adapter behavior: `packages/RecallOSCore/Sources/RecallOSCore/Repositories/FixtureRecallOSRepository.swift`
- App repository selection: `apps/Shared/Sources/RecallOSStoreFactory.swift`
- Convex as future boundary: `apps/Shared/Sources/ConvexRecallOSRepository.swift`
- Current recording flow tests: `packages/RecallOSCore/Tests/RecallOSCoreTests/ModelTests.swift`

## Implementation Units

### Unit 1: SwiftData Schema And Mapping Layer

Files:

- Add `apps/Shared/Sources/Persistence/RecallOSPersistentModels.swift`
- Add `apps/Shared/Sources/Persistence/RecallOSPersistenceMapper.swift`
- Update `RecallOS.xcodeproj/project.pbxproj` to include new shared persistence files in Mac and iOS app targets.

Responsibilities:

- Define SwiftData models for persisted meetings and owned child records.
- Store `id` and `convexID` for every sync-backed entity that currently has those fields.
- Map Core `Meeting` to/from SwiftData meeting records, including attendees, transcript segments, note blocks, AI additions, tasks, screenshots, decisions, and topics.
- Represent optional child collections as empty arrays at the Core boundary.
- Preserve transcript ordering by `startTime`.
- Preserve task source metadata: `sourceMeetingID`, `sourceMeetingTitle`, `sourceTimestamp`, `extractionConfidence`.

Test scenarios:

- A Core `Meeting` with transcript, hybrid notes, tasks, decisions, topics, and attendees round-trips through the mapper without losing IDs.
- A meeting with no child collections maps back with empty arrays, not nil-like missing state.
- Transcript segments remain sorted by `startTime` after mapping.
- Optional `convexID` values survive mapping for future sync.

### Unit 2: SwiftData Repository Adapter

Files:

- Add `apps/Shared/Sources/Persistence/SwiftDataRecallOSRepository.swift`
- Update `apps/Shared/Sources/RecallOSStoreFactory.swift`

Responsibilities:

- Implement `RecallOSRepository` against SwiftData.
- Provide `listMeetings`, `createMeeting`, `updateMeeting`, `listTasks`, `moveTasks`, `listTranscriptSegments`, `listScreenshots`, `listPeople`, `listTopics`, `listDecisions`, `listSettings`, and `searchSecondBrain`.
- Seed `SampleData.meeting` and `SampleData.tasks` only when the persistent store has no meetings.
- Keep `searchSecondBrain` simple: either call through to in-memory filtering after loading Core models, or return persisted search result equivalents. Prefer the simpler path for this sprint.
- Use fixture repository only if SwiftData container creation fails, and surface a specific `syncError`/workflow message rather than a loading dead end.

Test scenarios:

- Empty local store seeds the sample meeting once.
- `createMeeting` persists a new meeting and it appears in a fresh repository instance.
- `updateMeeting` persists enhanced notes, transcript segments, completed status, and extracted tasks.
- `listTasks(forMeeting:)` filters meeting tasks correctly and `listTasks(forMeeting: nil)` returns all tasks.
- `moveTasks` persists status and `completedAt` changes across repository reload.
- `listPeople`, `listTopics`, and `listDecisions` derive graph data from persisted meetings.

### Unit 3: Store Factory And App Launch Behavior

Files:

- Update `apps/Shared/Sources/RecallOSStoreFactory.swift`
- Update `apps/RecallOSMac/Sources/RecallOSMacApp.swift` if dependency injection needs app-level container ownership.
- Update `apps/RecallOSiOS/Sources/RecallOSiOSApp.swift` if dependency injection needs app-level container ownership.

Responsibilities:

- Build a SwiftData-backed `RecallOSAppStore` for normal app launch.
- Keep a stable local store URL/container name for Mac and iOS.
- Keep `CONVEX_URL` ignored until `ConvexRecallOSRepository` implements real reads/writes.
- Avoid duplicate store creation if SwiftUI recreates root views.
- Make launch recover gracefully if local store initialization fails.

Test scenarios:

- App factory creates a loadable store when `CONVEX_URL` is present.
- Failed local container setup falls back to fixture data with a specific visible error.
- Multiple root view creations do not duplicate seed meetings.

### Unit 4: End-To-End Local Recording Persistence

Files:

- Update `packages/RecallOSCore/Sources/RecallOSCore/Stores/RecallOSAppStore.swift` only if repository semantics require it.
- Add app-level verification helpers or tests if the Xcode project test layout supports them.
- Extend `packages/RecallOSCore/Tests/RecallOSCoreTests/ModelTests.swift` only for repository-independent store behavior.

Responsibilities:

- Ensure the existing flow persists through the repository after every durable transition:
  - create meeting
  - start mock recording
  - append transcript segments
  - stop and enhance
  - extracted tasks saved
  - task moves saved
- Decide whether live transcript segments should be written on every segment or batched at stop for Sprint 2. Prefer writing at stop unless the UI needs crash recovery mid-recording.
- Keep selected meeting behavior from commit `c041e5d`: recording data follows `recordingSession.meetingID`.

Test scenarios:

- Create meeting, record mock transcript, stop/enhance, construct a fresh store/repository, and verify the meeting reopens completed with transcript, hybrid notes, and tasks.
- Navigate to another meeting during mock recording, stop, reload, and verify the recording meeting was updated while selected meeting state did not corrupt data.
- Move an extracted task to Done, reload, and verify status and `completedAt` persist.

### Unit 5: iOS Read Path From Shared Local Store

Files:

- Update `apps/RecallOSiOS/Sources/IOSContentView.swift` only as needed for persisted loading states.
- Update shared factory/persistence files from Units 2 and 3.

Responsibilities:

- Let iOS load the same repository shape as Mac.
- Keep iOS as a companion read surface in this sprint.
- Avoid adding iOS-first recording or voice memo persistence until the Mac flow is stable.

Test scenarios:

- iOS target builds with the shared SwiftData repository.
- iOS Today, Meetings, Tasks, and Brain screens render from persisted data rather than fixtures after `store.load()`.
- iOS “Show full meeting” still navigates from a persisted search result.

## Sequencing

1. Build the SwiftData model and mapper first, because all repository behavior depends on lossless conversion.
2. Implement the SwiftData repository against an in-memory or temporary container for development verification.
3. Wire `RecallOSStoreFactory` to persistent storage with fixture fallback.
4. Verify Mac create-record-enhance-reload flow.
5. Verify iOS read path builds and still navigates.
6. Run CE code review before moving to real capture or Convex.

## Verification Gates

Required:

```sh
swift test --package-path packages/RecallOSCore
xcodebuild -project RecallOS.xcodeproj -scheme RecallOSMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project RecallOS.xcodeproj -scheme RecallOSiOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Add implementation-specific verification:

- A temporary-store SwiftData repository test or executable check that proves create/update/reload.
- Manual Mac flow: create meeting → record mock transcript → stop/enhance → quit/relaunch → meeting data remains.
- Manual iOS flow: launch companion → Brain search → Show full meeting opens the persisted meeting.

## Risks And Mitigations

- SwiftData relationship modeling can become noisy if every Core child type is modeled as a deep relationship. Start explicit and boring; avoid clever generic blob storage for primary entities, but JSON blobs are acceptable only for low-value metadata if relationship overhead blocks progress.
- Xcode project file edits are easy to break. Add new shared files once and verify both app targets build before filling out all repository methods.
- Seeding can accidentally duplicate sample data. Gate seeding on an empty meeting table and use stable sample UUIDs.
- Repository actors and SwiftData contexts have thread-affinity constraints. Keep repository methods `@MainActor` or use a clearly owned model context if needed; do not mix contexts casually.
- Convex environment variables must not change app behavior in this sprint.

## Follow-Up After Sprint 2

- Add EventKit calendar provider and pre-meeting banner triggers.
- Add AVFoundation mock-to-real audio capture adapter.
- Persist transcript segments incrementally during active recording if crash recovery becomes a pilot requirement.
- Revisit Convex schema and sync once local data behavior is trustworthy.
