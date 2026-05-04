import { query } from "./_generated/server";
import { v } from "convex/values";
import { requireUserId } from "./auth";

const MAX_SEARCH_RESULTS = 50;

function normalizedQuery(queryText: string) {
  return queryText.trim();
}

function clampLimit(limit: number | undefined, max = MAX_SEARCH_RESULTS) {
  if (limit === undefined) {
    return 20;
  }

  return Math.max(1, Math.min(Math.floor(limit), max));
}

export const brain = query({
  args: { query: v.string() },
  handler: async (ctx, args) => {
    const userId = await requireUserId(ctx);
    const normalized = args.query.toLowerCase();
    const meetings = await ctx.db
      .query("recallOSMeetings")
      .withIndex("by_user_start", (q) => q.eq("userId", userId))
      .collect();
    const tasks = await ctx.db
      .query("recallOSTasks")
      .withIndex("by_user_status", (q) => q.eq("userId", userId))
      .collect();

    const meetingResults = meetings
      .filter((meeting) => {
        const summary = meeting.summary ?? "";
        return meeting.title.toLowerCase().includes(normalized) || summary.toLowerCase().includes(normalized);
      })
      .map((meeting) => ({
        id: meeting.localId,
        title: meeting.title,
        source: "Meeting",
        snippet: meeting.summary ?? "No summary yet.",
        sourceMeetingID: meeting.localId,
      }));

    const taskResults = tasks
      .filter((task) => {
        const notes = task.notes ?? "";
        return task.title.toLowerCase().includes(normalized) || notes.toLowerCase().includes(normalized);
      })
      .map((task) => ({
        id: task.localId,
        title: task.title,
        source: "Task",
        snippet: task.notes ?? "Meeting task",
        sourceMeetingID: task.sourceMeetingLocalId,
      }));

    return [...meetingResults, ...taskResults].slice(0, 12);
  },
});

export const meetings = query({
  args: {
    query: v.string(),
    folderId: v.optional(v.id("folders")),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const queryText = normalizedQuery(args.query);
    if (queryText.length === 0) {
      return [];
    }

    const search = ctx.db
      .query("meetings")
      .withSearchIndex("search_notes", (q) => {
        const builder = q.search("searchableText", queryText);
        return args.folderId === undefined ? builder : builder.eq("folderId", args.folderId);
      });

    return await search.take(clampLimit(args.limit));
  },
});

export const transcriptSegments = query({
  args: {
    query: v.string(),
    meetingId: v.optional(v.id("meetings")),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const queryText = normalizedQuery(args.query);
    if (queryText.length === 0) {
      return [];
    }

    const search = ctx.db
      .query("transcriptSegments")
      .withSearchIndex("search_transcripts", (q) => {
        const builder = q.search("text", queryText);
        return args.meetingId === undefined ? builder : builder.eq("meetingId", args.meetingId);
      });

    return await search.take(clampLimit(args.limit));
  },
});
