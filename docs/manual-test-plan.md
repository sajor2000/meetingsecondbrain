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
