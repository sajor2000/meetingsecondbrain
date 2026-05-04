import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { requireUserId } from "./auth";
import { requireUUIDLocalId } from "./localIds";

export const list = query({
  args: {},
  handler: async (ctx, args) => {
    const userId = await requireUserId(ctx);
    return await ctx.db
      .query("recallOSMeetings")
      .withIndex("by_user_start", (q) => q.eq("userId", userId))
      .order("desc")
      .collect();
  },
});

export const create = mutation({
  args: {
    localId: v.string(),
    title: v.string(),
    startsAt: v.number(),
    endsAt: v.number(),
    attendeeIds: v.optional(v.array(v.id("recallOSPeople"))),
  },
  handler: async (ctx, args) => {
    const userId = await requireUserId(ctx);
    requireUUIDLocalId(args.localId);
    const attendeeIds = args.attendeeIds ?? [];
    for (const attendeeId of attendeeIds) {
      const attendee = await ctx.db.get(attendeeId);
      if (attendee === null || attendee.userId !== userId) {
        throw new Error("Attendee not found.");
      }
    }

    const existingMeeting = await ctx.db
      .query("recallOSMeetings")
      .withIndex("by_user_local_id", (q) => q.eq("userId", userId).eq("localId", args.localId))
      .unique();
    if (existingMeeting !== null) {
      return existingMeeting._id;
    }

    const now = Date.now();
    return await ctx.db.insert("recallOSMeetings", {
      userId,
      localId: args.localId,
      title: args.title,
      startsAt: args.startsAt,
      endsAt: args.endsAt,
      attendeeIds,
      topicIds: [],
      status: "scheduled",
      createdAt: now,
      updatedAt: now,
    });
  },
});

export const updateNotes = mutation({
  args: {
    meetingId: v.id("recallOSMeetings"),
    status: v.optional(v.union(
      v.literal("scheduled"),
      v.literal("inProgress"),
      v.literal("recording"),
      v.literal("enhancing"),
      v.literal("completed"),
      v.literal("failed"),
    )),
    rawNotes: v.optional(v.string()),
    enhancedNotes: v.optional(v.string()),
    noteBlocks: v.optional(v.any()),
    summary: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const userId = await requireUserId(ctx);
    const meeting = await ctx.db.get(args.meetingId);
    if (meeting === null || meeting.userId !== userId) {
      throw new Error("Meeting not found.");
    }

    const { meetingId, ...patch } = args;
    await ctx.db.patch(meetingId, { ...patch, updatedAt: Date.now() });
    return meetingId;
  },
});
