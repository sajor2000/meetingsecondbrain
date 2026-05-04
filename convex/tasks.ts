import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { requireUserId } from "./auth";

export const listOpen = query({
  args: {},
  handler: async (ctx, args) => {
    const userId = await requireUserId(ctx);
    return await ctx.db
      .query("recallOSTasks")
      .withIndex("by_user_status", (q) => q.eq("userId", userId).eq("status", "open"))
      .collect();
  },
});

export const listForMeeting = query({
  args: { meetingId: v.optional(v.id("recallOSMeetings")) },
  handler: async (ctx, args) => {
    const userId = await requireUserId(ctx);

    if (args.meetingId === undefined) {
      return await ctx.db
        .query("recallOSTasks")
        .withIndex("by_user_status", (q) => q.eq("userId", userId))
        .collect();
    }

    const meeting = await ctx.db.get(args.meetingId);
    if (meeting === null || meeting.userId !== userId) {
      throw new Error("Meeting not found.");
    }

    return await ctx.db
      .query("recallOSTasks")
      .withIndex("by_user_meeting", (q) => q.eq("userId", userId).eq("sourceMeetingId", args.meetingId))
      .collect();
  },
});

export const createFromMeeting = mutation({
  args: {
    localId: v.string(),
    title: v.string(),
    sourceMeetingId: v.id("recallOSMeetings"),
    sourceTimestamp: v.optional(v.number()),
    extractionConfidence: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const userId = await requireUserId(ctx);
    const meeting = await ctx.db.get(args.sourceMeetingId);
    if (meeting === null || meeting.userId !== userId) {
      throw new Error("Meeting not found.");
    }

    const now = Date.now();
    return await ctx.db.insert("recallOSTasks", {
      userId,
      localId: args.localId,
      title: args.title,
      status: "open",
      priority: "medium",
      sourceMeetingId: args.sourceMeetingId,
      sourceMeetingLocalId: meeting.localId,
      sourceTimestamp: args.sourceTimestamp,
      extractionConfidence: args.extractionConfidence,
      createdAt: now,
      updatedAt: now,
    });
  },
});

export const move = mutation({
  args: {
    taskId: v.id("recallOSTasks"),
    status: v.union(v.literal("open"), v.literal("today"), v.literal("waiting"), v.literal("done")),
  },
  handler: async (ctx, args) => {
    const userId = await requireUserId(ctx);
    const task = await ctx.db.get(args.taskId);
    if (task === null || task.userId !== userId) {
      throw new Error("Task not found.");
    }

    await ctx.db.patch(args.taskId, {
      status: args.status,
      completedAt: args.status === "done" ? Date.now() : undefined,
      updatedAt: Date.now(),
    });
    return args.taskId;
  },
});

export const moveByLocalIds = mutation({
  args: {
    localIds: v.array(v.string()),
    status: v.union(v.literal("open"), v.literal("today"), v.literal("waiting"), v.literal("done")),
  },
  handler: async (ctx, args) => {
    const userId = await requireUserId(ctx);
    const now = Date.now();
    const movedTaskIds = [];

    for (const localId of args.localIds) {
      const task = await ctx.db
        .query("recallOSTasks")
        .withIndex("by_user_local_id", (q) => q.eq("userId", userId).eq("localId", localId))
        .unique();

      if (task === null) {
        continue;
      }

      await ctx.db.patch(task._id, {
        status: args.status,
        completedAt: args.status === "done" ? now : undefined,
        updatedAt: now,
      });
      movedTaskIds.push(task._id);
    }

    return movedTaskIds;
  },
});
