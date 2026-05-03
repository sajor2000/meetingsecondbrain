# Manual Test Plan

## Phase 2: Mac Audio Capture

Status: automated capture proof implemented, real meeting gate pending

### Automated Regression Gate

- `npm run xcode:test:macos` must pass before a real meeting proof run.
- `npm run phase1:check` must pass before moving beyond the capture proof slice.
- `git diff --check` must pass before commit.

Regression coverage to keep:

- Starting a recording starts both capture engines and writes metadata.
- If microphone startup fails after system capture starts, system capture is stopped.
- Stop attempts both engines when microphone stop fails.
- Stop attempts both engines when system stop fails.
- Same-second artifacts use different session directories.
- Activity updates preserve the other channel level.
- Activity publisher state is serialized across callback paths.

Documented capture hardening:

- `docs/solutions/logic-errors/stabilize-macos-capture-recorder-cleanup-and-activity-state-2026-05-03.md`

### Real Zoom or Equivalent Capture Gate

- Bot-free requirement:
  - App does not join the meeting.
  - No meeting bot, external recorder, browser automation participant, or invited capture account appears in the participant list.
  - Capture uses only local system audio and local microphone audio from the Mac running the app.
- Date:
- Meeting app build:
- macOS version:
- Meeting client:
- Recording start latency:
- Output folder:
- System audio file audible:
- Microphone file audible:
- Mixed file audible:
- No bot or external recorder joined:
- Stop leaves no active capture indicators:
- Artifact directory contains unique session ID:
- Live system meter active:
- Live microphone meter active:
- Notes:

### Acceptance

- Remote speaker audio is audible in the system audio artifact.
- Local microphone audio is audible in the microphone artifact.
- No bot, external recorder, or extra participant joins the meeting.
- Start latency is recorded.
- Any capture permission or audio quality issue is added to `DECISIONS.md` or a follow-up issue before Phase 2 continues.

## Phase 2: Parakeet Batch Transcription

Status: offline scaffolding implemented, real 30 minute transcription gate pending

### Automated Regression Gate

- `npm run swift:test:core` must pass before a real transcription proof run.
- `npm run xcode:test:macos` must pass before a real transcription proof run.
- `npm run phase1:check` must pass before moving beyond the transcription proof slice.
- `git diff --check` must pass before commit.

Regression coverage to keep:

- Core transcript segments sort by start time and keep final and partial segment state.
- Core transcription provider config defaults to English with no vocabulary hints.
- Parakeet model selection uses the English v2 model for English and multilingual v3 for other languages.
- Parakeet token timings map into timestamped transcript segments.
- Parakeet does not advertise diarization until speaker assignment is wired into returned segments.
- Batch transcription checks for a missing audio file before invoking the provider.
- The macOS transcription runner writes transcript JSON and markdown beside the mixed audio artifact.
- The macOS transcription runner surfaces missing mixed audio and missing file errors.
- The proof UI enables transcription only for completed recordings with mixed audio.
- The proof UI renders transcript duration, output paths, and timestamped transcript rows.

### Real 30 Minute Transcription Gate

- Bot-free capture artifact source:
- Date:
- Meeting app build:
- FluidAudio version:
- Parakeet model:
- Audio duration:
- Model download time:
- Transcription duration:
- Real-time factor:
- Transcript JSON:
- Transcript markdown:
- Proof UI transcribe button enabled after stop:
- Proof UI duration visible:
- Proof UI transcript panel visible:
- Proof UI JSON path visible:
- Proof UI markdown path visible:
- Proof UI audio playback checked:
- Proof UI evidence summary copied:
- Timestamp segment quality:
- Speaker label quality:
- Vocabulary normalization notes:
- Accuracy notes:
- Blockers:

### Acceptance

- A real 30 minute meeting artifact transcribes end to end.
- Transcript generation finishes within the spec target for post-meeting enhancement readiness.
- Transcript JSON and markdown are written beside the recording artifact.
- Transcript segments include nonzero timestamp anchors beyond the first segment.
- The proof UI can run transcription from a completed recording and show duration, output paths, and timestamped rows.
- Any model download, accuracy, diarization, or performance issue is added to `DECISIONS.md` or a follow-up issue before Phase 2 continues.
