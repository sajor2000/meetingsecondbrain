import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const list = query({
  args: { userId: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("meetings")
      .withIndex("by_user_start", (q) => q.eq("userId", args.userId))
      .order("desc")
      .collect();
  },
});

export const create = mutation({
  args: {
    userId: v.string(),
    title: v.string(),
    startsAt: v.number(),
    endsAt: v.number(),
    attendeeIds: v.array(v.id("people")),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    return await ctx.db.insert("meetings", {
      userId: args.userId,
      title: args.title,
      startsAt: args.startsAt,
      endsAt: args.endsAt,
      attendeeIds: args.attendeeIds,
      topicIds: [],
      status: "scheduled",
      createdAt: now,
      updatedAt: now,
    });
  },
});

export const updateNotes = mutation({
  args: {
    meetingId: v.id("meetings"),
    rawNotes: v.optional(v.string()),
    enhancedNotes: v.optional(v.string()),
    summary: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const { meetingId, ...patch } = args;
    await ctx.db.patch(meetingId, { ...patch, updatedAt: Date.now() });
    return meetingId;
  },
});
