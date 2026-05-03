# Personal Meeting, Task, and Second Brain App

Native macOS and iOS app for meeting capture, notes, tasks, screenshot OCR, audio retention, and a Cognee powered second brain.

## Status

Phase 1 foundation is in progress. The current gate is user approval of the Convex schema before Phase 2 starts.

Completed foundation items:

- `SPEC.md` and `DECISIONS.md` exist at the repository root.
- Convex is initialized with the reviewed schema and generated types.
- Core Swift package scaffold exists at `packages/Core`.
- macOS project scaffold exists at `apps/macOS/MeetingApp.xcodeproj`.
- iOS project scaffold exists at `apps/iOS/MeetingAppMobile.xcodeproj`.
- Git remote is set to `https://github.com/sajor2000/meetingsecondbrain.git`.

No Phase 2 capture, transcription, calendar implementation, LLM enhancement, or Cognee code has been started.

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
- `convex`
- `mac-studio`

Open the canonical workspace in Xcode:

```bash
open MeetingSecondBrain.xcworkspace
```

Convex local development:

```bash
npm run convex:dev
```

## Costs

The target operating cost is about $5 to $6 per month, excluding Apple Developer Program fees and hardware.
