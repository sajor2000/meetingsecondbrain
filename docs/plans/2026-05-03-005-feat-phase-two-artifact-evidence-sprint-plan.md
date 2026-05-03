---
title: feat: Phase 2 artifact evidence sprint
type: feat
status: planned
date: 2026-05-03
origin: docs/plans/2026-05-03-004-feat-phase-two-transcript-ui-sprint-plan.md
---

# feat: Phase 2 artifact evidence sprint

## Summary

The transcript proof panel now connects recording artifacts to batch transcription. The next manageable sprint should make the manual Phase 2 gates easier to run when a real meeting is available. Build local artifact inspection, audio playback checks, and evidence export around the existing proof UI.

This sprint should not claim Phase 2 approval. It should reduce friction for the real Zoom capture and real 30 minute transcription proof runs.

## Problem Frame

The app can record, stop, transcribe, and render transcript output from one screen. The remaining Phase 2 risk is still empirical: real system audio, real microphone audio, mixed audio quality, and Parakeet timing quality on a realistic meeting. The user cannot always run a live meeting gate immediately, so the app should make collected artifacts easy to inspect, replay, and document later.

## Requirements

- R1. The proof UI can load an existing recording artifact folder from disk.
- R2. The proof UI verifies that system, microphone, mixed, metadata, transcript JSON, and transcript markdown files exist.
- R3. The proof UI shows file duration, byte size, and last modified time where available.
- R4. The proof UI can play system, microphone, and mixed audio locally for quick quality checks.
- R5. The proof UI can copy or generate a markdown evidence summary for `docs/manual-test-plan.md`.
- R6. The sprint stays local-only. No Convex upload, calendar, LLM enhancement, screenshots, tasks, iOS capture, or Cognee behavior.
- R7. Automated tests cover artifact folder parsing, missing file states, and evidence summary generation.
- R8. Manual gates remain explicit in `docs/manual-test-plan.md`.

## Scope Boundaries

- Do not add synced transcript playback in this sprint.
- Do not add live transcription.
- Do not add note editing or hybrid AI note rendering.
- Do not mark Phase 2 complete without real capture and real 30 minute transcription evidence.
- Do not add iOS transcription or WhisperKit.

## Existing Patterns to Follow

- `apps/macOS/MeetingApp/Views/CaptureProofView.swift` is the proof UI shell.
- `apps/macOS/MeetingApp/Models/RecordingArtifact.swift` models capture outputs.
- `apps/macOS/MeetingApp/Services/TranscriptionRunner.swift` writes transcript artifacts beside mixed audio.
- `docs/manual-test-plan.md` is the manual gate artifact.

## Implementation Units

### U1. Artifact Folder Loader

Goal: Load a prior recording artifact folder into the proof UI.

Files:
- Create: `apps/macOS/MeetingApp/Services/RecordingArtifactLoader.swift`
- Modify: `apps/macOS/MeetingApp/ViewModels/RecordingSessionViewModel.swift`
- Modify: `apps/macOS/MeetingApp/Views/CaptureProofView.swift`
- Test: `apps/macOS/Tests/RecordingArtifactLoaderTests.swift`

Approach:
- Parse `metadata.json` when available.
- Infer standard file names when metadata is missing.
- Surface missing files as recoverable inspection warnings.

### U2. Local Audio Inspection

Goal: Let the user play system, microphone, and mixed audio from the proof UI.

Files:
- Create: `apps/macOS/MeetingApp/ViewModels/AudioInspectionViewModel.swift`
- Create: `apps/macOS/MeetingApp/Views/AudioInspectionView.swift`
- Modify: `apps/macOS/MeetingApp/Views/CaptureProofView.swift`
- Test: `apps/macOS/Tests/AudioInspectionViewModelTests.swift`

Approach:
- Use `AVAudioPlayer` behind an injectable player protocol.
- Show duration and file size for each available audio file.
- Keep playback controls compact and utilitarian.

### U3. Manual Evidence Summary

Goal: Generate a markdown summary that maps one proof run to the manual gate fields.

Files:
- Create: `apps/macOS/MeetingApp/Services/ManualEvidenceSummaryBuilder.swift`
- Modify: `apps/macOS/MeetingApp/Views/CaptureProofView.swift`
- Modify: `docs/manual-test-plan.md`
- Test: `apps/macOS/Tests/ManualEvidenceSummaryBuilderTests.swift`

Approach:
- Include session ID, artifact paths, file presence, audio durations, transcript paths, and timestamps.
- Leave real-meeting observations blank for the user to fill after listening.
- Keep the generated summary local and clipboard-friendly.

## Verification

- `npm run xcode:test:macos`
- `npm run phase1:check`
- `git diff --check`
- Style scan for em dashes and semicolons in touched docs and user-facing strings
- `ce-code-review` before opening the sprint PR

## Suggested CE Loop

1. `ce-work` U1 only.
2. Run `npm run xcode:test:macos` and `git diff --check`.
3. `ce-code-review`, then fix P1 to P3 findings.
4. `ce-work` U2 and U3.
5. Run `npm run phase1:check` and `git diff --check`.
6. `ce-code-review`, then fix P1 to P3 findings.
7. Open the sprint PR.

## Definition of Done

- Existing recording artifact folders can be loaded into the proof UI.
- Audio artifacts can be inspected and played locally.
- The proof UI generates a manual evidence summary.
- Automated tests cover artifact parsing, audio inspection state, and evidence summary generation.
- Manual test plan fields remain ready for the real meeting gates.
- The full gate passes.
- CE review has no unresolved P1 to P3 findings.
