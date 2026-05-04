# UI/UX and Code Audit

Run date: 2026-05-03

Scope:

- `Apps/RecallOSMac`
- `Apps/RecallOSiOS`
- `Packages/RecallOSCore`
- `SPEC.md`
- `UI_UX_DESIGN.md`
- High-fidelity artifact at `/Users/jcrmacstudio/Desktop/open-design/.od/projects/8cf51484-1b6c-4588-adcb-0afebf87b658/recallos-meeting-second-brain.html`

## Design Findings

### Fixed: iOS Was Not Using Full-Screen Device Geometry

The iOS app was letterboxed in the simulator, which made the app feel oversized and caused the floating tab bar to overlap task content. Root cause was missing launch-screen metadata.

Fix:

- Added `Apps/RecallOSiOS/Resources/LaunchScreen.storyboard`.
- Added `UILaunchStoryboardName` to `Apps/RecallOSiOS/Resources/Info.plist`.

Evidence:

- New screenshot: `Screenshots/ios-today.png`.

### Fixed: iOS Title Scale Drifted From App Tokens

The original iOS Today screen used a large native navigation title, which violated the app's 22 pt page-title token and made the companion app feel louder than the design artifact.

Fix:

- Replaced the large native Today title with a custom `AppFont.pageTitle` header.
- Kept other navigation screens inline to avoid oversized titles.

### Fixed: Summary Surfaces Were Duplicated

macOS and iOS each hand-built summary blocks. That made it easy for the core hybrid-note visual language to drift.

Fix:

- Added `CalmSummaryBlock` in `RecallOSCore`.
- Reused it in macOS and iOS meeting surfaces.

### Fixed: Board Mode Was Visual Only

The Kanban board advertised draggable cards but did not accept drops, so it looked more functional than it was.

Fix:

- Added local `dropDestination` handling to `TaskBoardView`.
- Dropping a card into a column now mutates the local board state and completed timestamp for Done.
- Board mutations now flow through a `TaskStore`/`RecallOSAppStore` boundary so parent app state observes moves.

Remaining caveat:

- The live Convex mutation body is still future work; Sprint 1 adds the app-layer repository boundary, and Sprint 2 should implement actual Convex subscriptions/mutations.

### Fixed: Token Drift In Sidebar Typography

The macOS sidebar row title used `AppFont.secondary.weight(.medium)`, creating a local font style outside the declared token set.

Fix:

- Sidebar row titles now use `AppFont.secondary`.

## Code Findings

### Fixed: App Shells Now Use Store-Backed Fixtures

The first shell pass used `SampleData` directly in macOS and iOS views. The app shells now render through `RecallOSAppStore.fixture()`, with fixture data contained behind repository/store boundaries.

Remaining caveat:

- The store currently uses fixture repositories by default. Real Convex subscriptions are planned for Sprint 2.

### P2: Convex Repository Is Boundary-Only

The project now has repository protocols and an app-layer `ConvexRecallOSRepository`, but live Convex list/search/mutation implementations are intentionally not complete yet.

Recommendation:

- Implement `ConvexRecallOSRepository` subscriptions and task move mutation in Sprint 2.
- Add mapping tests for Convex document IDs to Core `convexID` fields.

### P2: Recording Banner Needs Scenario Tests

The banner has the correct visual states and `NSPanel` placement logic, but the behavior needs tests or manual scripts for multi-display, fullscreen spaces, and transition timing.

Recommendation:

- Add a small macOS UI test harness for `preMeeting`, `inProgress`, `recording`, and `adHoc`.
- Include explicit assertions that recording state has no dismiss action.

### P3: Native iOS Tab Bar Adds System Chrome

The iOS 26 simulator renders a glassy floating tab bar. It is native and acceptable for now, but it is more visually expressive than the artifact's calmer tab bar.

Recommendation:

- Keep the native tab bar while product direction is still evolving.
- Revisit only if it keeps competing with task content after real data lands.

### P3: Icon Sizing Uses Raw System Fonts

A few icon-only controls use `.font(.system(...))`. This does not violate the text token contract, but icon sizing would be cleaner as a token.

Recommendation:

- Add `AppIconSize` or constants under design tokens if icon sizing starts repeating.

## Validation

Commands run after fixes:

```sh
swift test --package-path Packages/RecallOSCore
xcodebuild -project RecallOS.xcodeproj -scheme RecallOSMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project RecallOS.xcodeproj -scheme RecallOSiOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Results:

- Core tests passed: 4 tests.
- macOS build succeeded.
- iOS build succeeded.
- iOS simulator install and launch succeeded.
- iOS screenshot refreshed at `Screenshots/ios-today.png`.

## External Worktree Note

The sibling design repository at `/Users/jcrmacstudio/Desktop/open-design` has a pre-existing modified file:

- `apps/web/next-env.d.ts`

This audit did not modify or revert it.
