---
title: feat: Convex backend foundation
type: feat
status: completed
date: 2026-05-04
origin: SPEC.md
---

# feat: Convex backend foundation

## Summary

Build the first Convex backend function layer on a parallel branch from `main`, away from the microphone capture sprint. The branch should expose schema-aligned meeting, task, and search functions that native clients can call in a later integration sprint.

## Scope Boundaries

- Do not modify microphone capture, audio artifact, SwiftData persistence, Xcode project, or RecallOS Mac UI files.
- Do not add authentication, OpenRouter enhancement actions, Cognee ingestion, calendar sync, or file upload flows.
- Do not change `convex/schema.ts` unless an existing field is impossible to use safely from functions.

## Implementation Units

### U1: Meeting Functions

Files:

- Create: `convex/meetings.ts`

Approach:

- Add public queries for retrieving a meeting by ID and listing meetings in a start-time window.
- Add public mutations for creating manual meetings, updating note content, and updating enhancement/second-brain state.
- Default required schema arrays and status fields inside creation so clients do not need to duplicate boilerplate.
- Keep `searchableText` synchronized with title, raw notes, enhanced notes, summary, decisions, and open questions where those fields are updated.

Test scenarios:

- Create a meeting with only required client-facing fields and confirm defaults satisfy the schema.
- List meetings by date window in descending start-time order.
- Updating notes updates `updatedAt` and `searchableText`.
- Updating enhancement status accepts only schema-backed status values.

### U2: Task Functions

Files:

- Create: `convex/tasks.ts`

Approach:

- Add public queries for listing tasks by status, due-date range, meeting source, and user/others assignee.
- Add public mutations for creating tasks, updating task metadata, and updating task status.
- Set `completedAt` when status becomes `done`, and clear it when a done task is reopened.
- Preserve source meeting evidence fields without requiring a meeting for manually created tasks.

Test scenarios:

- Create manual and meeting-sourced tasks with schema defaults.
- Filter tasks by status, assignee, due date, and source meeting.
- Marking a task done sets `completedAt`; reopening clears it.
- Metadata updates refresh `updatedAt` without overwriting omitted fields.

### U3: Search Functions

Files:

- Create: `convex/search.ts`

Approach:

- Add public meeting note search using the existing `meetings.search_notes` index.
- Add public transcript search using the existing `transcriptSegments.search_transcripts` index.
- Keep optional limits bounded so callers cannot request unbounded result sets.
- Return enough meeting/transcript context for clients to render search results without adding new schema fields.

Test scenarios:

- Meeting search supports a text query and optional folder filter.
- Transcript search supports a text query and optional meeting filter after search.
- Empty or whitespace query returns an empty list.
- Limit arguments are clamped to a small backend maximum.

## Verification

- Run `npm run convex:check`.
- Run `npm run convex:codegen`.
- Run `ce-code-review mode:report-only base:main plan:docs/plans/2026-05-04-001-feat-convex-backend-foundation-plan.md` before PR.

## Assumptions

- Branch name: `codex/convex-backend-foundation`.
- `open-design/` remains untracked.
- Native Swift app integration will happen in a later branch.
