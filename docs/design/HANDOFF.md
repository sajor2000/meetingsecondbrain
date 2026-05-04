# RecallOS Coding Agent Handoff

## What To Read First

Read these in order:

1. `/Users/jcrmacstudio/Desktop/open-design/.od/projects/8cf51484-1b6c-4588-adcb-0afebf87b658/index.html`
2. `SPEC.md`
3. `UI_UX_DESIGN.md`
4. `DECISIONS.md`

The external `index.html` is the canonical design artifact. `/Users/jcrmacstudio/Desktop/open-design/.od/projects/8cf51484-1b6c-4588-adcb-0afebf87b658/recallos-meeting-second-brain.html` is a synced backup.

## Important Framing

This is a native Apple-platform app.

Do not build a web app from the HTML. Use the HTML to understand layout, content hierarchy, visual system, and interaction intent.

Primary target:

- macOS SwiftUI

Secondary target:

- iOS SwiftUI companion

Shared code:

- Core Swift package

Backend:

- Convex

## Existing Implementation Repo

Do not recreate the foundation from this artifact folder.

The native app implementation already lives at:

- Local project: this Git checkout. Common local checkouts include `/Users/jcrmacstudio/Desktop/Notes:Second Brain` and CE worktrees such as `/Users/jcrmacstudio/Desktop/meetingsecondbrain-recallos-commit`.
- GitHub repo: `https://github.com/sajor2000/meetingsecondbrain`

Current foundation inventory:

- `apps/RecallOSMac` - macOS SwiftUI target and AppKit recording banner panel.
- `apps/RecallOSiOS` - iOS SwiftUI companion target.
- `apps/Shared` - app-level shared repository/store wiring.
- `packages/RecallOSCore` - shared Core Swift package with design tokens, models, components, stores, fixtures, and tests.
- `convex` - Convex schema, package metadata, and backend stubs.
- `project.yml` - XcodeGen project definition.
- `SPEC.md`, `UI_UX_DESIGN.md`, `DECISIONS.md`, `README.md` - implementation docs in the app repo.

## Product Priority

Build Mac first.

The first production loop is:

1. Floating recording banner
2. Start recording
3. Live notes
4. Live transcript
5. Stop recording
6. Enhance notes
7. Review AI additions
8. Review extracted tasks
9. Save tasks
10. Search meeting later

iOS comes after the Mac loop works.

## Visual Rules

Use:

- Deep teal `#0F4C5C`
- SF/system typography
- Regular and medium weights only
- Native neutral surfaces
- 0.5 px borders
- 8 to 12 px card corners

Do not use:

- Gradients
- Shadows
- Heavy font weights
- Decorative emoji
- Rainbow status colors
- Web-first layout assumptions

## Critical UX Pattern

Hybrid notes are the signature pattern.

User-authored notes:

- Primary text
- Regular weight

AI additions:

- Gray secondary text
- Vertical left bar
- Timestamp link
- Editable and removable

Timestamp format:

- `↗ MM:SS`

Timestamp behavior:

- Seek audio
- Scroll transcript
- Highlight source segment

## Known Decision

The optional task board is approved.

Record it as:

> Board mode is an optional task workflow view for meeting-derived tasks. It is not the default task experience.

Default task UX remains list-first and Things-inspired.

## Suggested First Prompt For Coding Agent

```text
You are building RecallOS, a native Mac-first meeting second brain with an iOS companion.

Read the external design artifact, SPEC.md, UI_UX_DESIGN.md, DECISIONS.md, and docs/plans/recallos-pilot-mvp-sprint-plan.md before coding.

Use the existing implementation repo at /Users/jcrmacstudio/Desktop/Notes:Second Brain. Do not recreate the repo structure, Swift package, app targets, Convex folder, or foundation docs from scratch.

Treat the HTML as design reference only. Build native SwiftUI apps.

Continue from the existing SwiftUI foundation and implement the Mac recording loop first.

Do not mark a feature complete without code evidence and tests or previews.
```

## Handoff Checklist

Before implementation starts:

- Confirm Mac-first scope.
- Confirm iOS companion scope.
- Confirm Convex backend choice.
- Confirm transcription provider choices.
- Confirm optional Kanban decision.
- Confirm first milestone is the Mac recording loop.

Before demo:

- Run app builds.
- Run tests.
- Capture screenshots.
- Run feature audit against `SPEC.md` and `UI_UX_DESIGN.md`.
