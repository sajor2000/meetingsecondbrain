# RecallOS Sprint 3 Calendar And Meeting Lifecycle Plan

Created: 2026-05-04
Status: active

## Summary

Sprint 3 connects the Mac app shell to real meeting timing. The goal is to move from static/mock upcoming events to an EventKit-backed calendar provider, a reliable meeting lifecycle state machine, and pre-meeting/detected banners that can start the existing mock recording workflow at the right time. This remains local-first: no Convex sync, no real transcription engine, and no real audio capture beyond the provider boundaries already present.

Sprint 2 made meetings durable through `SwiftDataRecallOSRepository`. Sprint 3 should build on that persistence by making scheduled meetings, in-progress meetings, and recording transitions first-class state in `RecallOSAppStore`.

## Problem Frame

RecallOS is supposed to feel ambient on Mac: upcoming meetings appear in the sidebar, the banner nudges at the right time, and recording/enhancement states stay coherent even when the user navigates away. Today, the app has mock calendar events and a working provider-backed recording flow, but the calendar and lifecycle logic are not yet grounded in real EventKit data or explicit transition rules.

## Scope

In scope:

- Add an EventKit-backed `CalendarEventProvider` in the app layer, with mock fallback for tests and denied permissions.
- Persist calendar-linked meeting metadata through existing Core fields: `calendarEventID`, `startsAt`, `endsAt`, `attendees`, and `status`.
- Populate the Mac sidebar `Coming up` section from provider-backed events.
- Add lifecycle transitions for scheduled, in-progress, recording, paused, enhancing, completed, and failed states.
- Trigger a pre-meeting banner two minutes before eligible events.
- Create or select a meeting from an upcoming calendar event, then start the existing mock recording workflow.
- Keep simultaneous-event selection deterministic: choose the event with the most attendees.

Out of scope:

- Real audio capture, system audio, Parakeet, WhisperKit, or OpenRouter.
- Convex calendar sync.
- Background launch/login item behavior.
- Full multi-display banner persistence.
- iOS calendar ingestion. iOS can read persisted meetings after Mac creates them, but Mac remains the primary lifecycle owner.

## Key Decisions

1. Put EventKit in `Apps/Shared` or `Apps/RecallOSMac`, not Core.

   Rationale: `Packages/RecallOSCore` should keep using the existing `CalendarEventProvider` protocol and Core `CalendarEvent` model. EventKit permissions and framework types belong in app targets.

2. Model lifecycle transitions in Core, orchestrate triggers in the Mac app.

   Rationale: State transition rules should be testable without EventKit. Timing, permissions, and timers are platform concerns.

3. Keep recording provider-mock-based.

   Rationale: Sprint 3 is about correct meeting lifecycle and entry points. Real capture belongs in the following sprint.

4. Treat denied calendar access as a visible degraded mode, not a launch failure.

   Rationale: The app should still show locally persisted meetings and allow manual recording when calendar permission is unavailable.

## Existing Patterns To Follow

- Provider protocol: `Packages/RecallOSCore/Sources/RecallOSCore/Repositories/RecallOSProviders.swift`
- Store orchestration: `Packages/RecallOSCore/Sources/RecallOSCore/Stores/RecallOSAppStore.swift`
- Meeting status model: `Packages/RecallOSCore/Sources/RecallOSCore/Models/Meeting.swift`
- Recording session model: `Packages/RecallOSCore/Sources/RecallOSCore/Models/RecordingSession.swift`
- Banner state model and UI: `Packages/RecallOSCore/Sources/RecallOSCore/Models/RecordingBannerState.swift`, `Packages/RecallOSCore/Sources/RecallOSCore/Components/RecordingBannerView.swift`
- Mac sidebar and banner entry points: `Apps/RecallOSMac/Sources/MacContentView.swift`, `Apps/RecallOSMac/Sources/RecallOSMacApp.swift`
- Persistence adapter from Sprint 2: `Apps/Shared/Sources/Persistence/SwiftDataRecallOSRepository.swift`

## Implementation Units

### Unit 1: Calendar Provider Boundary

Files:

- Add `Apps/Shared/Sources/Calendar/EventKitCalendarEventProvider.swift` or `Apps/RecallOSMac/Sources/EventKitCalendarEventProvider.swift`
- Update `Apps/Shared/Sources/RecallOSStoreFactory.swift`
- Update `RecallOS.xcodeproj/project.pbxproj`

Responsibilities:

- Implement `CalendarEventProvider` using EventKit.
- Request calendar read access on first load.
- Map EventKit events to Core `CalendarEvent`, including external ID, title, start/end, location, and attendees when available.
- Return deterministic sorted results limited by the requested count.
- Fall back to `MockCalendarEventProvider` when permission is denied or EventKit errors.
- Surface a specific `syncError` or workflow message for denied access without blocking app launch.

Test scenarios:

- Mock fallback still loads upcoming events when EventKit access is denied.
- Event mapping preserves external ID, title, start/end, location, and attendee display names.
- Results are sorted by `startsAt` and respect the requested limit.

### Unit 2: Lifecycle State Machine

Files:

- Update `Packages/RecallOSCore/Sources/RecallOSCore/Models/Meeting.swift`
- Add or update lifecycle helpers in `Packages/RecallOSCore/Sources/RecallOSCore/Stores/RecallOSAppStore.swift`
- Add tests in `Packages/RecallOSCore/Tests/RecallOSCoreTests/ModelTests.swift`

Responsibilities:

- Define explicit transition helpers for meeting lifecycle state.
- Keep `RecordingSession` and `Meeting.status` aligned when starting, pausing, resuming, stopping, enhancing, completing, or failing.
- Ensure transitions update the recording meeting by ID, not selected UI meeting.
- Add validation or no-op behavior for invalid transitions, such as pausing without an active recording.

Test scenarios:

- Scheduled meeting becomes in-progress when current time is inside the meeting window.
- Starting recording marks the meeting recording and creates an active session.
- Pausing/resuming updates session state without changing selected meeting.
- Stop/enhance moves the recording meeting to completed and keeps tasks/transcript attached.
- Failure marks session failed and keeps a recoverable error message.

### Unit 3: Pre-Meeting Banner Scheduler

Files:

- Add `Apps/RecallOSMac/Sources/MeetingLifecycleScheduler.swift`
- Update `Apps/RecallOSMac/Sources/MacContentView.swift`
- Update `Apps/RecallOSMac/Sources/RecallOSMacApp.swift`

Responsibilities:

- Watch provider-backed upcoming events in the Mac app.
- Trigger `.preMeeting` banner two minutes before eligible calendar events.
- Suppress repeat banners for events the user dismisses.
- If multiple events overlap, choose the one with the most attendees.
- Clicking Record from the banner should create or select the matching meeting and call the existing `startRecording()` flow.

Test scenarios:

- Scheduler chooses an event beginning within the pre-meeting window.
- Scheduler ignores events already dismissed.
- Overlapping events choose the event with the most attendees.
- Banner Record creates/selects the event-backed meeting and starts mock recording.

### Unit 4: Sidebar Coming Up Integration

Files:

- Update `Apps/RecallOSMac/Sources/MacContentView.swift`
- Update `Packages/RecallOSCore/Sources/RecallOSCore/Stores/RecallOSAppStore.swift`

Responsibilities:

- Keep the sidebar `Coming up` list provider-backed.
- Add store methods to create/select meetings from calendar events.
- Highlight the active/in-progress event when recording is running.
- Preserve manual meeting creation behavior.

Test scenarios:

- Clicking an upcoming event creates/selects a meeting with matching title, start/end, attendees, and calendar event ID.
- Existing event-backed meeting is selected instead of duplicated.
- Active recording event is visually distinguishable in the sidebar.

### Unit 5: Persistence And Reload Behavior

Files:

- Update `Apps/Shared/Sources/Persistence/RecallOSPersistentModels.swift`
- Update `Apps/Shared/Sources/Persistence/RecallOSPersistenceMapper.swift`
- Update `Apps/Shared/Sources/Persistence/SwiftDataRecallOSRepository.swift`

Responsibilities:

- Persist any new lifecycle metadata introduced in Unit 2.
- Ensure event-backed meetings reload with `calendarEventID` and lifecycle status intact.
- Avoid duplicating meetings when the same calendar event is seen after relaunch.

Test scenarios:

- Event-backed meeting persists and reloads with `calendarEventID`.
- Reprocessing the same calendar event selects or updates the existing meeting rather than creating a duplicate.
- Completed meeting remains completed after relaunch even if the original calendar event is still visible.

## Sequencing

1. Add lifecycle helpers and tests first so state rules are explicit before timers and EventKit enter the picture.
2. Add the EventKit provider behind the existing provider protocol with mock fallback.
3. Wire sidebar event selection to create/select persistent meetings.
4. Add Mac scheduler and banner trigger behavior.
5. Verify reload behavior with event-backed meetings.
6. Run CE review before starting real audio capture.

## Verification Gates

Required:

```sh
swift test --package-path Packages/RecallOSCore
xcodebuild -project RecallOS.xcodeproj -scheme RecallOSMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project RecallOS.xcodeproj -scheme RecallOSiOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Add implementation-specific verification:

- Manual Mac permission-denied flow: app still loads persisted meetings and manual recording works.
- Manual Mac happy path with mock EventKit data or calendar access: upcoming event appears, banner fires, Record starts mock recording.
- Persistence check: event-backed meeting survives reload without duplication.

## Risks And Mitigations

- EventKit permission APIs differ subtly by OS version. Keep the provider small, isolate permission handling, and build on the minimum deployment targets already configured.
- Timer-driven UI can become flaky. Keep scheduling deterministic by injecting a clock/date provider where tests need it.
- Calendar events can be edited externally. Prefer updating event-backed scheduled meetings until recording starts; once recording begins, preserve meeting content and avoid destructive sync.
- Banner timing can annoy users. Persist dismissals per calendar event ID and avoid repeated pre-meeting prompts.

## Follow-Up After Sprint 3

- Sprint 4 should replace mock audio capture with AVFoundation microphone capture.
- Add Login Item behavior only after recording and banner lifecycle are stable.
- Add iOS calendar read support only after Mac lifecycle behavior is reliable.
