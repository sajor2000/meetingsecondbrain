/// <reference types="vite/client" />

import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";

const functions = api as any;
const modules = import.meta.glob(["./**/*.ts", "!./**/*.test.ts"]);

function makeConvexTest() {
  return convexTest(schema, modules);
}

const identity = {
  issuer: "issuer-alpha",
  subject: "subject-alpha",
  tokenIdentifier: "issuer-alpha|subject-alpha",
};

describe("RecallOS Convex function contracts", () => {
  test("meetings list by user start date and update notes", async () => {
    const t = makeConvexTest().withIdentity(identity);

    const olderMeetingId = await t.mutation(functions.meetings.create, {
      localId: "11111111-1111-4111-8111-111111111111",
      title: "Older meeting",
      startsAt: 1,
      endsAt: 2,
    });
    const newerMeetingId = await t.mutation(functions.meetings.create, {
      localId: "22222222-2222-4222-8222-222222222222",
      title: "Newer meeting",
      startsAt: 10,
      endsAt: 11,
    });

    await t.mutation(functions.meetings.updateNotes, {
      meetingId: olderMeetingId,
      status: "completed",
      summary: "Summary needle",
      rawNotes: "Raw notes",
      enhancedNotes: "Enhanced notes",
      noteBlocks: [{ title: "Block", body: "Body" }],
    });

    const meetings = await t.query(functions.meetings.list, {});
    expect(meetings.map((meeting: any) => meeting._id)).toEqual([newerMeetingId, olderMeetingId]);
    expect(meetings[1]).toMatchObject({
      status: "completed",
      summary: "Summary needle",
      rawNotes: "Raw notes",
      enhancedNotes: "Enhanced notes",
      noteBlocks: [{ title: "Block", body: "Body" }],
    });
  });

  test("meeting create is idempotent and rejects non-uuid local IDs", async () => {
    const t = makeConvexTest().withIdentity(identity);

    await expect(
      t.mutation(functions.meetings.create, {
        localId: "not-a-uuid",
        title: "Invalid local ID",
        startsAt: 1,
        endsAt: 2,
      }),
    ).rejects.toThrow("UUID");

    const meetingId = await t.mutation(functions.meetings.create, {
      localId: "99999999-9999-4999-8999-999999999999",
      title: "Retry-safe meeting",
      startsAt: 1,
      endsAt: 2,
    });
    const retriedMeetingId = await t.mutation(functions.meetings.create, {
      localId: "99999999-9999-4999-8999-999999999999",
      title: "Retry-safe meeting duplicate",
      startsAt: 3,
      endsAt: 4,
    });

    expect(retriedMeetingId).toBe(meetingId);
    const meetings = await t.query(functions.meetings.list, {});
    expect(meetings.map((meeting: any) => meeting._id)).toEqual([meetingId]);
    expect(meetings[0].title).toBe("Retry-safe meeting");
  });

  test("tasks support create, list, move, local-id move, and search result shape", async () => {
    const t = makeConvexTest().withIdentity(identity);

    const meetingId = await t.mutation(functions.meetings.create, {
      localId: "33333333-3333-4333-8333-333333333333",
      title: "Task source meeting",
      startsAt: 1,
      endsAt: 2,
    });
    const taskId = await t.mutation(functions.tasks.createFromMeeting, {
      localId: "44444444-4444-4444-8444-444444444444",
      title: "Searchable task needle",
      sourceMeetingId: meetingId,
      sourceTimestamp: 64,
      extractionConfidence: 0.87,
    });

    const openTasks = await t.query(functions.tasks.listOpen, {});
    expect(openTasks).toHaveLength(1);
    expect(openTasks[0]).toMatchObject({
      _id: taskId,
      status: "open",
      priority: "medium",
      sourceMeetingId: meetingId,
      sourceMeetingLocalId: "33333333-3333-4333-8333-333333333333",
      sourceTimestamp: 64,
      extractionConfidence: 0.87,
    });

    const meetingTasks = await t.query(functions.tasks.listForMeeting, { meetingId });
    expect(meetingTasks.map((task: any) => task._id)).toEqual([taskId]);

    const otherMeetingId = await t.mutation(functions.meetings.create, {
      localId: "55555555-5555-4555-8555-555555555555",
      title: "Other task source",
      startsAt: 3,
      endsAt: 4,
    });
    const otherTaskId = await t.mutation(functions.tasks.createFromMeeting, {
      localId: "66666666-6666-4666-8666-666666666666",
      title: "Other task",
      sourceMeetingId: otherMeetingId,
    });
    const allTasks = await t.query(functions.tasks.listForMeeting, {});
    expect(new Set(allTasks.map((task: any) => task._id))).toEqual(new Set([taskId, otherTaskId]));

    await t.mutation(functions.tasks.move, { taskId, status: "done" });
    const doneTasks = await t.query(functions.tasks.listForMeeting, { meetingId });
    expect(doneTasks[0].status).toBe("done");
    expect(doneTasks[0].completedAt).toBeTypeOf("number");

    const movedByLocalId = await t.mutation(functions.tasks.moveByLocalIds, {
      localIds: ["44444444-4444-4444-8444-444444444444"],
      status: "waiting",
    });
    expect(movedByLocalId).toEqual([taskId]);
    const waitingTasks = await t.query(functions.tasks.listForMeeting, { meetingId });
    expect(waitingTasks[0].status).toBe("waiting");
    expect(waitingTasks[0].completedAt).toBeUndefined();

    const retriedTaskId = await t.mutation(functions.tasks.createFromMeeting, {
      localId: "44444444-4444-4444-8444-444444444444",
      title: "Duplicate retry should not create another task",
      sourceMeetingId: meetingId,
    });
    expect(retriedTaskId).toBe(taskId);
    const tasksAfterRetry = await t.query(functions.tasks.listForMeeting, { meetingId });
    expect(tasksAfterRetry.map((task: any) => task._id)).toEqual([taskId]);

    await expect(
      t.mutation(functions.tasks.createFromMeeting, {
        localId: "not-a-uuid",
        title: "Invalid task local ID",
        sourceMeetingId: meetingId,
      }),
    ).rejects.toThrow("UUID");
    await expect(
      t.mutation(functions.tasks.moveByLocalIds, {
        localIds: ["not-a-uuid"],
        status: "done",
      }),
    ).rejects.toThrow("UUID");

    const results = await t.query(functions.search.brain, { query: "Searchable" });
    expect(results).toEqual([
      expect.objectContaining({
        id: "44444444-4444-4444-8444-444444444444",
        title: "Searchable task needle",
        source: "Task",
        snippet: "Meeting task",
        sourceMeetingID: "33333333-3333-4333-8333-333333333333",
      }),
    ]);
  });
});
