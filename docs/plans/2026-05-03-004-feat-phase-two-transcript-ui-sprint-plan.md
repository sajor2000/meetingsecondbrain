---
title: feat: Phase 2 transcript UI sprint
type: feat
status: active
date: 2026-05-03
origin: docs/plans/2026-05-03-003-feat-phase-two-core-capture-plan.md
---

# feat: Phase 2 transcript UI sprint

## Summary

PR #3 completed the offline-safe Parakeet batch transcription scaffold. The next manageable sprint should connect the existing recording proof surface to the transcription runner and add a transcript rendering panel that can be tested without a live meeting. This keeps momentum while the real Zoom capture and real 30 minute transcription gates remain pending.

This sprint should not claim Phase 2 approval. It should produce a better proof tool for the manual gates.

## Problem Frame

The app can now record local artifacts and can transcribe a mixed audio file through a testable runner. Those capabilities are still separate. The user needs one macOS proof surface where a completed recording can be inspected, transcribed, and reviewed with timestamped transcript output.

The best next slice is not calendar or enhancement. It is the smallest product-shaped loop around the Phase 2 risk: record, stop, transcribe, view transcript, and capture evidence for the manual test plan.

## Requirements

- R1. The capture proof UI exposes a completed recording artifact and its output files.
- R2. The user can start batch transcription from the completed recording state.
- R3. The UI shows transcription progress, errors, elapsed time, transcript JSON path, and transcript markdown path.
- R4. The transcript panel renders timestamped segments in timeline order.
- R5. Transcript rendering preserves speaker labels when present.
- R6. The sprint stays local-only. No Convex upload, calendar, LLM enhancement, screenshots, tasks, iOS capture, or Cognee behavior.
- R7. Automated tests cover view model state, transcript rendering, missing mixed audio, and provider failure paths.
- R8. Manual gates remain explicit in `docs/manual-test-plan.md`.

## Scope Boundaries

- Do not add live audio streaming in this sprint unless it is a tiny adapter on top of the same view model.
- Do not add note editing or hybrid AI note rendering.
- Do not add real diarization. Parakeet still reports diarization unsupported until speaker assignment is wired.
- Do not mark Phase 2 complete without the real Zoom capture and real 30 minute transcription evidence.
- Do not add iOS transcription or WhisperKit.

## Existing Patterns to Follow

- `apps/macOS/MeetingApp/Views/CaptureProofView.swift` is the proof UI shell.
- `apps/macOS/MeetingApp/ViewModels/RecordingSessionViewModel.swift` owns capture state and completed artifacts.
- `apps/macOS/MeetingApp/Services/TranscriptionRunner.swift` owns batch transcription and artifact writing.
- `apps/macOS/Tests/TranscriptionRunnerTests.swift` shows how to inject fake providers.
- `packages/Core/Sources/Core/Models/Transcript.swift` is the shared transcript model.
- `docs/manual-test-plan.md` is the manual gate artifact.

## Key Technical Decisions

- Add a separate transcription view model instead of expanding recording state into a large mixed state object. Recording and transcription are related, but they have different failure modes.
- Keep the first transcript panel read-only. Editing belongs to Phase 4 notes work.
- Use dependency injection for `TranscriptionRunner` so tests never download models.
- Keep the UI tied to completed artifacts. Starting transcription while recording can wait until live streaming is explicitly implemented.
- Record manual evidence fields in the existing manual test plan instead of inventing a new proof format.

## Implementation Units

- U1. **Transcription proof state**

**Goal:** Add a testable view model for transcribing one completed recording artifact.

**Requirements:** R1, R2, R3, R7

**Files:**
- Create: `apps/macOS/MeetingApp/ViewModels/TranscriptionProofViewModel.swift`
- Modify: `apps/macOS/MeetingApp/Services/TranscriptionRunner.swift`
- Test: `apps/macOS/Tests/TranscriptionProofViewModelTests.swift`
- Test: `apps/macOS/Tests/TranscriptionRunnerTests.swift`

**Approach:**
- Model idle, transcribing, completed, and failed states.
- Accept a `RecordingArtifact` from the completed capture state.
- Inject a transcription running dependency that can be faked in tests.
- Preserve transcription duration and output URLs in the completed state.

**Test scenarios:**
- Happy path: completed recording starts transcription and reaches completed state.
- Error path: missing mixed audio surfaces a user-readable failure.
- Error path: provider failure surfaces a user-readable failure and keeps the recording artifact available.
- Edge case: duplicate transcribe clicks while transcribing do not start a second run.

- U2. **Transcript rendering panel**

**Goal:** Render timestamped transcript segments in the macOS proof UI.

**Requirements:** R3, R4, R5, R7

**Files:**
- Create: `apps/macOS/MeetingApp/Views/TranscriptPanelView.swift`
- Modify: `apps/macOS/MeetingApp/Views/CaptureProofView.swift`
- Test: `apps/macOS/Tests/TranscriptPanelViewModelTests.swift`

**Approach:**
- Render segment timestamp, optional speaker, and text.
- Keep the panel stable for empty, loading, completed, and failed states.
- Use the same timestamp formatting as `TranscriptMarkdownRenderer`.
- Keep the layout dense and utilitarian because this is a proof tool, not a landing page.

**Test scenarios:**
- Empty transcript renders no segment rows.
- Timestamp formatting handles zero, one minute, and one hour scale offsets.
- Speaker labels appear only when provided.
- Segments render in model order after transcript sorting.

- U3. **Capture proof UI integration**

**Goal:** Let the user record, stop, transcribe, and inspect output from one screen.

**Requirements:** R1, R2, R3, R6, R8

**Files:**
- Modify: `apps/macOS/MeetingApp/Views/CaptureProofView.swift`
- Modify: `apps/macOS/MeetingApp/ViewModels/RecordingSessionViewModel.swift`
- Modify: `docs/manual-test-plan.md`
- Test: `apps/macOS/Tests/RecordingSessionViewModelTests.swift`
- Test: `apps/macOS/Tests/TranscriptionProofViewModelTests.swift`

**Approach:**
- Show a Transcribe button only after a completed recording has a mixed audio path.
- Show transcript output paths after transcription succeeds.
- Add manual test plan fields for one-screen proof runs.
- Keep capture controls and transcript controls visually distinct.

**Test scenarios:**
- Completed recording with a mixed file enables transcription.
- Completed recording without a mixed file disables transcription and shows a recoverable status.
- Successful transcription exposes JSON and markdown paths.
- Failed transcription does not clear the completed recording.

## Verification

- `npm run swift:test:core`
- `npm run xcode:test:macos`
- `npm run phase1:check`
- `git diff --check`
- Style scan for em dashes and semicolons in touched docs and user-facing strings
- `ce-code-review` before opening or merging the sprint PR

## Manual Evidence

This sprint can be merged with fake provider tests, but Phase 2 cannot be approved until these are filled in:

- Real Zoom or equivalent capture in `docs/manual-test-plan.md`
- Real 30 minute Parakeet transcription in `docs/manual-test-plan.md`
- Transcript segment quality notes, including nonzero timestamp anchors beyond the first segment
- Any model download, accuracy, diarization, or performance issue logged in `DECISIONS.md` or a follow-up issue

## Suggested CE Loop

1. `ce-work` U1 only.
2. Run `npm run xcode:test:macos` and `git diff --check`.
3. `ce-code-review`, then fix P1 to P3 findings.
4. `ce-work` U2 and U3.
5. Run `npm run phase1:check` and `git diff --check`.
6. `ce-code-review`, then fix P1 to P3 findings.
7. Open the sprint PR.

## Definition of Done

- The macOS proof UI can start from a completed recording artifact and run batch transcription.
- The transcript panel shows timestamped segments and output artifact paths.
- Automated tests cover state transitions and rendering rules.
- Manual test plan fields are ready for real capture and real 30 minute transcription evidence.
- The full gate passes.
- CE review has no unresolved P1 to P3 findings.
