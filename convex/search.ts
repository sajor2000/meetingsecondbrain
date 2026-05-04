import { query } from "./_generated/server";
import { v } from "convex/values";

export const brain = query({
  args: { userId: v.string(), query: v.string() },
  handler: async (ctx, args) => {
    const normalized = args.query.toLowerCase();
    const meetings = await ctx.db
      .query("meetings")
      .withIndex("by_user_start", (q) => q.eq("userId", args.userId))
      .collect();
    const tasks = await ctx.db
      .query("tasks")
      .withIndex("by_user_status", (q) => q.eq("userId", args.userId))
      .collect();

    return {
      meetings: meetings.filter((meeting) => meeting.title.toLowerCase().includes(normalized)),
      tasks: tasks.filter((task) => task.title.toLowerCase().includes(normalized)),
    };
  },
});
