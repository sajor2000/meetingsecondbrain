import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

const byUser = { userId: v.string() };

export default defineSchema({
  meetings: defineTable({
    ...byUser,
    title: v.string(),
    startsAt: v.number(),
    endsAt: v.number(),
    status: v.union(
      v.literal("scheduled"),
      v.literal("inProgress"),
      v.literal("recording"),
      v.literal("enhancing"),
      v.literal("completed"),
    ),
    folderId: v.optional(v.id("folders")),
    calendarEventId: v.optional(v.id("calendarSources")),
    summary: v.optional(v.string()),
    rawNotes: v.optional(v.string()),
    enhancedNotes: v.optional(v.string()),
    attendeeIds: v.array(v.id("people")),
    topicIds: v.array(v.id("topics")),
    createdAt: v.number(),
    updatedAt: v.number(),
  }).index("by_user_start", ["userId", "startsAt"]),

  transcriptSegments: defineTable({
    ...byUser,
    meetingId: v.id("meetings"),
    speakerId: v.optional(v.id("people")),
    startTime: v.number(),
    endTime: v.number(),
    text: v.string(),
    confidence: v.number(),
  }).index("by_meeting_time", ["meetingId", "startTime"]),

  tasks: defineTable({
    ...byUser,
    title: v.string(),
    notes: v.optional(v.string()),
    status: v.union(v.literal("open"), v.literal("today"), v.literal("waiting"), v.literal("done")),
    priority: v.union(v.literal("low"), v.literal("medium"), v.literal("high")),
    ownerId: v.optional(v.id("people")),
    dueAt: v.optional(v.number()),
    completedAt: v.optional(v.number()),
    sourceMeetingId: v.optional(v.id("meetings")),
    sourceTimestamp: v.optional(v.number()),
    extractionConfidence: v.optional(v.number()),
    createdAt: v.number(),
    updatedAt: v.number(),
  }).index("by_user_status", ["userId", "status"]),

  screenshots: defineTable({
    ...byUser,
    meetingId: v.id("meetings"),
    capturedAt: v.number(),
    storageId: v.id("_storage"),
    caption: v.optional(v.string()),
  }).index("by_meeting", ["meetingId"]),

  documents: defineTable({
    ...byUser,
    meetingId: v.optional(v.id("meetings")),
    title: v.string(),
    storageId: v.optional(v.id("_storage")),
    content: v.optional(v.string()),
    createdAt: v.number(),
  }).index("by_user", ["userId"]),

  templates: defineTable({
    ...byUser,
    name: v.string(),
    body: v.string(),
    createdAt: v.number(),
    updatedAt: v.number(),
  }).index("by_user", ["userId"]),

  recipes: defineTable({
    ...byUser,
    name: v.string(),
    prompt: v.string(),
    isEnabled: v.boolean(),
    createdAt: v.number(),
    updatedAt: v.number(),
  }).index("by_user", ["userId"]),

  calendarSources: defineTable({
    ...byUser,
    provider: v.union(v.literal("eventKit"), v.literal("ics"), v.literal("google"), v.literal("office365")),
    externalId: v.string(),
    displayName: v.string(),
    isEnabled: v.boolean(),
    lastSyncedAt: v.optional(v.number()),
  }).index("by_user", ["userId"]),

  folders: defineTable({
    ...byUser,
    name: v.string(),
    sortOrder: v.number(),
  }).index("by_user", ["userId"]),

  vocabulary: defineTable({
    ...byUser,
    phrase: v.string(),
    pronunciationHint: v.optional(v.string()),
    notes: v.optional(v.string()),
  }).index("by_user_phrase", ["userId", "phrase"]),

  settings: defineTable({
    ...byUser,
    key: v.string(),
    value: v.any(),
    updatedAt: v.number(),
  }).index("by_user_key", ["userId", "key"]),

  people: defineTable({
    ...byUser,
    displayName: v.string(),
    email: v.optional(v.string()),
    role: v.optional(v.string()),
  }).index("by_user_name", ["userId", "displayName"]),

  topics: defineTable({
    ...byUser,
    name: v.string(),
    description: v.optional(v.string()),
  }).index("by_user_name", ["userId", "name"]),

  decisions: defineTable({
    ...byUser,
    meetingId: v.id("meetings"),
    title: v.string(),
    detail: v.string(),
    sourceTimestamp: v.optional(v.number()),
    createdAt: v.number(),
  }).index("by_meeting", ["meetingId"]),
});
