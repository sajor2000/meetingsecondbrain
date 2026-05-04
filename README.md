# Personal Meeting, Task, and Second Brain App

Native macOS and iOS app for meeting capture, notes, tasks, screenshot OCR, audio retention, and a Cognee powered second brain.

The meeting capture model is bot-free. The app does not join meetings as a participant. On macOS, it records local system audio from the meeting client plus local microphone audio from the user.

## Status

Phase 1 foundation is complete. Phase 2 core capture proof is in progress, with the macOS recording scaffold implemented and the real meeting capture gate still pending.

Completed foundation items:

- `SPEC.md` and `DECISIONS.md` exist at the repository root.
- Convex is initialized with the reviewed schema and generated types.
- Core Swift package scaffold exists at `packages/Core`.
- macOS project scaffold exists at `apps/macOS/MeetingApp.xcodeproj`.
- iOS project scaffold exists at `apps/iOS/MeetingAppMobile.xcodeproj`.
- Git remote is set to `https://github.com/sajor2000/meetingsecondbrain.git`.

Phase 2 capture proof items now present:

- macOS recording session UI scaffold with local capture proof controls.
- ScreenCaptureKit system audio capture service.
- AVFoundation microphone capture service.
- RecallOS native microphone artifact boundary with local metadata persistence.
- Recording artifact model, metadata writer, and local diagnostic output folder.
- Recorder lifecycle tests for startup cleanup, stop cleanup, artifact uniqueness, and live meter activity.
- Manual real meeting test plan at `docs/manual-test-plan.md`.
- Capture hardening learning at `docs/solutions/logic-errors/stabilize-macos-capture-recorder-cleanup-and-activity-state-2026-05-03.md`.

Phase 2 transcription proof items now present:

- Core transcript models and transcription provider protocol.
- FluidAudio Parakeet dependency pinned to version `0.14.3` in a macOS-only package product.
- Offline-safe Parakeet batch transcription wrapper with token timing mapped to transcript segments.
- macOS transcription runner that writes transcript JSON and markdown artifacts.
- Automated tests for transcript modeling, model selection, missing audio files, and transcript artifact writing.

Real meeting capture, real 30 minute transcription, and Parakeet diarization gates are still pending. Calendar implementation, LLM enhancement, and Cognee code have not been started.

## Setup

Install JavaScript dependencies:

```bash
npm install
```

Install XcodeGen if it is not already installed:

```bash
brew install xcodegen
```

Regenerate Xcode projects:

```bash
npm run xcodegen:macos
npm run xcodegen:ios
```

Run the strict Phase 1 approval gate:

```bash
npm run phase1:check
```

Running Xcode scheme tests requires a full Xcode developer directory:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
npm run phase1:check
```

If the iOS simulator platform is missing, install it with Xcode Settings > Components or:

```bash
xcodebuild -downloadPlatform iOS
```

The iOS test runner defaults to `platform=iOS Simulator,name=iPhone 17`. Override it when needed:

```bash
IOS_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 17' npm run xcode:test:ios
```

When only Command Line Tools are selected, use the local sanity check. This is not the approval gate:

```bash
npm run phase1:check:local
```

## Architecture

See `SPEC.md` for the locked architecture, stack decisions, build order, and performance targets.

## Development

Workspaces:

- `apps/macOS`
- `apps/iOS`
- `packages/Core`
- `Apps/RecallOSMac`
- `Apps/RecallOSiOS`
- `Packages/RecallOSCore`
- `convex`
- `mac-studio`

Open the canonical workspace in Xcode:

```bash
open MeetingSecondBrain.xcworkspace
```

RecallOS native prototype checks:

```bash
npm run swift:test:recallos-core
npm run xcode:build:recallos
```

Convex local development:

```bash
npm run convex:dev
```

## Costs

The target operating cost is about $5 to $6 per month, excluding Apple Developer Program fees and hardware.
