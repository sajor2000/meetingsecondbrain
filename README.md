# RecallOS

RecallOS is a native Apple-platform meeting second brain inspired by Granola, Things 3, and Notion. It records meetings, supports live and enhanced notes, extracts action items, and connects meetings, transcript evidence, people, topics, decisions, and tasks.

## Design Source

The high-fidelity HTML artifact is the visual and UX reference, not implementation code to port:

- `/Users/jcrmacstudio/Desktop/open-design/.od/projects/8cf51484-1b6c-4588-adcb-0afebf87b658/index.html`
- `/Users/jcrmacstudio/Desktop/open-design/.od/projects/8cf51484-1b6c-4588-adcb-0afebf87b658/recallos-meeting-second-brain.html`

Existing artifact screenshots:

- `/Users/jcrmacstudio/Desktop/open-design/.od/projects/8cf51484-1b6c-4588-adcb-0afebf87b658/desktop.png`
- `/Users/jcrmacstudio/Desktop/open-design/.od/projects/8cf51484-1b6c-4588-adcb-0afebf87b658/mobile.png`

## Repository

Project instruction source names this GitHub repository:

`https://github.com/sajor2000/meetingsecondbrain`

This local folder is scaffolded as a buildable Apple project. Add the remote when preparing to publish:

```sh
git init
git remote add origin https://github.com/sajor2000/meetingsecondbrain.git
```

## Structure

- `project.yml` - XcodeGen project definition for macOS and iOS apps.
- `packages/RecallOSCore` - shared Swift package for tokens, models, fixtures, and reusable SwiftUI components.
- `apps/RecallOSMac` - macOS SwiftUI app shell.
- `apps/RecallOSiOS` - iOS SwiftUI companion app shell.
- `convex` - Convex schema and backend stubs.
- `SPEC.md` - product requirements and implementation evidence.
- `UI_UX_DESIGN.md` - native design translation from the artifact.
- `DECISIONS.md` - architectural and product decisions.

## Runtime Mode

The current native apps run in demo fixture mode by default while the Swift Convex adapter is still a boundary artifact. Setting `RECALLOS_USE_LIVE_CONVEX=1` intentionally shows a visible configuration error instead of falling back to fixtures, so live-mode mistakes are not hidden.

Live Convex remains Sprint 1/Sprint 2 work: implement the adapter, then flip `ConvexRecallOSRepository.supportsLiveUse` with repository and mapping tests.

## Build

Generate the Xcode project:

```sh
xcodegen generate
```

Run shared package tests:

```sh
swift test --package-path packages/RecallOSCore
```

Build macOS:

```sh
xcodebuild -project RecallOS.xcodeproj -scheme RecallOSMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Build iOS:

```sh
xcodebuild -project RecallOS.xcodeproj -scheme RecallOSiOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Current Status

Implemented in this pass:

- Shared Core design tokens.
- Core models for meetings, transcript segments, meeting tasks, screenshots, calendar events, people, topics, and decisions.
- Reusable hybrid note, timestamp, recording banner, task row, search card, and task board components.
- Repository protocols, fixture repositories, sync identifiers, and shared app stores for the first data boundary.
- macOS three-pane shell with notes editor, right rail tabs, grouped tasks, store-backed board mode, recording status bar, and floating `NSPanel` banner.
- iOS companion shell with store-backed Today, Meetings, Tasks, Brain, quick memo, and read-only meeting views.
- Convex schema and mutation/query stubs.
- Swift package unit tests.

Not production-complete yet:

- Live Convex Swift adapter/subscriptions/mutations, real audio capture, screen capture, transcription, diarization, AI enhancement, background sync, and Convex deployment.
- Screenshot preview generation for the native apps.

When only Command Line Tools are selected, use the local sanity check. This is not the approval gate:

```sh
npm run phase1:check:local
```

## Architecture

See `SPEC.md` for the locked architecture, stack decisions, build order, and performance targets.

## Development

Open the canonical workspace in Xcode:

```sh
open MeetingSecondBrain.xcworkspace
```

RecallOS native prototype checks:

```sh
npm run swift:test:core
npm run xcode:build
```

Convex local development:

```sh
npm run convex:dev
```

## Costs

The target operating cost is about $5 to $6 per month, excluding Apple Developer Program fees and hardware.
