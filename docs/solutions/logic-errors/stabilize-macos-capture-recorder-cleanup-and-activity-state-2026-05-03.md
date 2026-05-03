---
title: "Stabilize macOS capture recorder cleanup and activity state"
date: "2026-05-03"
category: "logic-errors"
module: "macOS capture"
problem_type: logic_error
component: service_object
symptoms:
  - "Stop failures could leave one capture engine running"
  - "Same-second recording retries could reuse output directories"
  - "One channel meter update could reset the other channel"
  - "Concurrent audio callbacks could race on shared activity state"
root_cause: thread_violation
resolution_type: code_fix
severity: high
related_components:
  - "MeetingAudioRecorder"
  - "SystemAudioCaptureEngine"
  - "MicrophoneCaptureEngine"
tags: [swift, screencapturekit, avfoundation, recording, concurrency, tests]
---

# Stabilize macOS Capture Recorder Cleanup and Activity State

## Problem
During Phase 2 capture proof, `MeetingAudioRecorder` looked correct under happy-path tests, but review found lifecycle and shared-state bugs that could weaken real meeting evidence. A Stop click could fail to stop all capture paths, quick retries could reuse artifact folders, and live meter state could be incorrect or racy.

## Symptoms
- If microphone shutdown threw, system audio shutdown could be skipped.
- If two artifacts were created in the same second, the timestamp-based session ID could collide.
- A system meter callback reset the microphone level to zero, and a microphone callback reset the system level to zero.
- ScreenCaptureKit and AVAudioEngine callbacks could mutate the same activity snapshot from different threads.

## What Didn't Work
- A direct sequential stop chain was too fragile because the first thrown error prevented later cleanup.
- Timestamp-only artifact IDs assumed the user could not start, fail, and retry within the same clock second.
- Rebuilding `AudioCaptureActivity` from only the current callback treated channel callbacks as full snapshots instead of partial updates.
- Marking the recorder `@unchecked Sendable` without serializing callback-updated state left Swift unable to protect the shared meter state.
- The session history confirmed that the reliable fix was to collect stop errors, preserve partial meter state, and protect the activity publisher with an explicit lock. (session history)

## Solution
Change `stop()` so it attempts both engines before reporting either failure. State cleanup, metadata writing, and meter reset happen before rethrowing a captured stop error.

```swift
let microphoneStopError: Error?
do {
    try await microphoneCapture.stopRecording()
    microphoneStopError = nil
} catch {
    microphoneStopError = error
}

let systemStopError: Error?
do {
    try await systemAudioCapture.stopRecording()
    systemStopError = nil
} catch {
    systemStopError = error
}
```

After both stop attempts, the recorder finalizes the artifact and resets activity state:

```swift
artifactStore.writeMetadata(for: currentArtifact)
currentArtifact.metadataURL = artifactStore.metadataURL(for: currentArtifact)
artifact = nil
activityPublisher.reset()
activityContinuation?.yield(.idle)
```

Make artifact IDs unique even when recordings share the same timestamp:

```swift
let sessionId = ISO8601DateFormatter().string(from: startedAt)
    .replacingOccurrences(of: ":", with: "-")
    .appending("-\(UUID().uuidString)")
```

Move meter state into a small publisher that treats callbacks as partial updates and serializes access with `NSLock`:

```swift
private final class AudioActivityPublisher: @unchecked Sendable {
    private let lock = NSLock()
    private var latestActivity = AudioCaptureActivity.idle

    func update(systemLevel: Double?, microphoneLevel: Double?, updatedAt: Date) -> AudioCaptureActivity {
        lock.lock()
        defer {
            lock.unlock()
        }

        latestActivity = AudioCaptureActivity(
            systemAudioLevel: systemLevel ?? latestActivity.systemAudioLevel,
            microphoneLevel: microphoneLevel ?? latestActivity.microphoneLevel,
            updatedAt: updatedAt
        )
        return latestActivity
    }
}
```

Add tests for the failure modes, not only the happy path:

- `testStopAttemptsBothEnginesWhenMicrophoneStopFails`
- `testStopAttemptsBothEnginesWhenSystemStopFails`
- `testArtifactsCreatedInSameSecondUseDifferentSessionDirectories`
- `testActivityUpdatesPreserveOtherChannelLevel`
- `testMicrophoneCaptureFailureStopsSystemCapture`

## Why This Works
The recorder now follows cleanup-first semantics. Every capture engine receives its stop request, artifact state is finalized, and the UI is returned to idle before the original stop failure is reported.

UUID-backed session IDs remove clock precision as a source of artifact identity. The activity publisher keeps one shared snapshot and updates only the channel reported by each callback. The lock serializes access to that snapshot across ScreenCaptureKit and AVAudioEngine callback threads.

## Prevention
- For any multi-engine capture lifecycle, collect cleanup errors and run every cleanup step before throwing.
- Treat independent audio callbacks as partial state updates.
- Put callback-mutated state behind an actor, lock, serial queue, or another explicit synchronization primitive.
- Include entropy in artifact identifiers whenever users or tests can create more than one artifact inside the clock resolution.
- Keep regression tests around failure ordering, artifact identity, and callback-derived UI state.
- Run the full gate after recorder changes. The verified loop here was `npm run xcode:test:macos`, `npm run phase1:check`, and `git diff --check`. (session history)

## Related Issues
- No related GitHub issues were found via `gh` search for recorder, capture, artifact, activity, or threading terms.
- Related plan: [Phase 2 core capture plan](../../plans/2026-05-03-003-feat-phase-two-core-capture-plan.md)
- Related verification guide: [Manual test plan](../../manual-test-plan.md)

## Follow-Up Refresh Candidates
- `README.md` still appeared to describe Phase 2 capture as not started during the related-docs pass.
- `docs/manual-test-plan.md` should be refreshed after real capture proof evidence is collected.
