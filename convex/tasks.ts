import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const listOpen = query({
  args: { userId: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("tasks")
      .withIndex("by_user_status", (q) => q.eq("userId", args.userId).eq("status", "open"))
      .collect();
  },
});

export const createFromMeeting = mutation({
  args: {
    userId: v.string(),
    title: v.string(),
    sourceMeetingId: v.id("meetings"),
    sourceTimestamp: v.optional(v.number()),
    extractionConfidence: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    return await ctx.db.insert("tasks", {
      userId: args.userId,
      title: args.title,
      status: "open",
      priority: "medium",
      sourceMeetingId: args.sourceMeetingId,
      sourceTimestamp: args.sourceTimestamp,
      extractionConfidence: args.extractionConfidence,
      createdAt: now,
      updatedAt: now,
    });
  },
});

export const move = mutation({
  args: {
    taskId: v.id("tasks"),
    status: v.union(v.literal("open"), v.literal("today"), v.literal("waiting"), v.literal("done")),
  },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.taskId, {
      status: args.status,
      completedAt: args.status === "done" ? Date.now() : undefined,
      updatedAt: Date.now(),
    });
    return args.taskId;
  },
});
