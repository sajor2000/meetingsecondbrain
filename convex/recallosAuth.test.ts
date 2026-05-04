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

const alphaIdentity = {
  issuer: "issuer-alpha",
  subject: "shared-subject",
  tokenIdentifier: "issuer-alpha|shared-subject",
};

const betaIdentity = {
  issuer: "issuer-beta",
  subject: "shared-subject",
  tokenIdentifier: "issuer-beta|shared-subject",
};

describe("RecallOS Convex auth boundaries", () => {
  test("public RecallOS functions reject unauthenticated callers", async () => {
    const t = makeConvexTest();
    const { meetingId, taskId } = await t.run(async (ctx) => {
      const meetingId = await ctx.db.insert("recallOSMeetings", {
        userId: alphaIdentity.tokenIdentifier,
        localId: "11111111-1111-4111-8111-111111111111",
        title: "Alpha unauth meeting",
        startsAt: 1,
        endsAt: 2,
        status: "scheduled",
        attendeeIds: [],
        topicIds: [],
        createdAt: 1,
        updatedAt: 1,
      });
      const taskId = await ctx.db.insert("recallOSTasks", {
        userId: alphaIdentity.tokenIdentifier,
        localId: "22222222-2222-4222-8222-222222222222",
        title: "Alpha unauth task",
        status: "open",
        priority: "medium",
        sourceMeetingId: meetingId,
        sourceMeetingLocalId: "11111111-1111-4111-8111-111111111111",
        createdAt: 1,
        updatedAt: 1,
      });
      return { meetingId, taskId };
    });

    const unauthenticatedCalls = [
      () => t.query(functions.meetings.list, {}),
      () => t.mutation(functions.meetings.create, {
        localId: "33333333-3333-4333-8333-333333333333",
        title: "Unauth create",
        startsAt: 1,
        endsAt: 2,
      }),
      () => t.mutation(functions.meetings.updateNotes, {
        meetingId,
        summary: "Unauth notes",
      }),
      () => t.mutation(functions.meetings.update, {
        meetingId,
        title: "Unauth update",
      }),
      () => t.query(functions.tasks.listOpen, {}),
      () => t.query(functions.tasks.listForMeeting, {}),
      () => t.query(functions.tasks.listForMeeting, { meetingId }),
      () => t.query(functions.tasks.listForMeetingByLocalId, {
        meetingLocalId: "11111111-1111-4111-8111-111111111111",
      }),
      () => t.mutation(functions.tasks.createFromMeeting, {
        localId: "44444444-4444-4444-8444-444444444444",
        title: "Unauth task",
        sourceMeetingId: meetingId,
      }),
      () => t.mutation(functions.tasks.move, { taskId, status: "done" }),
      () => t.mutation(functions.tasks.moveByLocalIds, {
        localIds: ["22222222-2222-4222-8222-222222222222"],
        status: "done",
      }),
      () => t.query(functions.search.brain, { query: "anything" }),
    ];

    for (const call of unauthenticatedCalls) {
      await expect(call()).rejects.toThrow("authenticated");
    }
  });

  test("tokenIdentifier isolates users even when subjects match", async () => {
    const t = makeConvexTest();
    const asAlpha = t.withIdentity(alphaIdentity);
    const asBeta = t.withIdentity(betaIdentity);

    await asAlpha.mutation(functions.meetings.create, {
      localId: "11111111-1111-4111-8111-111111111111",
      title: "Alpha planning",
      startsAt: 1,
      endsAt: 2,
    });
    await asBeta.mutation(functions.meetings.create, {
      localId: "22222222-2222-4222-8222-222222222222",
      title: "Beta planning",
      startsAt: 1,
      endsAt: 2,
    });

    const alphaResults = await asAlpha.query(functions.search.brain, { query: "planning" });
    expect(alphaResults).toMatchObject([{ title: "Alpha planning" }]);
    expect(alphaResults).not.toEqual(expect.arrayContaining([expect.objectContaining({ title: "Beta planning" })]));
  });

  test("meeting mutations reject records owned by another user", async () => {
    const t = makeConvexTest();
    const asAlpha = t.withIdentity(alphaIdentity);
    const asBeta = t.withIdentity(betaIdentity);

    const alphaMeetingId = await asAlpha.mutation(functions.meetings.create, {
      localId: "33333333-3333-4333-8333-333333333333",
      title: "Alpha meeting",
      startsAt: 1,
      endsAt: 2,
    });

    await expect(
      asBeta.mutation(functions.meetings.updateNotes, {
        meetingId: alphaMeetingId,
        summary: "Stolen notes",
      }),
    ).rejects.toThrow("Meeting not found");
    await expect(
      asBeta.mutation(functions.meetings.update, {
        meetingId: alphaMeetingId,
        title: "Stolen title",
      }),
    ).rejects.toThrow("Meeting not found");
  });

  test("meeting creation rejects attendee IDs from another user", async () => {
    const t = makeConvexTest();
    const asAlpha = t.withIdentity(alphaIdentity);

    const { betaPersonId, betaTopicId, betaFolderId } = await t.run(async (ctx) => {
      const betaPersonId = await ctx.db.insert("recallOSPeople", {
        userId: betaIdentity.tokenIdentifier,
        localId: "44444444-4444-4444-8444-444444444444",
        displayName: "Beta Person",
      });
      const betaTopicId = await ctx.db.insert("recallOSTopics", {
        userId: betaIdentity.tokenIdentifier,
        localId: "56565656-5656-4656-8656-565656565656",
        name: "Beta Topic",
      });
      const betaFolderId = await ctx.db.insert("recallOSFolders", {
        userId: betaIdentity.tokenIdentifier,
        name: "Beta Folder",
        sortOrder: 1,
      });
      return { betaPersonId, betaTopicId, betaFolderId };
    });

    await expect(
      asAlpha.mutation(functions.meetings.create, {
        localId: "55555555-5555-4555-8555-555555555555",
        title: "Cross-user attendee attempt",
        startsAt: 1,
        endsAt: 2,
        attendeeIds: [betaPersonId],
      }),
    ).rejects.toThrow("Attendee not found");
    await expect(
      asAlpha.mutation(functions.meetings.create, {
        localId: "34343434-3434-4434-8434-343434343434",
        title: "Cross-user topic attempt",
        startsAt: 1,
        endsAt: 2,
        topicIds: [betaTopicId],
      }),
    ).rejects.toThrow("Topic not found");
    await expect(
      asAlpha.mutation(functions.meetings.create, {
        localId: "78787878-7878-4878-8878-787878787878",
        title: "Cross-user folder attempt",
        startsAt: 1,
        endsAt: 2,
        folderId: betaFolderId,
      }),
    ).rejects.toThrow("Folder not found");

    const alphaMeetingId = await asAlpha.mutation(functions.meetings.create, {
      localId: "12121212-1212-4212-8212-121212121212",
      title: "Alpha attendee update target",
      startsAt: 1,
      endsAt: 2,
    });
    await expect(
      asAlpha.mutation(functions.meetings.update, {
        meetingId: alphaMeetingId,
        attendeeIds: [betaPersonId],
      }),
    ).rejects.toThrow("Attendee not found");
    await expect(
      asAlpha.mutation(functions.meetings.update, {
        meetingId: alphaMeetingId,
        topicIds: [betaTopicId],
      }),
    ).rejects.toThrow("Topic not found");
    await expect(
      asAlpha.mutation(functions.meetings.update, {
        meetingId: alphaMeetingId,
        folderId: betaFolderId,
      }),
    ).rejects.toThrow("Folder not found");
  });

  test("task queries and moves reject cross-user meeting/task access", async () => {
    const t = makeConvexTest();
    const asBeta = t.withIdentity(betaIdentity);

    const { meetingId, taskId } = await t.run(async (ctx) => {
      const meetingId = await ctx.db.insert("recallOSMeetings", {
        userId: alphaIdentity.tokenIdentifier,
        localId: "66666666-6666-4666-8666-666666666666",
        title: "Alpha task meeting",
        startsAt: 1,
        endsAt: 2,
        status: "scheduled",
        attendeeIds: [],
        topicIds: [],
        createdAt: 1,
        updatedAt: 1,
      });
      const taskId = await ctx.db.insert("recallOSTasks", {
        userId: alphaIdentity.tokenIdentifier,
        localId: "77777777-7777-4777-8777-777777777777",
        title: "Alpha task",
        status: "open",
        priority: "medium",
        sourceMeetingId: meetingId,
        sourceMeetingLocalId: "66666666-6666-4666-8666-666666666666",
        createdAt: 1,
        updatedAt: 1,
      });
      return { meetingId, taskId };
    });

    await expect(asBeta.query(functions.tasks.listForMeeting, { meetingId })).rejects.toThrow("Meeting not found");
    await expect(
      asBeta.mutation(functions.tasks.createFromMeeting, {
        localId: "88888888-8888-4888-8888-888888888888",
        title: "Cross-user task attempt",
        sourceMeetingId: meetingId,
      }),
    ).rejects.toThrow("Meeting not found");
    await expect(asBeta.mutation(functions.tasks.move, { taskId, status: "done" })).rejects.toThrow("Task not found");
    const movedByLocalId = await asBeta.mutation(functions.tasks.moveByLocalIds, {
      localIds: ["77777777-7777-4777-8777-777777777777"],
      status: "done",
    });
    expect(movedByLocalId).toEqual([]);

    const betaMeetingId = await asBeta.mutation(functions.meetings.create, {
      localId: "99999999-9999-4999-8999-999999999999",
      title: "Beta task meeting",
      startsAt: 3,
      endsAt: 4,
    });
    const betaTaskId = await asBeta.mutation(functions.tasks.createFromMeeting, {
      localId: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      title: "Beta task",
      sourceMeetingId: betaMeetingId,
    });
    const betaGlobalTasks = await asBeta.query(functions.tasks.listForMeeting, {});
    expect(betaGlobalTasks.map((task: any) => task._id)).toEqual([betaTaskId]);
    expect(betaGlobalTasks).not.toEqual(expect.arrayContaining([expect.objectContaining({ _id: taskId })]));
    const betaLocalMeetingTasks = await asBeta.query(functions.tasks.listForMeetingByLocalId, {
      meetingLocalId: "99999999-9999-4999-8999-999999999999",
    });
    expect(betaLocalMeetingTasks.map((task: any) => task._id)).toEqual([betaTaskId]);
    await expect(
      asBeta.query(functions.tasks.listForMeetingByLocalId, {
        meetingLocalId: "66666666-6666-4666-8666-666666666666",
      }),
    ).rejects.toThrow("Meeting not found");

    const alphaTask = await t.run(async (ctx) => await ctx.db.get(taskId));
    expect(alphaTask?.status).toBe("open");
  });
});
