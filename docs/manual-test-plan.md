# Manual Test Plan

## Phase 2: Mac Audio Capture

Status: automated capture proof implemented, real meeting gate pending

### RecallOS Sprint 4: Microphone Artifact Gate

Use this section for the native RecallOS app before adding system audio or real transcription.

Automated gate:

- `swift test --package-path Packages/RecallOSCore`
- `xcodebuild -project RecallOS.xcodeproj -scheme RecallOSMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`
- `xcodebuild -project RecallOS.xcodeproj -scheme RecallOSiOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`

Manual permission-denied check:

- Deny microphone permission in System Settings.
- Start a RecallOS recording.
- Expected: no active recording remains, the selected meeting is recoverable, and the UI shows the microphone-specific recovery message.

Manual happy path:

- Allow microphone permission.
- Start a RecallOS recording for 5-10 seconds.
- Stop the recording and allow mock enhancement to complete.
- Confirm the meeting shows an Audio artifacts section with a microphone path.
- Confirm the `microphone.caf` file exists and is non-empty.
- Relaunch the app and confirm the meeting still retains artifact metadata.

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

Use this section for one real bot-free capture run. Start with a short call that has remote speaker audio and local mic audio. After Stop, inspect all three audio files in the proof UI, then use Copy Evidence and paste the copied block below.

- Bot-free requirement:
  - App does not join the meeting.
  - No meeting bot, external recorder, browser automation participant, or invited capture account appears in the participant list.
  - Capture uses only local system audio and local microphone audio from the Mac running the app.

#### Run Details

- Date:
- Meeting app build:
- macOS version:
- Meeting client:
- Meeting client version:
- Meeting type:
- Remote speaker source:
- Local microphone:
- Recording start latency:
- Output folder:
- No bot or external recorder joined:
- Stop leaves no active capture indicators:
- Artifact directory contains unique session ID:
- Live system meter active:
- Live microphone meter active:
- Screen recording permission prompt behavior:
- Microphone permission prompt behavior:
- Notes:

#### Artifact Checks

- System audio checklist status:
- System audio audible:
- System audio content notes:
- Microphone checklist status:
- Microphone audible:
- Microphone content notes:
- Mixed audio checklist status:
- Mixed audio audible:
- Mixed audio content notes:
- Metadata checklist status:
- Transcript JSON checklist status:
- Transcript markdown checklist status:

#### Copied Evidence

Paste the full proof UI evidence block here:

```markdown

```

### Acceptance

- Remote speaker audio is audible in the system audio artifact.
- Local microphone audio is audible in the microphone artifact.
- Mixed audio is present and audible, or its diagnostics explain the failure.
- Metadata is present.
- The proof UI evidence checklist clearly marks system, microphone, mixed, metadata, transcript JSON, and transcript markdown as PASS or FAIL.
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
