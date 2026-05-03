# Deviations and decisions log

- 2026-05-03: Placed the working repository at `/Users/jcrmacstudio/Desktop/meeting-app` instead of keeping it under `/Users/jcrmacstudio/Desktop/Notes:Second Brain`. Convex local dev generated invalid module paths when any parent folder contained spaces or punctuation. This preserves the spec's `meeting-app/` root and lets Convex initialize cleanly.
- 2026-05-03: Server-side LLM calls use `OPENROUTER_API_KEY` in Convex environment variables. macOS Keychain may still store a local copy for settings validation, but Convex actions cannot read Keychain directly.
- 2026-05-03: Calendar source records store typed non-secret config plus secret reference keys. Actual ICS URLs and Google OAuth material should live in Convex environment variables or platform key storage.
- 2026-05-03: Audio remains local by default. Convex audio file sync is opt-in because always syncing 88 meeting hours per month would likely exceed the intended free-tier operating envelope.
- 2026-05-03: GitHub repository for this project is `sajor2000/meetingsecondbrain` at `https://github.com/sajor2000/meetingsecondbrain.git`.
- 2026-05-03: Phase 1 Xcode projects are generated with XcodeGen from checked-in `project.yml` files. This keeps project files reproducible while preserving the required `.xcodeproj` deliverables.
- 2026-05-03: The canonical native entry point is `MeetingSecondBrain.xcworkspace`, which references both generated app projects and the Core package.
- 2026-05-03: The local developer directory currently points to Command Line Tools, not full Xcode. The strict Phase 1 gate is `npm run phase1:check` and includes a Core command line self-test plus macOS and iOS Xcode scheme tests. `npm run phase1:check:local` is only a Command Line Tools sanity check.
- 2026-05-03: Deferred the real meeting capture gate because a live Zoom, Meet, or Teams call was not available. Continued with offline-safe U4 and U5 transcription scaffolding only. Phase 2 still requires the manual capture and 30 minute transcription gates before approval.
