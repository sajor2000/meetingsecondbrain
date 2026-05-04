import { mutation, query } from "./_generated/server";
import { Doc, Id } from "./_generated/dataModel";
import { v } from "convex/values";
import { requireUserId } from "./auth";
import { requireUUIDLocalId } from "./localIds";

const meetingStatus = v.union(
  v.literal("scheduled"),
  v.literal("inProgress"),
  v.literal("recording"),
  v.literal("enhancing"),
  v.literal("completed"),
  v.literal("failed"),
);

type OwnedRecallOSTable = "recallOSPeople" | "recallOSTopics" | "recallOSFolders";

async function requireOwnedRecord<T extends OwnedRecallOSTable>(
  ctx: any,
  id: Id<T>,
  userId: string,
  label: string,
) {
  const record = await ctx.db.get(id);
  if (record === null || record.userId !== userId) {
    throw new Error(`${label} not found.`);
  }
}

async function validateMeetingLinks(
  ctx: any,
  userId: string,
  attendeeIds: Id<"recallOSPeople">[],
  topicIds: Id<"recallOSTopics">[],
  folderId?: Id<"recallOSFolders">,
) {
  if (folderId !== undefined) {
    await requireOwnedRecord(ctx, folderId, userId, "Folder");
  }

  for (const attendeeId of attendeeIds) {
    await requireOwnedRecord(ctx, attendeeId, userId, "Attendee");
  }

  for (const topicId of topicIds) {
    await requireOwnedRecord(ctx, topicId, userId, "Topic");
  }
}

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
    status: v.optional(meetingStatus),
    folderId: v.optional(v.id("recallOSFolders")),
    calendarEventId: v.optional(v.string()),
    calendarEventLocalId: v.optional(v.string()),
    summary: v.optional(v.string()),
    rawNotes: v.optional(v.string()),
    enhancedNotes: v.optional(v.string()),
    noteBlocks: v.optional(v.any()),
    attendeeIds: v.optional(v.array(v.id("recallOSPeople"))),
    topicIds: v.optional(v.array(v.id("recallOSTopics"))),
  },
  handler: async (ctx, args) => {
    const userId = await requireUserId(ctx);
    requireUUIDLocalId(args.localId);
    if (args.calendarEventLocalId !== undefined) {
      requireUUIDLocalId(args.calendarEventLocalId);
    }
    const attendeeIds = args.attendeeIds ?? [];
    const topicIds = args.topicIds ?? [];
    await validateMeetingLinks(ctx, userId, attendeeIds, topicIds, args.folderId);

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
      status: args.status ?? "scheduled",
      folderId: args.folderId,
      calendarEventId: args.calendarEventId,
      calendarEventLocalId: args.calendarEventLocalId,
      summary: args.summary,
      rawNotes: args.rawNotes,
      enhancedNotes: args.enhancedNotes,
      noteBlocks: args.noteBlocks,
      attendeeIds,
      topicIds,
      createdAt: now,
      updatedAt: now,
    });
  },
});

export const update = mutation({
  args: {
    meetingId: v.id("recallOSMeetings"),
    title: v.optional(v.string()),
    startsAt: v.optional(v.number()),
    endsAt: v.optional(v.number()),
    status: v.optional(meetingStatus),
    folderId: v.optional(v.id("recallOSFolders")),
    calendarEventId: v.optional(v.string()),
    calendarEventLocalId: v.optional(v.string()),
    summary: v.optional(v.string()),
    rawNotes: v.optional(v.string()),
    enhancedNotes: v.optional(v.string()),
    noteBlocks: v.optional(v.any()),
    attendeeIds: v.optional(v.array(v.id("recallOSPeople"))),
    topicIds: v.optional(v.array(v.id("recallOSTopics"))),
  },
  handler: async (ctx, args) => {
    const userId = await requireUserId(ctx);
    const meeting = await ctx.db.get(args.meetingId);
    if (meeting === null || meeting.userId !== userId) {
      throw new Error("Meeting not found.");
    }

    await validateMeetingLinks(
      ctx,
      userId,
      args.attendeeIds ?? [],
      args.topicIds ?? [],
      args.folderId,
    );

    const patch: Partial<Doc<"recallOSMeetings">> = {
      updatedAt: Date.now(),
    };
    if (args.title !== undefined) patch.title = args.title;
    if (args.startsAt !== undefined) patch.startsAt = args.startsAt;
    if (args.endsAt !== undefined) patch.endsAt = args.endsAt;
    if (args.status !== undefined) patch.status = args.status;
    if (args.folderId !== undefined) patch.folderId = args.folderId;
    if (args.calendarEventId !== undefined) patch.calendarEventId = args.calendarEventId;
    if (args.calendarEventLocalId !== undefined) {
      requireUUIDLocalId(args.calendarEventLocalId);
      patch.calendarEventLocalId = args.calendarEventLocalId;
    }
    if (args.summary !== undefined) patch.summary = args.summary;
    if (args.rawNotes !== undefined) patch.rawNotes = args.rawNotes;
    if (args.enhancedNotes !== undefined) patch.enhancedNotes = args.enhancedNotes;
    if (args.noteBlocks !== undefined) patch.noteBlocks = args.noteBlocks;
    if (args.attendeeIds !== undefined) patch.attendeeIds = args.attendeeIds;
    if (args.topicIds !== undefined) patch.topicIds = args.topicIds;

    await ctx.db.patch(args.meetingId, patch);
    return args.meetingId;
  },
});

export const updateNotes = mutation({
  args: {
    meetingId: v.id("recallOSMeetings"),
    status: v.optional(meetingStatus),
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
