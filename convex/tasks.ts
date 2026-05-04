import { mutation, query } from "./_generated/server";
import type { Id } from "./_generated/dataModel";
import { v } from "convex/values";
import { requireUserId } from "./auth";
import { requireUUIDLocalId } from "./localIds";

const taskStatus = v.union(
  v.literal("todo"),
  v.literal("doing"),
  v.literal("done"),
);

const taskPriority = v.union(
  v.literal("low"),
  v.literal("medium"),
  v.literal("high"),
);

const taskAssignee = v.union(
  v.literal("user"),
  v.literal("others"),
);

const MAX_TASKS = 200;

function clampLimit(limit: number | undefined, max = MAX_TASKS) {
  if (limit === undefined) {
    return max;
  }

  return Math.max(1, Math.min(Math.floor(limit), max));
}

function completionTimestamp(status: "todo" | "doing" | "done", existing?: number) {
  if (status === "done") {
    return existing ?? Date.now();
  }

  return undefined;
}

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

export const listForMeetingByLocalId = query({
  args: { meetingLocalId: v.string() },
  handler: async (ctx, args) => {
    const userId = await requireUserId(ctx);
    requireUUIDLocalId(args.meetingLocalId);

    const meeting = await ctx.db
      .query("recallOSMeetings")
      .withIndex("by_user_local_id", (q) => q.eq("userId", userId).eq("localId", args.meetingLocalId))
      .unique();
    if (meeting === null) {
      throw new Error("Meeting not found.");
    }

    return await ctx.db
      .query("recallOSTasks")
      .withIndex("by_user_meeting_local_id", (q) =>
        q.eq("userId", userId).eq("sourceMeetingLocalId", args.meetingLocalId),
      )
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
    requireUUIDLocalId(args.localId);
    const existingTask = await ctx.db
      .query("recallOSTasks")
      .withIndex("by_user_local_id", (q) => q.eq("userId", userId).eq("localId", args.localId))
      .unique();
    if (existingTask !== null) {
      return existingTask._id;
    }

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
      requireUUIDLocalId(localId);
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

export const list = query({
  args: {
    status: v.optional(taskStatus),
    assignee: v.optional(taskAssignee),
    sourceMeetingId: v.optional(v.id("meetings")),
    dueDateFrom: v.optional(v.number()),
    dueDateTo: v.optional(v.number()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const limit = clampLimit(args.limit);
    const tasks =
      args.status !== undefined
        ? await ctx.db
            .query("tasks")
            .withIndex("by_status", (q) => q.eq("status", args.status!))
            .take(MAX_TASKS)
        : args.sourceMeetingId !== undefined
          ? await ctx.db
              .query("tasks")
              .withIndex("by_meeting", (q) => q.eq("sourceMeetingId", args.sourceMeetingId!))
              .take(MAX_TASKS)
          : args.dueDateFrom !== undefined && args.dueDateTo !== undefined
            ? await ctx.db
                .query("tasks")
                .withIndex("by_due_date", (q) =>
                  q.gte("dueDate", args.dueDateFrom!).lte("dueDate", args.dueDateTo!),
                )
                .take(MAX_TASKS)
          : args.dueDateFrom !== undefined
            ? await ctx.db
                .query("tasks")
                .withIndex("by_due_date", (q) => q.gte("dueDate", args.dueDateFrom!))
                .take(MAX_TASKS)
          : args.dueDateTo !== undefined
            ? await ctx.db
                .query("tasks")
                .withIndex("by_due_date", (q) => q.lte("dueDate", args.dueDateTo!))
                .take(MAX_TASKS)
          : await ctx.db.query("tasks").withIndex("by_due_date").take(MAX_TASKS);

    return tasks
      .filter((task) => args.assignee === undefined || task.assignee === args.assignee)
      .filter(
        (task) =>
          args.sourceMeetingId === undefined || task.sourceMeetingId === args.sourceMeetingId,
      )
      .filter((task) => args.dueDateFrom === undefined || (task.dueDate ?? 0) >= args.dueDateFrom!)
      .filter((task) => args.dueDateTo === undefined || (task.dueDate ?? Infinity) <= args.dueDateTo!)
      .sort((a, b) => {
        const aDue = a.dueDate ?? Number.MAX_SAFE_INTEGER;
        const bDue = b.dueDate ?? Number.MAX_SAFE_INTEGER;
        return aDue - bDue || b.updatedAt - a.updatedAt;
      })
      .slice(0, limit);
  },
});

export const create = mutation({
  args: {
    title: v.string(),
    description: v.optional(v.string()),
    dueDate: v.optional(v.number()),
    status: v.optional(taskStatus),
    priority: v.optional(taskPriority),
    sourceMeetingId: v.optional(v.id("meetings")),
    sourceTranscriptStartMs: v.optional(v.number()),
    sourceTranscriptEndMs: v.optional(v.number()),
    sourceEvidence: v.optional(v.string()),
    assignee: v.optional(taskAssignee),
    assigneeName: v.optional(v.string()),
  },
  handler: async (ctx, args): Promise<Id<"tasks">> => {
    const now = Date.now();
    const status = args.status ?? "todo";

    return await ctx.db.insert("tasks", {
      title: args.title,
      description: args.description,
      dueDate: args.dueDate,
      status,
      priority: args.priority ?? "medium",
      sourceMeetingId: args.sourceMeetingId,
      sourceTranscriptStartMs: args.sourceTranscriptStartMs,
      sourceTranscriptEndMs: args.sourceTranscriptEndMs,
      sourceEvidence: args.sourceEvidence,
      assignee: args.assignee ?? "user",
      assigneeName: args.assigneeName,
      completedAt: completionTimestamp(status),
      createdAt: now,
      updatedAt: now,
    });
  },
});

export const updateMetadata = mutation({
  args: {
    taskId: v.id("tasks"),
    title: v.optional(v.string()),
    description: v.optional(v.string()),
    dueDate: v.optional(v.number()),
    priority: v.optional(taskPriority),
    sourceEvidence: v.optional(v.string()),
    assignee: v.optional(taskAssignee),
    assigneeName: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const task = await ctx.db.get(args.taskId);
    if (task === null) {
      throw new Error("Task not found");
    }

    await ctx.db.patch(args.taskId, {
      ...(args.title !== undefined ? { title: args.title } : {}),
      ...(args.description !== undefined ? { description: args.description } : {}),
      ...(args.dueDate !== undefined ? { dueDate: args.dueDate } : {}),
      ...(args.priority !== undefined ? { priority: args.priority } : {}),
      ...(args.sourceEvidence !== undefined ? { sourceEvidence: args.sourceEvidence } : {}),
      ...(args.assignee !== undefined ? { assignee: args.assignee } : {}),
      ...(args.assigneeName !== undefined ? { assigneeName: args.assigneeName } : {}),
      updatedAt: Date.now(),
    });

    return await ctx.db.get(args.taskId);
  },
});

export const updateStatus = mutation({
  args: {
    taskId: v.id("tasks"),
    status: taskStatus,
  },
  handler: async (ctx, args) => {
    const task = await ctx.db.get(args.taskId);
    if (task === null) {
      throw new Error("Task not found");
    }

    await ctx.db.patch(args.taskId, {
      status: args.status,
      completedAt: completionTimestamp(args.status, task.completedAt),
      updatedAt: Date.now(),
    });

    return await ctx.db.get(args.taskId);
  },
});
