import { query } from "./_generated/server";
import { v } from "convex/values";
import { requireUserId } from "./auth";

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
