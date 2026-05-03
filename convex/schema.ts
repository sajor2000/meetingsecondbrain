import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

const calendarSourceType = v.union(
  v.literal("eventkit"),
  v.literal("ics"),
  v.literal("google"),
  v.literal("manual"),
);

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

const documentFileType = v.union(
  v.literal("pdf"),
  v.literal("md"),
  v.literal("docx"),
  v.literal("txt"),
);

const vocabularyCategory = v.union(
  v.literal("organization"),
  v.literal("person"),
  v.literal("technical"),
  v.literal("program"),
);

export default defineSchema({
  meetings: defineTable({
    title: v.string(),
    startTime: v.number(),
    endTime: v.optional(v.number()),
    attendees: v.array(v.object({
      name: v.string(),
      email: v.optional(v.string()),
    })),

    // Calendar source
    calendarSource: v.optional(calendarSourceType),
    calendarSourceId: v.optional(v.string()),
    recurringId: v.optional(v.string()),

    // Organization
    templateId: v.optional(v.id("templates")),
    folderId: v.optional(v.id("folders")),

    // Notes
    rawNotes: v.string(),
    enhancedNotes: v.optional(v.string()),
    searchableText: v.string(),

    // Structured outputs
    summary: v.optional(v.string()),
    keyDecisions: v.array(v.string()),
    openQuestions: v.array(v.string()),

    // Audio
    audioFileId: v.optional(v.id("_storage")),
    audioRetentionUntil: v.optional(v.number()),
    audioDurationMs: v.optional(v.number()),

    // State
    enhancementStatus,
    transcriptionEngine,
    secondBrainStatus: v.optional(secondBrainStatus),
    secondBrainSyncedAt: v.optional(v.number()),

    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .searchIndex("search_notes", {
      searchField: "searchableText",
      filterFields: ["folderId"],
    })
    .index("by_start_time", ["startTime"])
    .index("by_recurring", ["recurringId"])
    .index("by_status", ["enhancementStatus"])
    .index("by_second_brain_status", ["secondBrainStatus"]),

  transcriptSegments: defineTable({
    meetingId: v.id("meetings"),
    startMs: v.number(),
    endMs: v.number(),
    text: v.string(),
    speaker: v.optional(v.string()),
    confidence: v.optional(v.number()),
  })
    .index("by_meeting", ["meetingId", "startMs"])
    .searchIndex("search_transcripts", { searchField: "text" }),

  tasks: defineTable({
    title: v.string(),
    description: v.optional(v.string()),
    dueDate: v.optional(v.number()),
    status: taskStatus,
    priority: taskPriority,
    sourceMeetingId: v.optional(v.id("meetings")),
    sourceTranscriptStartMs: v.optional(v.number()),
    sourceTranscriptEndMs: v.optional(v.number()),
    sourceEvidence: v.optional(v.string()),
    assignee: taskAssignee,
    assigneeName: v.optional(v.string()),
    completedAt: v.optional(v.number()),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_status", ["status"])
    .index("by_meeting", ["sourceMeetingId"])
    .index("by_due_date", ["dueDate"]),

  screenshots: defineTable({
    meetingId: v.id("meetings"),
    timestamp: v.number(),
    fileId: v.id("_storage"),
    inlineMarker: v.string(),
    noteCharacterOffset: v.optional(v.number()),
    ocrText: v.optional(v.string()),
    annotations: v.optional(v.string()),
    width: v.number(),
    height: v.number(),
  }).index("by_meeting", ["meetingId", "timestamp"]),

  documents: defineTable({
    title: v.string(),
    fileId: v.id("_storage"),
    fileType: documentFileType,
    extractedText: v.optional(v.string()),
    tags: v.array(v.string()),
    folderId: v.optional(v.id("folders")),
    secondBrainStatus,
    secondBrainSyncedAt: v.optional(v.number()),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_second_brain_status", ["secondBrainStatus"])
    .index("by_folder", ["folderId"]),

  templates: defineTable({
    name: v.string(),
    skeleton: v.string(),
    systemPrompt: v.string(),
    titleKeywords: v.array(v.string()),
    isCustom: v.boolean(),
    isDefault: v.boolean(),
  }),

  recipes: defineTable({
    name: v.string(),
    description: v.string(),
    prompt: v.string(),
    icon: v.optional(v.string()),
    isBuiltIn: v.boolean(),
  }),

  calendarEvents: defineTable({
    title: v.string(),
    startTime: v.number(),
    endTime: v.optional(v.number()),
    attendees: v.array(v.object({
      name: v.string(),
      email: v.optional(v.string()),
    })),
    location: v.optional(v.string()),
    description: v.optional(v.string()),
    meetingUrl: v.optional(v.string()),
    calendarSourceId: v.id("calendarSources"),
    externalId: v.string(),
    recurringId: v.optional(v.string()),
    recurrenceRule: v.optional(v.string()),
    dedupKey: v.string(),
    linkedMeetingId: v.optional(v.id("meetings")),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_start_time", ["startTime"])
    .index("by_source", ["calendarSourceId", "externalId"])
    .index("by_recurring", ["recurringId"])
    .index("by_linked_meeting", ["linkedMeetingId"])
    .index("by_dedup", ["dedupKey"]),

  calendarSources: defineTable({
    type: calendarSourceType,
    name: v.string(),
    config: v.object({
      eventKitCalendarIds: v.optional(v.array(v.string())),
      icsUrlSecretKey: v.optional(v.string()),
      googleCalendarIds: v.optional(v.array(v.string())),
      googleOAuthSecretKey: v.optional(v.string()),
    }),
    enabledCalendars: v.array(v.string()),
    enabled: v.boolean(),
    lastSyncedAt: v.optional(v.number()),
    lastError: v.optional(v.string()),
  }),

  folders: defineTable({
    name: v.string(),
    parentId: v.optional(v.id("folders")),
    color: v.optional(v.string()),
  }),

  vocabulary: defineTable({
    term: v.string(),
    aliases: v.array(v.string()),
    category: v.optional(vocabularyCategory),
  }).index("by_term", ["term"]),

  settings: defineTable({
    key: v.string(),
    value: v.any(),
  }).index("by_key", ["key"]),
});
