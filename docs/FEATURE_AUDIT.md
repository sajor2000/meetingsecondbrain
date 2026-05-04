# Feature Audit

Run date: 2026-05-04

Design sources:

- `/Users/jcrmacstudio/Desktop/open-design/.od/projects/8cf51484-1b6c-4588-adcb-0afebf87b658/index.html`
- `/Users/jcrmacstudio/Desktop/open-design/.od/projects/8cf51484-1b6c-4588-adcb-0afebf87b658/recallos-meeting-second-brain.html`

## Validation Evidence

- `swift test --package-path packages/RecallOSCore`: passed, 25 tests.
- `xcodebuild test -project RecallOS.xcodeproj -scheme RecallOSSharedTests -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`: passed, 13 tests.
- `npm --prefix convex run typecheck`: passed.
- `npm --prefix convex test`: passed, 10 tests.
- `xcodegen generate`: passed, generated `RecallOS.xcodeproj`.
- `xcodebuild -project RecallOS.xcodeproj -scheme RecallOSMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`: passed.
- `xcodebuild -project RecallOS.xcodeproj -scheme RecallOSiOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`: passed.
- iOS simulator install/launch after plist fix: passed.
- iOS screenshot captured: `Screenshots/ios-today.png`.
- macOS screenshot capture attempted with `screencapture`: failed with `could not create image from display` in this host session.

## SPEC.md Coverage

| Area | Status | Evidence |
| --- | --- | --- |
| Docs first | Complete | `SPEC.md`, `UI_UX_DESIGN.md`, `DECISIONS.md`, `README.md` |
| Shared Core tokens | Complete | `packages/RecallOSCore/Sources/RecallOSCore/Design` |
| Core models | Complete | `packages/RecallOSCore/Sources/RecallOSCore/Models` |
| macOS shell | Implemented shell | `apps/RecallOSMac/Sources/MacContentView.swift` |
| Recording banner | Implemented UI/panel | `RecordingBannerView`, `RecordingBannerPanelController` |
| Notes surfaces | Implemented sample UI | `HybridNoteBlockView`, `NotesEditorView` |
| Task system | Store-backed fixture UI | `TaskRowView`, `TaskBoardView`, `TaskStore`, `RecallOSAppStore` |
| iOS companion | Implemented shell | `apps/RecallOSiOS/Sources/IOSContentView.swift` |
| Second brain UI | Implemented sample UI | `SearchResultCard`, Brain tab/rail |
| App data boundary | Implemented boundary | `RecallOSAppStore`, repository protocols, fixture/local repositories, `RecallOSStoreFactory` |
| Convex client boundary | Opt-in boundary only | `ConvexRecallOSRepository`, `RecallOSConvexDTOs`, live mode guarded by `RECALLOS_USE_LIVE_CONVEX=1` |
| Convex backend | Stubbed with checks | `convex/schema.ts`, `meetings.ts`, `tasks.ts`, `search.ts`, Convex tests |
| Tests | Partial but expanded | Core tests, shared app-store/factory tests, Convex tests |
| Screenshots | Partial | iOS screenshot captured; macOS capture blocked |

## UI_UX_DESIGN.md Coverage

Implemented:

- Deep teal accent `#0F4C5C`.
- Accent dark `#1A6F86`.
- SF/system typography through `Font.system`.
- Two product weights via token scale: regular and medium.
- Hybrid notes with primary user text, gray AI additions, left rule, and `↗ MM:SS` timestamp links.
- Three-pane macOS layout.
- iOS tabs for Today, Meetings, Tasks, Brain.
- Optional board mode as a non-default task mode.

Needs iteration:

- Native macOS screenshot verification is blocked until the runtime has screen capture access.
- iOS visual scale should be reviewed on physical device and at default accessibility settings.
- Board drag/drop mutates parent task state through store/repository boundaries; live Convex persistence remains Sprint 2 work.
- AppKit banner is implemented but needs scenario tests for multi-display, fullscreen, and meeting transitions.

## Not Complete

- AVFoundation audio capture.
- ScreenCaptureKit screenshot capture.
- Local transcription providers.
- AI enhancement pipeline.
- Live Convex subscriptions and mutations.
- Authentication and multi-user sync.
- Real Convex-backed second brain search/indexing.
- End-to-end UI tests.
