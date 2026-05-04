---
title: fix: Convex backend search index hardening
type: fix
status: completed
date: 2026-05-04
origin: CE review feedback on PR #16
---

# fix: Convex backend search index hardening

## Summary

Harden the parallel Convex backend branch after review found that the first backend-foundation pass exposed unauthenticated legacy-table functions. This PR now keeps only the safe schema and repository hygiene changes, and defers auth-scoped meeting, task, and search APIs to a separate plan.

## Scope Boundaries

- Do not reintroduce public functions for legacy `meetings`, `tasks`, or `transcriptSegments` tables.
- Do not modify microphone capture, audio artifacts, SwiftData persistence, Xcode project files, or RecallOS Mac UI files.
- Do not include unrelated web app, dependency, or `open-design/` changes.

## Implementation Units

### U1: Search Index Hardening

Files:

- Modify: `convex/schema.ts`

Approach:

- Add `meetingId` as a filter field on `transcriptSegments.search_transcripts`.
- Keep the change schema-only until a future auth-scoped transcript search API is designed.

Test scenarios:

- Confirm the schema defines `search_transcripts` with `searchField: "text"` and `filterFields: ["meetingId"]`.
- Confirm no public transcript search function is added on the legacy `transcriptSegments` table.

### U2: Repository Hygiene

Files:

- Modify: `.gitignore`

Approach:

- Ignore `.DS_Store` so local macOS metadata is not accidentally staged with Convex work.

Test scenarios:

- Confirm `.DS_Store` appears in `.gitignore`.
- Confirm no unrelated web app, dependency, or design assets are included in the PR diff.

### U3: Auth-Risk Cleanup

Files:

- Review: `convex/meetings.ts`
- Review: `convex/tasks.ts`
- Review: `convex/search.ts`

Approach:

- Remove the unauthenticated legacy-table meeting, task, and search exports from this PR.
- Preserve existing RecallOS APIs that derive `userId` with `requireUserId` and enforce ownership checks.

Test scenarios:

- Confirm no public legacy meeting endpoints such as `get`, `listByStartTime`, `createManual`, or `updateState` remain in the PR diff.
- Confirm no public legacy task endpoints such as `list`, `create`, `updateMetadata`, or `updateStatus` remain in the PR diff.
- Confirm no public legacy `meetings` or `transcriptSegments` search exports remain in the PR diff.

## Deferred Work

- Auth-scoped RecallOS meeting, task, and search APIs remain valuable, but they require a separate CE plan.
- Any future implementation must use `requireUserId`, tenant ownership checks, and auth-scoped RecallOS tables instead of the legacy tenantless tables.

## Verification

- Run `git diff --check`.
- Confirm the PR diff contains only `.gitignore`, `convex/schema.ts`, and this plan artifact.
- Run `ce-code-review mode:report-only base:main plan:docs/plans/2026-05-04-001-feat-convex-backend-foundation-plan.md`.
- Do not block on `npm run convex:codegen` while `CONVEX_DEPLOYMENT` is unset.

## Assumptions

- PR #16 should stay small and auth-safe instead of rebuilding the broader backend foundation in this branch.
- The larger Convex backend foundation will be planned and implemented later against auth-scoped RecallOS data.
