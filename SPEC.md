# SPEC: Personal Meeting, Task & Second Brain App

**A Granola alternative with integrated task management, screenshot capture, and a Cognee-powered knowledge graph.**

---

## 0. How to Read This Spec

This is a spec-driven development document. The agent (Claude Code or Codex) should:

1. Read this entire spec before writing any code
2. Create `SPEC.md` in repo root with this exact content
3. Confirm each phase boundary with the user before proceeding
4. Show schemas and prompts as artifacts before implementing
5. Maintain `DECISIONS.md` log of any deviations from this spec
6. Run all tests after each phase before moving to the next

**Do not skip phases. Do not write code until phase 1's schema is approved.**

---

## 1. Project Brief

Build a native macOS + iOS application that replicates Granola's meeting workflow with four additions Granola lacks:

1. **Integrated task management** with assignee detection
2. **Inline screenshots** in meeting notes with OCR
3. **Audio retention** with transcript-synced playback
4. **Cognee-powered second brain** — knowledge graph across meetings + ingested documents

### User profile
- Single user, multi-device
- Physician informaticist, runs 6-8 meetings/day
- Meetings are research, AI governance, administrative (RICCC, CLIF Consortium, AI CoE, IRB strategy, grant calls, vendor POCs, manuscript reviews)
- No clinical/PHI content in this app
- Strong aversion to em dashes and semicolons in writing
- Expects fluency in clinical informatics, statistics, ML

### Hardware
- **Primary**: M4 MacBook (mobile, 18 GB RAM)
- **Always-on host**: M4 Max Mac Studio, 64 GB RAM (runs Cognee + Ollama)
- **Mobile companion**: iPhone (model TBD, assume non-Pro for lightweight transcription)

### Performance targets (non-negotiable)
- Meeting detection notification: <200ms after trigger
- Recording start latency: <500ms after click
- Live transcript lag: <1s on M4
- Post-meeting enhancement: <30s for 30-min meeting
- App cold launch: <1s
- Switch between meetings: instant (Convex reactive)
- Search results: <100ms (Convex full-text)
- Second brain query: <5s (Cognee on Mac Studio via Tailscale)

---

## 2. Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  M4 MacBook (primary)                                             │
│  - SwiftUI + AppKit                                               │
│  - ScreenCaptureKit (system audio) + AVFoundation (mic)          │
│  - FluidAudio Parakeet (Neural Engine transcription)             │
│  - EventKit + ICS parser + Google Calendar API                   │
│  - Vision framework (screenshot OCR)                              │
└────────┬──────────────────────────────────┬──────────────────────┘
         │                                  │
         │ Reactive sync                    │ Knowledge graph (Tailscale)
         ▼                                  ▼
┌────────────────────────────┐  ┌──────────────────────────────────┐
│  Convex (cloud, free tier)  │  │  M4 Max Mac Studio 64GB          │
│  - TS schema + reactive     │  │  (always-on, headless OK)         │
│  - File storage             │  │                                   │
│  - Server-side actions      │  │  Docker:                          │
│    (LLM enhancement)         │  │  - Cognee (FastAPI wrapper)       │
│  - Cron jobs (ICS sync)     │  │  - SQLite + LanceDB + Kuzu       │
│  - Full-text search         │  │  - Caddy (HTTPS via Tailscale)   │
│                              │  │                                   │
│  $0/month                    │  │  Native:                          │
│                              │  │  - Ollama (Gemma 4 26B MoE)       │
│                              │  │  - Tailscale (remote access)      │
│                              │  │                                   │
│                              │  │  $0/month (electricity ~$2-3)     │
└────────────────────────────┘  └──────────────────────────────────┘
         │                                  │
         │                                  │
         ▼                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│  iOS App (companion)                                              │
│  - SwiftUI                                                        │
│  - WhisperKit base.en (lightweight local transcription)          │
│  - AVFoundation (mic only)                                        │
│  - Read meetings, manage tasks, voice memo capture               │
│  - Tailscale for second brain access                             │
└──────────────────────────────────────────────────────────────────┘

External APIs (single key via OpenRouter):
┌──────────────────────────────────────────────────────────────────┐
│  OpenRouter (https://openrouter.ai/api/v1)                        │
│  - openai/gpt-5-mini       — meeting enhancement (default)        │
│  - openai/gpt-5            — heavy reasoning fallback             │
│  - anthropic/claude-sonnet-4.5  — quality fallback                │
│  - google/gemma-4-31b-it   — second brain queries                 │
│  - google/gemma-4-26b-a4b-it  — voice memo extraction             │
│                                                                    │
│  ~$5-6/month at user's volume                                     │
└──────────────────────────────────────────────────────────────────┘

Optional paid:
- Deepgram Nova-3 ($200 free credits, then $0.0077/min) — escape hatch
```

### Cost summary

| Component | Cost |
|---|---|
| Convex | $0 (free tier) |
| Mac Studio (Cognee + Ollama) | $0 (sunk cost + ~$2-3/mo electricity) |
| Tailscale | $0 (personal free tier) |
| Local Parakeet transcription | $0 |
| OpenRouter (all LLM ops) | ~$5-6/month |
| Apple Developer Program | $99/year (recommended for stable signing) |
| **Total** | **~$5-6/month** vs Granola at $18/month |

---

## 3. Stack Decisions (locked)

| Layer | Choice | Rationale |
|---|---|---|
| **App backend** | Convex free tier | Real-time reactive sync, server-side actions for enhancement that survive device sleep, $0 at single-user volume |
| **Knowledge graph** | Cognee on Mac Studio (Docker) | Self-hosted second brain, light stack (SQLite + LanceDB + Kuzu), 92.5% accuracy vs RAG baseline 60% |
| **Remote access to Mac Studio** | Tailscale | Free, encrypted, zero port forwarding, works anywhere |
| **LLM gateway** | OpenRouter | Single API key, swap models without code changes, automatic fallback |
| **Default LLM (enhancement)** | openai/gpt-5-mini | Best quality-per-dollar for writing tasks, $0.25/$2.00 per M tokens |
| **LLM (Cognee cognify)** | Local Ollama Gemma 4 26B MoE | Token-heavy operation, runs free on Mac Studio at 40-50 tok/s |
| **LLM (second brain queries)** | openai/gpt-5-mini OR local Ollama | gpt-5-mini for speed when online, Ollama as offline fallback |
| **Mac transcription (primary)** | FluidAudio Parakeet TDT v2 | 6.05% WER (best open-source), 300x+ realtime on M4, built-in pyannote diarization |
| **Mac transcription (fallback)** | WhisperKit (Argmax open-source) | When Parakeet struggles or non-English needed |
| **iOS transcription** | WhisperKit whisper-base.en | ~150 MB model, fast on phones, Mac re-transcribes with Parakeet when synced |
| **Paid escape hatch** | Deepgram Nova-3 | $200 free credits, then $0.0077/min for difficult audio |
| **Audio capture (Mac)** | ScreenCaptureKit + AVFoundation | System audio + mic mixed locally |
| **Calendar** | EventKit + ICS + Google | Three sources unified into single CalendarEvent model |
| **OCR** | Vision framework | Local, free, ships with macOS |

---

## 4. Repository Structure

```
meeting-app/
├── SPEC.md                        # This document
├── DECISIONS.md                   # Log of deviations and decisions
├── README.md                      # Setup, build, architecture, costs
├── .gitignore
│
├── apps/
│   ├── macOS/                     # Native macOS app
│   │   ├── MeetingApp.xcodeproj
│   │   ├── MeetingApp/
│   │   │   ├── Views/
│   │   │   ├── ViewModels/
│   │   │   ├── Services/
│   │   │   └── Resources/
│   │   └── Tests/
│   │
│   └── iOS/                       # iOS companion app
│       ├── MeetingAppMobile.xcodeproj
│       ├── MeetingAppMobile/
│       └── Tests/
│
├── packages/
│   └── Core/                      # Shared Swift package
│       ├── Package.swift
│       ├── Sources/
│       │   └── Core/
│       │       ├── Models/        # Convex-aligned models
│       │       ├── Services/      # ConvexClient, Transcription, LLM, Calendar
│       │       └── Prompts/       # Bundled markdown prompts
│       └── Tests/
│
├── convex/                        # Convex backend
│   ├── schema.ts
│   ├── meetings.ts
│   ├── tasks.ts
│   ├── transcripts.ts
│   ├── enhancement.ts             # Action: calls OpenRouter
│   ├── calendar.ts                # ICS sync cron
│   ├── recipes.ts
│   ├── secondBrain.ts             # Proxies to Mac Studio Cognee
│   ├── prompts/
│   │   ├── enhanceMeeting.ts
│   │   ├── extractTasks.ts
│   │   ├── recipes/
│   │   └── secondBrainQuery.ts
│   ├── tests/
│   │   └── fixtures/
│   └── package.json
│
├── mac-studio/                    # Cognee + Ollama setup for Mac Studio
│   ├── docker-compose.yml
│   ├── Caddyfile
│   ├── cognee-wrapper/            # FastAPI wrapper around Cognee
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── app/
│   │       ├── main.py
│   │       ├── ingestion.py
│   │       ├── search.py
│   │       └── models.py
│   ├── .env.example
│   └── README.md                  # Mac Studio setup walkthrough
│
└── docs/
    ├── architecture.md
    ├── calendar-sources.md
    ├── transcription.md
    ├── second-brain.md
    └── operations.md
```

---

## 5. Convex Schema

Build this first. Show as artifact. Get user approval before any client code.

```typescript
// convex/schema.ts
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
```

---

## 6. LLM Provider: OpenRouter

All LLM calls route through OpenRouter for unified billing and easy model swapping.

### Configuration

OpenRouter calls that run inside Convex actions use `OPENROUTER_API_KEY` from Convex environment variables. Local-only clients may keep a copy in macOS Keychain for settings validation and direct local tools, but server-side enhancement does not read Keychain. Base URL: `https://openrouter.ai/api/v1`. OpenAI-compatible API.

### Model routing per operation

Configurable in settings. Sensible defaults:

```typescript
// convex/lib/llmConfig.ts
export const LLM_MODELS = {
  meetingEnhancement: {
    default: "openai/gpt-5-mini",
    alternatives: ["anthropic/claude-sonnet-4.5", "openai/gpt-5"],
    rationale: "Best quality-per-dollar for structured writing. Honors style rules well.",
  },
  
  taskExtraction: {
    default: "openai/gpt-5-mini",
    alternatives: ["anthropic/claude-haiku-4.5"],
    rationale: "Fast, cheap, reliable structured JSON.",
  },
  
  cogneeCognify: {
    default: "ollama/gemma-4-26b-a4b-it",  // local on Mac Studio
    alternatives: ["openai/gpt-5-mini", "google/gemma-4-26b-a4b-it"],
    rationale: "Token-heavy, runs free on Mac Studio. Cloud only as fallback.",
  },
  
  cogneeMemify: {
    default: "ollama/gemma-4-26b-a4b-it",
    alternatives: ["google/gemma-4-26b-a4b-it"],
    rationale: "Batch operation, no time pressure, run free locally.",
  },
  
  secondBrainQuery: {
    default: "openai/gpt-5-mini",
    alternatives: ["google/gemma-4-31b-it", "anthropic/claude-sonnet-4.5"],
    rationale: "User-facing query, prioritize speed.",
  },
  
  voiceMemoTaskExtraction: {
    default: "openai/gpt-5-mini",
    alternatives: ["google/gemma-4-26b-a4b-it"],
    rationale: "Pennies per call regardless. Speed matters for UX.",
  },
  
  recipes: {
    default: "openai/gpt-5-mini",
    alternatives: ["anthropic/claude-sonnet-4.5"],
    rationale: "User invokes manually, quality matters.",
  },
};
```

### Why these defaults

- **gpt-5-mini ($0.25 in / $2.00 out per M)** is 4x cheaper than Claude Haiku 4.5 with comparable quality on structured output. For everything user-facing.
- **Ollama Gemma 4 26B MoE on Mac Studio** is free for the token-heavy Cognee operations. Gemma 4 jumped from 6.6% → 86.4% on agentic benchmarks vs Gemma 3, making it the first open Gemma generation that handles Cognee's structured extraction reliably.
- All defaults swappable via settings without code changes.

### Cost projection at user volume (88 hr/month meetings)

| Operation | Tokens/month | Cost |
|---|---|---|
| Meeting enhancement (gpt-5-mini) | ~5M in / 1M out | ~$3.25 |
| Task extraction (gpt-5-mini) | ~1M in / 0.2M out | ~$0.65 |
| Cognee cognify (local Ollama) | ~10M | $0 |
| Cognee memify (local Ollama) | ~5M | $0 |
| Second brain queries (gpt-5-mini) | ~2M in / 0.5M out | ~$1.50 |
| Voice memos + recipes | ~1M | ~$0.50 |
| **Total** | | **~$5-6/month** |

---

## 7. Mac Studio Setup (Phase 9 — second brain host)

The Mac Studio runs Cognee + Ollama as always-on services accessible via Tailscale from the M4 laptop and iPhone.

### Prerequisites
1. Mac Studio M4 Max 64GB on user's home network, always on
2. macOS 14+ with Docker Desktop OR Colima installed
3. Tailscale account (free personal tier)

### Setup steps (documented in `mac-studio/README.md`)

```bash
# 1. Install Tailscale
brew install --cask tailscale
# Sign in via menu bar, note the Tailscale hostname (e.g., mac-studio.tailXXXX.ts.net)

# 2. Install Ollama natively (better Metal/Neural Engine perf than Docker)
brew install ollama
brew services start ollama
ollama pull gemma-4-26b-a4b-it
ollama pull nomic-embed-text     # For Cognee embeddings

# Verify Ollama
curl http://localhost:11434/api/tags

# 3. Clone repo and start Cognee stack
cd ~/meeting-app/mac-studio
cp .env.example .env
# Edit .env with OpenRouter API key (used as Cognee fallback)
docker compose up -d

# 4. Verify Cognee accessible via Tailscale
curl https://mac-studio.tailXXXX.ts.net/cognee/health
```

### `mac-studio/docker-compose.yml`

```yaml
version: "3.9"

services:
  cognee:
    build: ./cognee-wrapper
    container_name: cognee
    restart: unless-stopped
    environment:
      # Primary LLM: local Ollama on host
      LLM_PROVIDER: ollama
      LLM_MODEL: gemma-4-26b-a4b-it
      LLM_ENDPOINT: http://host.docker.internal:11434
      EMBEDDING_PROVIDER: ollama
      EMBEDDING_MODEL: nomic-embed-text
      EMBEDDING_DIMENSIONS: 768
      
      # Fallback LLM: OpenRouter (used if Ollama down)
      FALLBACK_PROVIDER: openrouter
      FALLBACK_MODEL: google/gemma-4-26b-a4b-it
      FALLBACK_API_KEY: ${OPENROUTER_API_KEY}
      
      # Auth for the wrapper API
      COGNEE_API_KEY: ${COGNEE_API_KEY}
    volumes:
      - cognee-data:/data
    ports:
      - "127.0.0.1:8765:8765"   # Only accessible via Tailscale through Caddy

  caddy:
    image: caddy:2-alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy-data:/data
      - caddy-config:/config

volumes:
  cognee-data:
  caddy-data:
  caddy-config:
```

### `mac-studio/Caddyfile`

```
mac-studio.tailXXXX.ts.net {
    tls internal
    reverse_proxy /cognee/* cognee:8765
}
```

### `mac-studio/cognee-wrapper/app/main.py` (skeleton)

```python
from fastapi import FastAPI, Header, HTTPException, UploadFile
from pydantic import BaseModel
import cognee
import os

app = FastAPI(title="Cognee Wrapper")

API_KEY = os.environ["COGNEE_API_KEY"]

def verify_key(authorization: str = Header(...)):
    if authorization != f"Bearer {API_KEY}":
        raise HTTPException(401)

class IngestMeeting(BaseModel):
    meeting_id: str
    title: str
    enhanced_notes: str
    transcript: str
    attendees: list[str]
    date: str

@app.post("/cognee/ingest/meeting")
async def ingest_meeting(payload: IngestMeeting, _=Depends(verify_key)):
    text = f"""# {payload.title}
Date: {payload.date}
Attendees: {', '.join(payload.attendees)}

## Notes
{payload.enhanced_notes}

## Transcript
{payload.transcript}
"""
    await cognee.add(text, dataset_name="meetings", node_set=["meeting", payload.meeting_id])
    await cognee.cognify()
    return {"status": "ingested", "meeting_id": payload.meeting_id}

@app.post("/cognee/ingest/document")
async def ingest_document(file: UploadFile, _=Depends(verify_key)):
    content = await file.read()
    text = extract_text(file.filename, content)  # PDF/DOCX/MD extraction
    await cognee.add(text, dataset_name="documents", node_set=["document", file.filename])
    await cognee.cognify()
    return {"status": "ingested", "filename": file.filename}

class SearchQuery(BaseModel):
    query: str
    mode: str = "GRAPH_COMPLETION"
    limit: int = 10

@app.post("/cognee/search")
async def search(payload: SearchQuery, _=Depends(verify_key)):
    results = await cognee.search(
        query_text=payload.query,
        query_type=payload.mode,
    )
    return {"results": results[:payload.limit]}

@app.get("/cognee/health")
async def health():
    return {"status": "ok"}
```

### iOS access via Tailscale
- Install Tailscale iOS app
- Sign in to same account
- iPhone gets access to `mac-studio.tailXXXX.ts.net` from anywhere

---

## 8. Calendar Integration

Three sources unified into a single `CalendarEvent` model.

### Source 1: macOS Calendar via EventKit (default)
- Reads whatever calendars are added in macOS Calendar app
- If user has Google or Outlook in macOS Calendar, EventKit sees them automatically
- Requires Calendar permission on first launch

### Source 2: ICS feed subscriptions
- User pastes ICS URL in settings
- Convex cron job (every 15 min) fetches and parses
- Critical for: shared institutional calendars, CalendarBridge, recurring Outlook/Exchange feeds
- Implement minimal RFC 5545 parser (only need VEVENT with DTSTART, DTEND, SUMMARY, DESCRIPTION, LOCATION, RRULE, UID)
- Expand RRULE for next 14 days

### Source 3: Google Calendar API (direct OAuth, optional)
- For users who don't want to add Google to macOS Calendar
- Reads next 14 days, refreshes every 5 min when active

### Unification rules
- All sources feed normalized `calendarEvents` records in Convex
- Dedup: same title + start time within ±5 min = duplicate (suppress)
- Recurring meeting linking: match by recurring UID OR exact title (Granola's approach)
- Show "Previous instances" inline when viewing recurring meeting note
- Calendar source secrets are not stored in `calendarSources.config`. Convex functions store references such as `icsUrlSecretKey` or `googleOAuthSecretKey`, while the actual values live in Convex environment variables or platform key storage.

---

## 9. Transcription

Build `TranscriptionProvider` protocol with three implementations.

```swift
// packages/Core/Sources/Core/Services/TranscriptionProvider.swift
public protocol TranscriptionProvider {
    var name: String { get }
    var supportsStreaming: Bool { get }
    var supportsDiarization: Bool { get }
    var requiresNetwork: Bool { get }
    
    func startSession(config: TranscriptionConfig) async throws -> TranscriptionSession
    func transcribeBatch(audioURL: URL, config: TranscriptionConfig) async throws -> Transcript
}

public struct TranscriptionConfig {
    public let language: String       // "en" default
    public let vocabularyHints: [String]
    public let enableDiarization: Bool
}

public protocol TranscriptionSession {
    func append(audioBuffer: AVAudioPCMBuffer) async
    func partialTranscript() async -> Transcript
    func finish() async throws -> Transcript
}
```

### Provider 1: ParakeetProvider (default on Mac)
- FluidAudio Swift SDK: `github.com/FluidInference/FluidAudio`
- Model: Parakeet TDT 0.6B v2 (NVIDIA, MIT license)
- Runs on Apple Neural Engine via CoreML
- 300x+ realtime on M4
- 6.05% WER (best open-source on Open ASR Leaderboard)
- Built-in pyannote Community-1 diarization
- First-launch: ~6 GB download
- Vocabulary correction handled in LLM enhancement step (no native keyterm)

### Provider 2: WhisperKitProvider (fallback)
- Argmax open-source: `github.com/argmaxinc/WhisperKit`
- whisper-large-v3-turbo on Mac (~1.5 GB)
- whisper-base.en on iOS (~150 MB)
- 99 languages
- No built-in diarization

### Provider 3: DeepgramProvider (paid, optional)
- Nova-3 streaming WebSocket
- $200 free credits, no expiration
- Keyterm Prompting (up to 100 terms)
- Built-in diarization
- Show credit balance in settings
- Per-meeting toggle

### Streaming behavior
- Subsecond rolling buffers for live partials, with 2-3 second finalized chunks
- Partial results render within the <1s latency target, finalize on chunk boundary
- Diarization runs as post-process when meeting ends
- During meeting: simple channel split (mic = "Me", system = "Them") for live UX
- After meeting: full diarization assigns proper speaker labels

---

## 10. LLM Enhancement Pipeline

Runs as Convex action (server-side) so it survives device sleep after meeting ends.

### Prompt: `convex/prompts/enhanceMeeting.ts`

```typescript
export const ENHANCE_MEETING_SYSTEM_PROMPT = `
You are enhancing meeting notes for a physician informaticist who runs research,
AI governance, and administrative meetings (RICCC, CLIF Consortium, AI CoE,
IRB strategy, grant calls, vendor POCs, manuscript reviews). No clinical/PHI
content in these meetings.

# Writing Style Requirements (CRITICAL)
- Do NOT use em dashes anywhere. Replace with periods or commas.
- Do NOT use semicolons. Replace with periods or restructure.
- Match the user's professional, brief tone.
- Assume fluency in clinical informatics, statistics, and ML.
- No fluff, no hedging, no filler phrases.

# Domain Vocabulary (normalize phonetic variants to canonical spelling)
Organizations: CLIF Consortium, RICCC, BMO Institute for Health Equity, Rush,
  Anthropic, John Snow Labs (JSL), Microsoft Fabric, Azure AI Foundry
Technical: TRIPOD+AI, Caboodle, Epic Clarity, Lakehouse, federated learning,
  Arriaga decomposition, marimo, Polars, scikit-learn, RAG, MCP
People: Patrick Healey, Kevin Buell, Vineet Arora, David Beiser, Mary Kate,
  Tipu Puri
Programs: NIDA R01, NHLBI R01, AHA, KL2, T32, XDRO-ARM, SMART-AI, RORRM,
  HAPI-RS, CONSCIENCE, ChicagoHealthMap

# Inputs
- TRANSCRIPT: Full meeting transcript with timestamps and speaker labels
- RAW_NOTES: User's typed notes (markdown, may be sparse)
- SCREENSHOT_OCR: Text extracted from screenshots taken during the meeting
- TEMPLATE_TYPE: Meeting type (1:1, RICCC, AI CoE, IRB Strategy, etc.)
- PREVIOUS_NOTES: Notes from the most recent prior instance of this recurring meeting (if any)
- USER_VOCABULARY: Custom vocabulary list maintained by the user

# Output Format (JSON only, no other text)
{
  "enhancedNotes": "<markdown with [[ai]]...[[/ai]] tags around AI additions and [[ts:MM:SS]] tags linking to transcript timestamps>",
  "summary": "<2-3 sentence summary>",
  "keyDecisions": ["<decision 1>", "<decision 2>"],
  "actionItems": [
    {
      "title": "<task title>",
      "description": "<optional context>",
      "assignee": "user" | "others",
      "assigneeName": "<name if assignee is 'others'>",
      "dueDate": "<ISO date if mentioned, else null>",
      "priority": "low" | "medium" | "high",
      "transcriptTimestamp": "<MM:SS where this was discussed>"
    }
  ],
  "openQuestions": ["<question 1>"]
}

# Enhancement Rules
- PRESERVE the user's original raw notes verbatim. Do not edit or rewrite his text.
- ADD context, decisions, and details he missed by inserting [[ai]]...[[/ai]] blocks.
- Every [[ai]] block must include a [[ts:MM:SS]] timestamp link.
- Action items: identify whether each task is assigned to the user (J.C., JC, "I", "I'll") or to others. Be conservative — if unclear, mark as "others".
- Reference screenshot OCR text when relevant.
- For recurring meetings, note continuity ("Following up on last week's discussion of...").
`;
```

### Convex action

```typescript
// convex/enhancement.ts
import { action } from "./_generated/server";
import { v } from "convex/values";

export const enhanceMeeting = action({
  args: { meetingId: v.id("meetings") },
  handler: async (ctx, { meetingId }) => {
    const meeting = await ctx.runQuery(api.meetings.get, { meetingId });
    const transcript = await ctx.runQuery(api.transcripts.getFull, { meetingId });
    const screenshots = await ctx.runQuery(api.screenshots.getOcrText, { meetingId });
    const previousNotes = meeting.recurringId 
      ? await ctx.runQuery(api.meetings.getPreviousRecurring, { meetingId })
      : null;
    const vocabulary = await ctx.runQuery(api.vocabulary.list);
    
    await ctx.runMutation(api.meetings.setEnhancementStatus, {
      meetingId,
      status: "processing",
    });
    
    const apiKey = process.env.OPENROUTER_API_KEY;
    const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "openai/gpt-5-mini",
        messages: [
          { role: "system", content: ENHANCE_MEETING_SYSTEM_PROMPT },
          { role: "user", content: buildUserMessage({
            transcript, rawNotes: meeting.rawNotes, screenshots,
            templateType: meeting.templateId, previousNotes, vocabulary,
          })},
        ],
        response_format: { type: "json_object" },
      }),
    });
    
    const result = await response.json();
    const parsed = JSON.parse(result.choices[0].message.content);
    
    await ctx.runMutation(api.meetings.applyEnhancement, {
      meetingId,
      enhancedNotes: parsed.enhancedNotes,
      summary: parsed.summary,
      keyDecisions: parsed.keyDecisions,
      openQuestions: parsed.openQuestions,
    });
    
    // Insert tasks
    for (const item of parsed.actionItems) {
      await ctx.runMutation(api.tasks.create, {
        title: item.title,
        description: item.description,
        dueDate: item.dueDate ? Date.parse(item.dueDate) : null,
        assignee: item.assignee,
        assigneeName: item.assigneeName,
        priority: item.priority,
        sourceMeetingId: meetingId,
        status: "todo",
      });
    }
    
    // Trigger Cognee ingestion
    await ctx.scheduler.runAfter(0, api.secondBrain.ingestMeeting, { meetingId });
    
    await ctx.runMutation(api.meetings.setEnhancementStatus, {
      meetingId,
      status: "complete",
    });
  },
});
```

---

## 11. Default Templates

Ship with these, auto-apply by `titleKeywords` match:

```typescript
export const DEFAULT_TEMPLATES = [
  {
    name: "Generic Meeting", isDefault: true, titleKeywords: [],
    skeleton: "## Discussion\n\n## Decisions\n\n## Action Items\n",
  },
  {
    name: "1:1", titleKeywords: ["1:1", "one on one", "1-1"],
    skeleton: "## Updates\n\n## Blockers\n\n## Discussion\n\n## Action Items\n",
  },
  {
    name: "RICCC Meeting", titleKeywords: ["riccc", "rush interdisciplinary"],
    skeleton: "## Studies in Progress\n\n## New Proposals\n\n## Data & Analytics\n\n## Action Items\n",
  },
  {
    name: "CLIF Consortium", titleKeywords: ["clif", "consortium"],
    skeleton: "## Site Updates\n\n## Data Pipeline\n\n## Manuscripts\n\n## Action Items\n",
  },
  {
    name: "AI CoE", titleKeywords: ["ai coe", "ai center of excellence", "ai governance"],
    skeleton: "## Models in Production\n\n## In Development\n\n## Governance & Compliance\n\n## Decisions\n\n## Action Items\n",
  },
  {
    name: "IRB Strategy", titleKeywords: ["irb", "research ethics"],
    skeleton: "## Protocol Status\n\n## Amendments\n\n## Compliance Issues\n\n## Action Items\n",
  },
  {
    name: "Grant Strategy", titleKeywords: ["grant", "nih", "aha", "nhlbi", "nida"],
    skeleton: "## Aims & Hypothesis\n\n## Methods\n\n## Budget\n\n## Timeline\n\n## Action Items\n",
  },
  {
    name: "Vendor POC", titleKeywords: ["poc", "vendor", "demo", "evaluation"],
    skeleton: "## Capabilities Demonstrated\n\n## Gaps & Concerns\n\n## Pricing & Terms\n\n## Next Steps\n",
  },
  {
    name: "Manuscript Review", titleKeywords: ["manuscript", "paper", "draft", "submission"],
    skeleton: "## Reviewer Comments\n\n## Required Changes\n\n## Author Responses\n\n## Action Items\n",
  },
  {
    name: "Health Equity Analytics", titleKeywords: ["health equity", "garfield", "conscience", "chicago health map"],
    skeleton: "## Analytic Approach\n\n## Findings\n\n## Methodologic Issues\n\n## Action Items\n",
  },
];
```

---

## 12. Default Recipes

```typescript
export const DEFAULT_RECIPES = [
  {
    name: "Draft follow-up email", icon: "envelope",
    prompt: "Draft a concise follow-up email summarizing decisions, action items assigned to me, and next steps. Professional tone. No em dashes, no semicolons.",
  },
  {
    name: "What did I miss?", icon: "questionmark",
    prompt: "Summarize what was discussed while I may not have been fully attentive. Highlight decisions, commitments made by others, and questions directed at me.",
  },
  {
    name: "Coach me", icon: "person",
    prompt: "Analyze how I showed up in this meeting. How much did I speak vs listen? Did I ask open-ended questions? Did I miss opportunities? Be direct.",
  },
  {
    name: "Prep next meeting", icon: "calendar",
    prompt: "Based on this meeting and recent prior meetings with these attendees, draft prep notes for our next conversation: open items, follow-ups, suggested topics.",
  },
  {
    name: "Extract grant-relevant content", icon: "doc.text",
    prompt: "Identify any content relevant to active grant applications (NIH R01, AHA, NHLBI). Format as bulleted notes I can paste into specific aims, methods, or progress updates.",
  },
  {
    name: "Manuscript-relevant findings", icon: "book",
    prompt: "Identify any findings, decisions, or data points that should be incorporated into in-progress manuscripts. Format with section suggestions.",
  },
];
```

---

## 13. Default Vocabulary

Pre-populate on first launch:

```typescript
export const DEFAULT_VOCABULARY = [
  { term: "CLIF Consortium", aliases: ["clift consortium", "clif"], category: "organization" },
  { term: "RICCC", aliases: ["rick", "ricck"], category: "organization" },
  { term: "BMO Institute for Health Equity", aliases: ["bmo institute"], category: "organization" },
  { term: "John Snow Labs", aliases: ["jsl", "john snow"], category: "organization" },
  { term: "Microsoft Fabric", aliases: ["ms fabric"], category: "technical" },
  { term: "Azure AI Foundry", aliases: ["azure foundry"], category: "technical" },
  { term: "TRIPOD+AI", aliases: ["tripod ai", "tripod-ai"], category: "technical" },
  { term: "Caboodle", aliases: ["kabudl"], category: "technical" },
  { term: "Epic Clarity", aliases: ["clarity"], category: "technical" },
  { term: "marimo", aliases: ["marimoto"], category: "technical" },
  { term: "Polars", aliases: ["polar"], category: "technical" },
  { term: "Arriaga decomposition", aliases: ["arriagas decomposition"], category: "technical" },
  { term: "federated learning", aliases: [], category: "technical" },
  { term: "RAG", aliases: ["rag pipeline"], category: "technical" },
  { term: "MCP", aliases: ["model context protocol"], category: "technical" },
  { term: "CONSCIENCE", aliases: ["conscience study"], category: "program" },
  { term: "ChicagoHealthMap", aliases: ["chicago health map"], category: "program" },
  { term: "RORRM", aliases: ["rorrm qi"], category: "program" },
  { term: "HAPI-RS", aliases: ["hapi rs", "hapirs"], category: "program" },
  { term: "SMART-AI", aliases: ["smart ai"], category: "program" },
  { term: "XDRO-ARM", aliases: ["xdro arm"], category: "program" },
  { term: "Patrick Healey", aliases: ["pat healey", "patrick healy"], category: "person" },
  { term: "Kevin Buell", aliases: ["kevin bewell"], category: "person" },
  { term: "Vineet Arora", aliases: ["vinit arora"], category: "person" },
  { term: "David Beiser", aliases: ["david beizer"], category: "person" },
];
```

---

## 14. Second Brain Integration

### Ingestion flow

When meeting enhancement completes:
1. Convex action triggers `secondBrain.ingestMeeting` 
2. Function POSTs enhanced notes + transcript to `https://mac-studio.tailXXXX.ts.net/cognee/ingest/meeting`
3. Cognee wrapper on Mac Studio runs `cognee.add()` then `cognee.cognify()` using local Ollama Gemma 4 26B MoE
4. On success, mark `meeting.secondBrainStatus = "synced"` in Convex

When user uploads document (PDF, DOCX, MD):
1. File uploaded to Convex storage
2. Convex action POSTs file to `/cognee/ingest/document`
3. Cognee extracts text, runs cognify pipeline
4. Mark `document.secondBrainStatus = "synced"`

### Query flow

User opens "Second Brain" tab and types query (e.g., "What did Patrick say about CLIF data extraction in the last 3 months?"):
1. App POSTs to `/cognee/search` with query + mode
2. Cognee runs graph traversal using local Ollama (or OpenRouter Gemma 4 31B for complex queries)
3. Returns ranked results with source meeting/document links
4. App displays with clickable links back to source meetings/documents

### Modes available
- `GRAPH_COMPLETION` (default) — graph traversal with vector grounding
- `RAG_COMPLETION` — pure vector RAG fallback
- `INSIGHTS` — summarized insights across multiple sources
- `CHUNKS` — raw chunks with citations

---

## 15. UX Patterns to Replicate from Granola

### Hybrid notes pattern (single most important UX detail)
- During meeting: split view, user notes left, live transcript right
- After "Enhance Notes":
  - User text renders **black**
  - AI additions render **gray** with subtle vertical accent bar
  - Each AI addition has small `↗` icon → click jumps audio + transcript to that timestamp
- Implemented via `[[ai]]...[[/ai]]` and `[[ts:MM:SS]]` markdown extension

### Bot-free invisible recording
- ScreenCaptureKit + AVFoundation, mixed locally
- Works with Zoom, Meet, Teams, Webex, FaceTime, Slack huddles, WhatsApp

### Meeting detection flow
- Sidebar "Coming up" section, next 5 meetings
- 2 min before video-link event: floating notification + menu bar pulse
- Detect Zoom/Meet/Teams app launch as fallback
- Mic-in-use detection as second fallback
- Click "Start notes" pre-fills title, attendees, date, auto-applied template

### Visual design
- Minimalist Notion-like editor
- SF Pro, generous whitespace, light/dark mode follows system
- Two-pane: sidebar (Today, Coming up, All Meetings, Tasks, **Second Brain**, People, Companies, Folders) + main content
- Accent color: deep teal `#0F4C5C` (avoid Granola's "gray on gray" criticism)
- People/Companies: auto-organize by attendee email domain

### Speed details
- Notes auto-save every 2 seconds via Convex mutations (non-blocking)
- Transcript renders incrementally as Parakeet streams chunks
- Enhancement runs in background, user can navigate away
- Reactive queries: changes from another device appear instantly

### Templates auto-apply
- Match meeting title against `titleKeywords`
- Apply automatically, no manual click
- User can override before recording starts

### Ask [App] chat
- Persistent chat panel right side of meeting view
- Single meeting: gpt-5-mini directly with transcript context
- Multi-meeting: full-text search → top results as context
- Cross-corpus: routes to second brain (Cognee on Mac Studio)

### Recipes
- `/` opens recipe picker in any meeting view
- Built-in recipes ship with app, user can create custom

---

## 16. Differentiating Features (Granola gaps)

### Inline screenshots
- Global hotkey `⌘⌥⇧S` (customizable) during meeting captures screen
- Inserted at cursor in notes with timestamp
- Inserted screenshots use durable inline markers, such as `[[screenshot:<id>]]`, so raw and enhanced notes preserve placement
- Optional pre-insertion annotation: arrows, boxes, text (PencilKit)
- Stored as Convex file
- Vision framework OCR runs locally
- OCR text fed to LLM enhancement context
- Screenshots remain inline in final enhanced note rendering

### Integrated task management
- LLM-extracted during enhancement with explicit assignee detection
- `assignee = "user"` → unified task list
- `assignee = "others"` → "Tasks for others" section in meeting view
- Unified Tasks view: Today, This Week, By Meeting, By Project, All
- Keyboard nav: j/k, x complete, e edit, n new
- Tasks linked to source meeting are clickable and retain transcript timestamp plus source evidence text

### Audio retention with synced playback
- Store locally by default. Convex audio sync is opt-in and subject to retention and storage limits
- Playback in meeting view with transcript-synced highlighting
- Click any transcript line → audio jumps to timestamp
- Auto-delete after N days (default 90)

### Second brain (the killer differentiator)
- Cognee knowledge graph across meetings + documents
- Cross-corpus queries: "What did we decide about X across all meetings?"
- Document ingestion: drag PDFs, papers, grants, manuscripts
- Graph visualization (Phase 10, optional)
- Multi-hop reasoning: "Which manuscripts reference findings from RICCC meetings in Q2?"

---

## 17. Eval Harness

Build alongside enhancement pipeline.

### Fixture: synthetic AI CoE meeting

`convex/tests/fixtures/ai_coe_synthetic.json`:

```json
{
  "title": "AI CoE Weekly - Aug 14",
  "attendees": [
    {"name": "JC Rojas", "email": "jc.rojas@rush.edu"},
    {"name": "Patrick Healey", "email": "patrick.healey@rush.edu"},
    {"name": "Kevin Buell", "email": "kbuell@rush.edu"}
  ],
  "transcript": [
    {"startMs": 0, "endMs": 8000, "speaker": "Patrick", "text": "Let's start with the JSL POC update. Where are we on the de-identification scaling work?"},
    {"startMs": 8000, "endMs": 24000, "speaker": "JC", "text": "We finished v3 of the AI due diligence questionnaire. The Microsoft Fabric Lakehouse integration is set up and we're processing pathology PDFs through the John Snow Labs pipeline. Pat needs to take ownership of the Caboodle data extraction piece by Friday."},
    {"startMs": 24000, "endMs": 32000, "speaker": "Kevin", "text": "What about the TRIPOD+AI documentation for the fall risk validation?"},
    {"startMs": 32000, "endMs": 48000, "speaker": "JC", "text": "Still on me. I'll get the methods section drafted by next Wednesday. Targeting JAMA Network Open. Comparing PMFRS to Morse Fall Scale."},
    {"startMs": 48000, "endMs": 60000, "speaker": "Patrick", "text": "Good. And the policy chat RAG system, where are we with that?"},
    {"startMs": 60000, "endMs": 78000, "speaker": "JC", "text": "Eighteen hundred policies indexed. We need someone to validate the answer quality on a sample of fifty queries. Patrick, can your team handle that this sprint?"},
    {"startMs": 78000, "endMs": 84000, "speaker": "Patrick", "text": "Yes, I'll have Maria run that eval."}
  ],
  "rawNotes": "AI CoE notes\n\n- JSL POC scaling\n- Fall risk validation manuscript\n- PolicyChat eval needed",
  "expectedEnhancement": {
    "actionItems": [
      {"title": "Draft methods section for fall risk validation manuscript", "assignee": "user", "dueDate": "next Wednesday"},
      {"title": "Take ownership of Caboodle data extraction for JSL POC", "assignee": "others", "assigneeName": "Patrick Healey", "dueDate": "Friday"},
      {"title": "Run 50-query eval on PolicyChat", "assignee": "others", "assigneeName": "Maria"}
    ]
  }
}
```

### Eval criteria
1. **Vocabulary normalization**: "JSL", "TRIPOD+AI", "PMFRS", "Caboodle", "Microsoft Fabric Lakehouse", "PolicyChat" appear with canonical spelling
2. **Assignee detection**: tasks assigned to user vs others correctly distinguished (precision and recall both > 90%)
3. **No em dashes or semicolons** in output (regex check)
4. **Decision extraction**: at least 80% of decisions captured
5. **Timestamp links**: every AI addition has `[[ts:MM:SS]]` link
6. **Style**: pass automated tone check (no fluff phrases like "let's dive in", "exciting", etc.)

Build at least 5 fixture transcripts covering different meeting types before shipping enhancement to production. Run them in CI.

---

## 18. Settings

```
General
- User name and aliases (for assignee detection)
- Default folder
- Show meeting notifications [On/Off]
- Default accent color

Calendar Sources
- macOS Calendar (EventKit) [auto-detected]
- ICS feeds: [add by URL]
- Google Calendar: [connect via OAuth]
- Per-source: enabled calendars, last sync, errors

Transcription
- Default engine: [Parakeet (recommended) / WhisperKit / Deepgram]
- Diarization: [Auto / Always / Off]
- Language: [English / ...]
- Show live transcript during meeting: [On/Off]

LLM (OpenRouter)
- OpenRouter API key: Convex env var for server actions, optional Keychain copy for local validation
- Per-operation model overrides:
  - Meeting enhancement: [openai/gpt-5-mini default]
  - Task extraction: [openai/gpt-5-mini default]
  - Second brain queries: [openai/gpt-5-mini default]
  - Voice memo extraction: [openai/gpt-5-mini default]
  - Recipes: [openai/gpt-5-mini default]
- Show monthly cost estimate

Second Brain (Mac Studio)
- Tailscale hostname: [mac-studio.tailXXXX.ts.net]
- Cognee API key (Keychain)
- Health check status indicator
- Manual ingestion trigger: "Re-sync all meetings"
- Document upload area
- Local Ollama model: [gemma-4-26b-a4b-it]

Vocabulary
- Pre-populated list (see section 13)
- User can add/edit/remove

Audio
- Retention: [30/60/90/180/365 days, never]
- Sync to Convex: [On/Off]
- Sources: [system + mic / system only / mic only]

Hotkeys (customizable)
- Start/stop recording
- Screenshot in meeting (default ⌘⌥⇧S)
- Quick note
- Open command palette

Templates & Recipes
- Manage built-in + custom
- Auto-apply templates: [On/Off]

Privacy
- "AI processing" indicator when calling LLM
- Export all data (markdown + media folder)
- Delete all data (Convex + Cognee on Mac Studio)
```

---

## 19. Build Order — Strict Phasing

Each phase ends with user approval before next phase starts.

### Phase 1: Foundation (verify before coding)
1. Read this entire spec
2. Create `SPEC.md` and `DECISIONS.md` in repo root
3. Initialize Convex project (`npx convex dev`)
4. **Show Convex schema as artifact, get user approval**
5. Initialize Xcode workspace with macOS target, iOS target, Core Swift package

### Phase 2: Core capture (highest risk — verify with real meeting)
6. Mac audio capture (ScreenCaptureKit + AVFoundation)
7. **Test: capture system audio from a real Zoom call to a file, verify clean audio**
8. FluidAudio Parakeet integration
9. **Test: transcribe a real 30-min meeting end-to-end, verify accuracy and speed**
10. Live transcript UI during recording

### Phase 3: Calendar
11. EventKit integration, "Coming up" sidebar populated
12. ICS parser as Convex function with cron job
13. Google Calendar OAuth
14. Calendar Sources settings UI with dedup

### Phase 4: Notes & enhancement
15. Live notes UI (split view with transcript)
16. Screenshot capture with Vision OCR
17. **Show enhanceMeeting prompt as artifact, get user approval**
18. Enhancement pipeline as Convex action via OpenRouter
19. Eval harness with 5 fixture transcripts
20. Hybrid notes rendering (black/gray + timestamp links)

### Phase 5: Tasks
21. Task extraction integrated with enhancement
22. Task management UI (unified list, filters, keyboard nav)
23. Task-meeting linking

### Phase 6: Discovery
24. Meeting library + Convex full-text search
25. Audio playback with transcript-synced highlighting
26. Recipes feature
27. Ask [App] chat panel (single meeting)

### Phase 7: iOS companion
28. iOS app shell, read meetings/tasks via Convex
29. iOS audio capture + WhisperKit base.en
30. Voice memo task input (gpt-5-mini extraction)
31. Audio handoff (iOS records, Mac re-transcribes with Parakeet)

### Phase 8: Polish
32. Hotkeys, menu bar integration, notifications
33. Settings UI completion
34. Performance pass to hit latency targets
35. Export, backup, data management

### Phase 9: Second Brain (Mac Studio + Cognee)
36. Mac Studio setup walkthrough in `mac-studio/README.md`
37. Docker compose for Cognee + Caddy
38. Ollama installation + Gemma 4 26B MoE pull
39. FastAPI wrapper for Cognee with auth
40. Tailscale configuration
41. Convex `secondBrain.ts` action: ingest meeting on enhancement complete
42. Document upload UI in Mac app
43. "Second Brain" tab with query interface
44. Multi-meeting Ask [App] chat (cross-corpus)

### Phase 10: Optional polish (future)
- Knowledge graph visualization
- Voice mode for second brain queries
- Apple Watch task quick-capture
- Public sharing of selected notes (read-only links)
- Browser extension to clip web pages into second brain

---

## 20. Deliverables

1. **Xcode workspace** with three targets/packages
2. **Convex backend** with schema, functions, prompts, tests
3. **Mac Studio bundle** in `mac-studio/` ready to deploy
4. **`SPEC.md`** kept current as living document
5. **`DECISIONS.md`** logging all deviations from this spec
6. **`README.md`** with setup, build, architecture, costs, calendar source walkthrough, Mac Studio setup
7. **`prompts/`** versioned LLM prompts (enhanceMeeting, recipes, secondBrain, etc.)
8. **`tests/`**:
   - Unit tests for stores and services
   - Eval harness with 5+ fixture transcripts and golden outputs
   - Integration tests: Convex ↔ Mac Studio Cognee
   - Manual test plan: two Macs offline-editing, iPhone task while Mac offline, audio recorded on iPhone synced to Mac, ICS dedup, recurring meeting linking, second brain query

---

## 21. First Action

**Do NOT start coding.** Instead:

1. Read this entire spec from top to bottom
2. Create `SPEC.md` in the repo root with this exact content
3. Create `DECISIONS.md` with header "Deviations and decisions log" (empty body)
4. Create `README.md` skeleton
5. Initialize Convex project (`npx convex dev`)
6. Show me the Convex schema (`convex/schema.ts`) as an artifact — flag anything in this spec that seems wrong or under-specified
7. **Wait for my approval before proceeding to Phase 2**

Show your work. Use artifacts liberally. Confirm before each phase boundary.

---

## 22. Notes for the Agent

- This is a single-user app. Do not build multi-tenant auth unless explicitly asked.
- Performance is non-negotiable. Hit the latency targets in section 1.
- Style requirements (no em dashes, no semicolons) apply to ALL user-facing output, including LLM prompts.
- When uncertain between two approaches, ask the user. Do not silently pick.
- If you find a better technical choice than what's in this spec, propose it in `DECISIONS.md` before changing course.
- Privacy first: nothing leaves the user's devices except Convex sync and OpenRouter API calls. Cognee data lives only on user's Mac Studio.
- Use Swift Concurrency (async/await) throughout. No Combine unless required by a framework.
- Use Convex reactive queries everywhere; avoid manual refresh logic.
- Test with real meetings, not just unit tests. Phase 2 is gated on a real Zoom call working end-to-end.

End of spec.
