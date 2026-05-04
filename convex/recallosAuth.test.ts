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
  test("public RecallOS queries reject unauthenticated callers", async () => {
    const t = makeConvexTest();

    await expect(t.query(functions.search.brain, { query: "anything" })).rejects.toThrow("authenticated");
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
  });

  test("meeting creation rejects attendee IDs from another user", async () => {
    const t = makeConvexTest();
    const asAlpha = t.withIdentity(alphaIdentity);

    const betaPersonId = await t.run(async (ctx) => {
      return await ctx.db.insert("recallOSPeople", {
        userId: betaIdentity.tokenIdentifier,
        localId: "44444444-4444-4444-8444-444444444444",
        displayName: "Beta Person",
      });
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
    await expect(asBeta.mutation(functions.tasks.move, { taskId, status: "done" })).rejects.toThrow("Task not found");
    const movedByLocalId = await asBeta.mutation(functions.tasks.moveByLocalIds, {
      localIds: ["77777777-7777-4777-8777-777777777777"],
      status: "done",
    });
    expect(movedByLocalId).toEqual([]);

    const alphaTask = await t.run(async (ctx) => await ctx.db.get(taskId));
    expect(alphaTask?.status).toBe("open");
  });
});
