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

const attendee = v.object({
  name: v.string(),
  email: v.optional(v.string()),
});

const enhancementStatus = v.union(
  v.literal("pending"),
  v.literal("processing"),
  v.literal("complete"),
  v.literal("failed"),
);

const transcriptionEngine = v.union(
  v.literal("parakeet"),
  v.literal("whisperkit"),
  v.literal("deepgram"),
  v.literal("apple"),
);

const secondBrainStatus = v.union(
  v.literal("pending"),
  v.literal("synced"),
  v.literal("failed"),
);

const calendarSourceType = v.union(
  v.literal("eventkit"),
  v.literal("ics"),
  v.literal("google"),
  v.literal("manual"),
);

const MAX_MEETINGS = 100;

type OwnedRecallOSTable = "recallOSPeople" | "recallOSTopics" | "recallOSFolders";

function clampLimit(limit: number | undefined, max = MAX_MEETINGS) {
  if (limit === undefined) {
    return max;
  }

  return Math.max(1, Math.min(Math.floor(limit), max));
}

function buildSearchableText(meeting: {
  title: string;
  attendees?: Array<{ name: string; email?: string }>;
  rawNotes?: string;
  enhancedNotes?: string;
  summary?: string;
  keyDecisions?: string[];
  openQuestions?: string[];
}) {
  return [
    meeting.title,
    ...(meeting.attendees ?? []).flatMap((person) => [person.name, person.email ?? ""]),
    meeting.rawNotes ?? "",
    meeting.enhancedNotes ?? "",
    meeting.summary ?? "",
    ...(meeting.keyDecisions ?? []),
    ...(meeting.openQuestions ?? []),
  ]
    .filter((part) => part.trim().length > 0)
    .join("\n");
}

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

export const get = query({
  args: {
    meetingId: v.id("meetings"),
  },
  handler: async (ctx, args) => {
    return await ctx.db.get(args.meetingId);
  },
});

export const listByStartTime = query({
  args: {
    startTime: v.number(),
    endTime: v.number(),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("meetings")
      .withIndex("by_start_time", (q) =>
        q.gte("startTime", args.startTime).lt("startTime", args.endTime),
      )
      .order("desc")
      .take(clampLimit(args.limit));
  },
});

export const createManual = mutation({
  args: {
    title: v.string(),
    startTime: v.number(),
    endTime: v.optional(v.number()),
    attendees: v.optional(v.array(attendee)),
    rawNotes: v.optional(v.string()),
    folderId: v.optional(v.id("folders")),
    templateId: v.optional(v.id("templates")),
    transcriptionEngine: v.optional(transcriptionEngine),
  },
  handler: async (ctx, args): Promise<Id<"meetings">> => {
    const now = Date.now();
    const attendees = args.attendees ?? [];
    const rawNotes = args.rawNotes ?? "";

    return await ctx.db.insert("meetings", {
      title: args.title,
      startTime: args.startTime,
      endTime: args.endTime,
      attendees,
      calendarSource: "manual",
      templateId: args.templateId,
      folderId: args.folderId,
      rawNotes,
      searchableText: buildSearchableText({
        title: args.title,
        attendees,
        rawNotes,
        keyDecisions: [],
        openQuestions: [],
      }),
      keyDecisions: [],
      openQuestions: [],
      enhancementStatus: "pending",
      transcriptionEngine: args.transcriptionEngine ?? "parakeet",
      secondBrainStatus: "pending",
      createdAt: now,
      updatedAt: now,
    });
  },
});

export const updateState = mutation({
  args: {
    meetingId: v.id("meetings"),
    enhancementStatus: v.optional(enhancementStatus),
    transcriptionEngine: v.optional(transcriptionEngine),
    secondBrainStatus: v.optional(secondBrainStatus),
    secondBrainSyncedAt: v.optional(v.number()),
    calendarSource: v.optional(calendarSourceType),
    calendarSourceId: v.optional(v.string()),
    recurringId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const meeting = await ctx.db.get(args.meetingId);
    if (meeting === null) {
      throw new Error("Meeting not found");
    }

    await ctx.db.patch(args.meetingId, {
      ...(args.enhancementStatus !== undefined
        ? { enhancementStatus: args.enhancementStatus }
        : {}),
      ...(args.transcriptionEngine !== undefined
        ? { transcriptionEngine: args.transcriptionEngine }
        : {}),
      ...(args.secondBrainStatus !== undefined
        ? { secondBrainStatus: args.secondBrainStatus }
        : {}),
      ...(args.secondBrainSyncedAt !== undefined
        ? { secondBrainSyncedAt: args.secondBrainSyncedAt }
        : {}),
      ...(args.calendarSource !== undefined ? { calendarSource: args.calendarSource } : {}),
      ...(args.calendarSourceId !== undefined ? { calendarSourceId: args.calendarSourceId } : {}),
      ...(args.recurringId !== undefined ? { recurringId: args.recurringId } : {}),
      updatedAt: Date.now(),
    });

    return await ctx.db.get(args.meetingId);
  },
});
