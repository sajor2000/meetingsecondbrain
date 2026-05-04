# RecallOS Sprint 4 Microphone Capture Plan

Created: 2026-05-04
Status: active

## Summary

Sprint 4 replaces the RecallOS mock audio capture boundary with a real macOS AVFoundation microphone capture adapter while keeping transcription mock-backed. The goal is not a full bot-free meeting recorder yet; it is a reliable first real capture slice that records the local microphone, handles microphone permissions cleanly, writes inspectable local audio artifacts, persists artifact metadata with the meeting, and keeps the existing record, pause, resume, stop, enhance flow working.

Sprint 3 made the Mac app calendar-aware and event-backed. Sprint 4 should build on that by proving the recording workflow can own a real capture engine without coupling `Packages/RecallOSCore` to AVFoundation or disturbing the local-first SwiftData path.

## Problem Frame

RecallOS currently starts and stops a mock `AudioCaptureProvider`, then streams mock transcript segments. That proves UI and state flow, but it does not prove that the native app can request microphone access, create a durable recording file, recover from denied permissions, pause and resume capture, or hand a future transcription engine a real artifact.

The older macOS proof app already contains useful AVFoundation capture, artifact-writing, and cleanup learnings under `Apps/macOS/MeetingApp`. Sprint 4 should reuse those patterns deliberately, but the implementation target is the new native RecallOS app in `Apps/RecallOSMac`, `Apps/Shared`, and `Packages/RecallOSCore`.

## Scope

In scope:

- Add Core audio artifact/domain types that describe captured local files without importing AVFoundation.
- Extend the audio capture provider boundary so app-layer providers can return artifact metadata at stop/finalization.
- Add a macOS AVFoundation microphone capture provider in the app layer.
- Add microphone permission provider behavior backed by `AVCaptureDevice` authorization.
- Write microphone audio artifacts into an app-owned local recording directory.
- Persist microphone artifact metadata through SwiftData and reload it with meetings.
- Show specific microphone permission and capture failure states in the existing Mac workflow surfaces.
- Keep mock transcription, mock enhancement, and mock task extraction as the post-stop path.
- Keep all Core tests and Mac/iOS builds passing.

Out of scope:

- ScreenCaptureKit system audio capture.
- Audio mixing.
- Parakeet, WhisperKit, OpenRouter, Cognee, Convex sync, or live transcript from captured audio.
- iOS voice memo capture.
- Login Item/background launch behavior.
- Multi-device artifact upload or retention settings.

## Key Decisions

1. Keep AVFoundation out of Core.

   Rationale: `Packages/RecallOSCore` should keep platform-neutral models and protocols. AVFoundation implementations belong under `Apps/Shared` or `Apps/RecallOSMac` behind provider protocols.

2. Persist artifact metadata, not raw audio bytes, in SwiftData.

   Rationale: Audio files are local filesystem artifacts. SwiftData should store stable paths, timing, byte size, duration when available, and diagnostics needed by UI and future transcription.

3. Keep transcription mocked after stop.

   Rationale: The sprint is about capture reliability and artifact ownership. Real transcription should consume the persisted artifact in the next sprint after capture failures are well understood.

4. Reuse the old recorder learnings, not the old UI architecture.

   Rationale: `Apps/macOS/MeetingApp/Services/MicrophoneCaptureEngine.swift`, `MeetingAudioRecorder.swift`, and the related learning doc contain hard-won cleanup patterns. The new implementation should adapt the service-level ideas into RecallOS providers instead of linking old view models into the new shell.

5. Make permission denial recoverable and specific.

   Rationale: A denied microphone permission should not corrupt meeting state or leave the app in a generic failure. The user should see that microphone access is required and manual navigation should continue working.

## Existing Patterns To Follow

- Provider boundary: `Packages/RecallOSCore/Sources/RecallOSCore/Repositories/RecallOSProviders.swift`
- Store orchestration: `Packages/RecallOSCore/Sources/RecallOSCore/Stores/RecallOSAppStore.swift`
- Recording state model: `Packages/RecallOSCore/Sources/RecallOSCore/Models/RecordingSession.swift`
- Meeting model and persistence mapping: `Packages/RecallOSCore/Sources/RecallOSCore/Models/Meeting.swift`, `Apps/Shared/Sources/Persistence/RecallOSPersistenceMapper.swift`
- SwiftData models: `Apps/Shared/Sources/Persistence/RecallOSPersistentModels.swift`
- Mac app factory and Info.plist: `Apps/Shared/Sources/RecallOSStoreFactory.swift`, `Apps/RecallOSMac/Resources/Info.plist`
- Existing capture proof code: `Apps/macOS/MeetingApp/Services/MicrophoneCaptureEngine.swift`, `Apps/macOS/MeetingApp/Services/MeetingAudioRecorder.swift`, `Apps/macOS/MeetingApp/Services/CapturePermissionService.swift`
- Capture cleanup learning: `Docs/solutions/logic-errors/stabilize-macos-capture-recorder-cleanup-and-activity-state-2026-05-03.md`

## Implementation Units

### Unit 1: Core Capture Artifact Contract

Files:

- Update `Packages/RecallOSCore/Sources/RecallOSCore/Models/Meeting.swift`
- Add `Packages/RecallOSCore/Sources/RecallOSCore/Models/AudioCaptureArtifact.swift`
- Update `Packages/RecallOSCore/Sources/RecallOSCore/Repositories/RecallOSProviders.swift`
- Update `Packages/RecallOSCore/Tests/RecallOSCoreTests/ModelTests.swift`

Responsibilities:

- Add a platform-neutral artifact model with local ID, meeting ID, started/ended timestamps, microphone audio path, optional duration, byte size, and diagnostics/error text.
- Add artifact storage to `Meeting`, defaulting to an empty collection.
- Extend `AudioCaptureProvider` so `stop()` can return an artifact result or expose the completed artifact through a provider method. Prefer a single `stop() async throws -> AudioCaptureArtifact?` shape if the call-site churn stays contained.
- Preserve mock provider behavior by returning nil or a mock artifact without introducing real capture into tests.
- Keep `RecordingWorkflowError.microphonePermissionDenied` as the explicit permission failure.

Test scenarios:

- A new meeting defaults to no audio artifacts.
- Audio artifact metadata is `Codable`, `Hashable`, and preserves local paths.
- Mock audio provider still supports start, pause, resume, and stop without requiring a real file.
- Recording failure can carry a microphone-specific error without changing unrelated meeting data.

### Unit 2: SwiftData Persistence For Audio Artifacts

Files:

- Update `Apps/Shared/Sources/Persistence/RecallOSPersistentModels.swift`
- Update `Apps/Shared/Sources/Persistence/RecallOSPersistenceMapper.swift`
- Update `Apps/Shared/Sources/Persistence/SwiftDataRecallOSRepository.swift` if repository update behavior needs relationship handling changes.
- Update `RecallOS.xcodeproj/project.pbxproj` if new files are added.

Responsibilities:

- Add a persistent child model for audio artifacts under `PersistentMeeting`.
- Map audio artifact metadata to and from Core meeting models.
- Preserve artifact ordering by `startedAt`.
- Keep existing persisted meetings readable by defaulting missing artifact collections to empty arrays.

Test scenarios:

- A meeting with a microphone artifact round-trips through the mapper without losing file path, timestamps, duration, or diagnostics.
- Existing fixture/sample meetings still map without artifacts.
- Updating a meeting after stop persists the artifact and reloads it through a fresh repository instance.

### Unit 3: AVFoundation Microphone Provider

Files:

- Add `Apps/Shared/Sources/Audio/AVFoundationMicrophoneAudioCaptureProvider.swift` or `Apps/RecallOSMac/Sources/Audio/AVFoundationMicrophoneAudioCaptureProvider.swift`
- Add `Apps/Shared/Sources/Audio/RecordingArtifactStore.swift` if the artifact writer is shared with future macOS capture providers.
- Update `Apps/Shared/Sources/RecallOSStoreFactory.swift`
- Update `Apps/RecallOSMac/Resources/Info.plist` only if usage descriptions need clearer copy.
- Update `RecallOS.xcodeproj/project.pbxproj`

Responsibilities:

- Implement `AudioCaptureProvider` with `AVAudioEngine`.
- Write microphone audio to a unique per-meeting recording directory under Application Support.
- Use UUID-backed artifact directory names to avoid same-second collisions.
- Implement pause/resume by pausing engine capture or marking captured segments according to the simplest reliable AVFoundation behavior discovered during implementation.
- Always clean up taps, writers, and engine state on stop or start failure.
- Return artifact metadata on stop, including path and best-effort byte size/duration.

Test scenarios:

- Starting capture creates a unique artifact directory and microphone file path.
- Starting twice without stopping throws a capture-specific error.
- Stop removes taps, stops the engine, finalizes metadata, and returns an artifact.
- If writer setup fails after engine preparation, the provider cleans up before throwing.
- Two quick captures do not reuse artifact directories.

### Unit 4: Microphone Permission Provider And Recovery UI

Files:

- Add `Apps/Shared/Sources/Audio/AVFoundationRecordingPermissionProvider.swift`
- Update `Apps/Shared/Sources/RecallOSStoreFactory.swift`
- Update `Apps/RecallOSMac/Sources/MacContentView.swift`
- Update `Packages/RecallOSCore/Tests/RecallOSCoreTests/ModelTests.swift`

Responsibilities:

- Implement `RecordingPermissionProvider` with `AVCaptureDevice.authorizationStatus(for: .audio)` and `requestAccess(for: .audio)`.
- Keep denied/restricted states as `false` so `RecallOSAppStore.startRecording()` produces `RecordingWorkflowError.microphonePermissionDenied`.
- Surface a specific Mac workflow message or error row with recovery guidance when microphone access is denied.
- Ensure permission denial leaves the selected meeting recoverable and does not create an active recording session.

Test scenarios:

- Denied permission prevents audio provider start.
- Denied permission leaves the meeting selected and not recording.
- Denied permission sets a microphone-specific error message.
- Allowed permission still starts the provider and records against the selected meeting.

### Unit 5: Store Integration And Post-Stop Artifact Persistence

Files:

- Update `Packages/RecallOSCore/Sources/RecallOSCore/Stores/RecallOSAppStore.swift`
- Update `Packages/RecallOSCore/Tests/RecallOSCoreTests/ModelTests.swift`

Responsibilities:

- Attach returned audio artifacts to `recordingSession.meetingID`, not whichever meeting is currently selected.
- Persist the meeting after stop even before mock enhancement runs, so artifact metadata survives if enhancement fails.
- Keep existing transcript/mock enhancement behavior intact after artifact persistence.
- Preserve the previous review fix: recording data must remain decoupled from selected UI navigation.

Test scenarios:

- Stop stores an artifact on the recording meeting.
- Navigating to another meeting during recording does not attach the artifact to the selected meeting.
- Enhancement failure still leaves the captured artifact metadata persisted.
- A completed mock-enhanced meeting contains transcript, hybrid notes, extracted tasks, and audio artifact metadata.

### Unit 6: Manual Evidence And Developer Verification

Files:

- Update `Docs/manual-test-plan.md`
- Update `README.md` if command names or status copy change.
- Optionally add lightweight developer-only artifact display in `Apps/RecallOSMac/Sources/MacContentView.swift` if no existing UI exposes the path.

Responsibilities:

- Document how to run a short microphone capture from the RecallOS Mac app.
- Document expected artifact location and how to verify the file exists and is non-empty.
- Keep the manual test focused on microphone capture only; system audio and mixing remain later.
- Add PR verification notes for permission denied and successful short capture.

Test scenarios:

- Manual permission denied: Record shows a microphone-specific recovery state and app remains usable.
- Manual happy path: Record for 5-10 seconds, Stop, and confirm a non-empty microphone audio file and persisted artifact path.
- Manual reload: relaunch app and confirm the meeting still shows or retains the artifact metadata.

## Sequencing

1. Add the Core artifact model and provider return contract first so app providers and persistence have a stable boundary.
2. Add SwiftData mapping for audio artifacts before wiring real capture, so the stop path has somewhere durable to write metadata.
3. Implement the AVFoundation permission provider and microphone capture provider behind the existing factory.
4. Wire `RecallOSAppStore.stopAndEnhanceRecording()` to attach and persist artifacts by `recordingSession.meetingID`.
5. Add permission recovery UI copy and manual evidence notes.
6. Run CE code review before starting ScreenCaptureKit or transcription integration.

## Verification Gates

Required:

```sh
swift test --package-path Packages/RecallOSCore
xcodebuild -project RecallOS.xcodeproj -scheme RecallOSMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project RecallOS.xcodeproj -scheme RecallOSiOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Add implementation-specific verification:

- Unit tests for artifact model mapping, provider error behavior, and store attachment by recording meeting ID.
- Manual Mac permission-denied flow: denied microphone access shows a specific recovery message and manual app navigation still works.
- Manual Mac capture flow: record 5-10 seconds, stop, verify microphone file exists, is non-empty, and artifact metadata persists after reload.
- CE code review on the Sprint 4 branch before opening the PR.

## Risks And Mitigations

- AVAudioEngine behavior differs across devices and input formats. Keep format handling inside the provider and record diagnostics in artifact metadata.
- Pause/resume can introduce file discontinuities. Choose the simplest reliable behavior first and document whether pause means engine pause or provider-level paused state.
- File writes happen off the happy path when users deny permission, unplug devices, or stop quickly. Reuse the cleanup-first lessons from `Docs/solutions/logic-errors/stabilize-macos-capture-recorder-cleanup-and-activity-state-2026-05-03.md`.
- SwiftData schema changes can affect existing local stores. Default new artifact relationships to empty arrays and verify app launch with old sample data.
- The old capture proof includes system audio and mixing, which can tempt scope creep. Keep Sprint 4 microphone-only so the next sprint has a trustworthy input artifact.

## Follow-Up After Sprint 4

- Sprint 5 should connect captured microphone artifacts to a real transcription adapter or a batch transcription proof while keeping provider boundaries intact.
- Add ScreenCaptureKit system audio only after microphone capture and artifact persistence are stable.
- Add iOS quick voice memo capture after the Mac artifact model is proven.
