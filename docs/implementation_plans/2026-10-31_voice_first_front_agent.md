# Voice-first front agent: one place to talk, many chats, she answers too

- Status: proposed
- Date: 2026-10-31
- Builds on: [single agent entry point](./2026-10-23_single_agent_entry_point.md)
  (slices 0–2 landed), [ADR 0149](../adr/0149-search-lists-word-matches-then-related-by-meaning.md)
  (search by meaning in every search) and the journal answer engine in PR #4902
- Concepts: [front agent](../../knowledge/features/front_agent.md),
  [scoped query conversations](../../knowledge/features/agents/query-chat.md),
  [companion](../../lib/features/companion/README.md)

## Goal

The owner wants to ask anything in full sentences, mostly by voice, and get an
answer, without choosing a surface first. On 2026-10-31 they decided:

- **One place:** the front agent, in her **voice-first** form, with the
  companion (the speaking grandmother) in the layout. She opens over the app
  from anywhere.
- **She can do anything** from there: answer from the journal herself, ask the
  owning agent, file, create.
- **Multiple chats with history**, like Claude or ChatGPT: a list of
  conversations, start a new one, come back to an old one.
- **The scope is the person's choice:** optional category chips, or a category
  named in the question ("in the colony category, find the feeder notes").

This replaces the journal-wide Ask surfaces tried in #4902 (a control beside
the search field, then inside it, then a row in the results). They were
rejected: the search field must keep its width, and there should be one place
to talk, not a second chat beside hers.

## What changes in the earlier plan's decisions

| # | Earlier decision (2026-10-23) | Now |
|---|---|---|
| 2 | Attributed specialist text, no relay | **Kept** for doors. Her own journal answers are new: attributed to her, with numbered evidence. She still never rewords an owner's answer. |
| 4 | Narrow allow-list, categories opted in | **Kept.** Journal answers stay inside her allow-list; a chip or a named category narrows it further, never widens it. |
| 7 | One continuous thread with day dividers | **Reversed.** Multiple chats. Day dividers stay within a chat. The inbox spans all chats. |
| 8 | Her cheap setup for routing, the destination's for answers | **Kept.** A journal answer has no destination, so it runs on the Settings default inference profile, as #4902's journal scope does. |
| 1, 3, 5, 6 | Confirm before filing; an app-shell surface; project statements deferred; the 41-call case | **Kept.** The surface grows from a sheet into the voice-first panel (slice C). |

## What exists

- **Front agent** (`lib/features/front_agent/`):
  - **Model:** one identity and one thread. `threadId` is the turn's own id, and history is the last 50 messages (`FrontChatThreadBuilder`).
  - **Tools:** `dispatch`, `read_tldr`, `match_to_corpus`, `ask_user` and `reply_to_user`. Her prompt forbids answering on the owner's behalf.
  - **Routing:** the door walker sends task and project questions through `QueryAnswerBuilder` headless. `journal` and `unrouted` segments have no answer path.
  - **Surface:** a side sheet (a bottom sheet on a phone) built on `AgentChatView`, with no avatar and no spoken reply.
- **The journal answer engine (#4902)**, which this plan reuses:
  - `QueryScope.journalIn(categoryIds)`;
  - the plan step's 1–3 natural-language `searches`, each run by meaning (`vectorSearchRepositoryProvider`) beside keywords;
  - live privacy checks on every source;
  - cited answers;
  - the tolerant `QueryScopeKind` decode;
  - Settings-default profile resolution.
- **Query chat:** an event-sourced multi-chat store (`created`, `renamed`, `archived`, `deleted`, `read`, ...) with a switcher. This is the template for multiple front chats.
- **Companion:** `CompanionSpeaker(sourceId)` speaks whatever `TtsPlaybackController` plays for that source, with lip-sync and tone. Gestures include `listen` and `think`; there is no listening mode yet.
- **Voice:** the shared `ChatRecorderController`, plus Voxtral realtime transcription.

## Slices

Each slice is its own pull request off `main`, green and reviewed before the
next one. The order is a proposal.

### A. She answers from the journal (rework of #4902)

- A segment the router marks `journal` — or `unrouted` with nothing better —
  is answered by her through the journal engine, scoped to:
  - **the category named in the question**, matched by name against the
    visible categories in her allow-list (the plan step is given those names
    and returns the ones the question limits itself to). A named category she
    cannot see narrows to nothing — she finds nothing rather than falling
    through to the steps below, which would widen the search; else
  - **the chat's category chips** (slice C); else
  - **her whole allow-list.**
- **Evidence and privacy contract.** The answer is her door's outcome,
  `FrontDoorAnswer(fromJournal: true)`, and the door record persists its
  numbered passages (`evidence`), every source it rests on (`dependencies`)
  and whether it drew on private material. On every load, reload or replay
  the card rechecks those sources live (`frontJournalAccessProvider`, reread
  on any journal, category or config-flag change and on lockdown): if one is
  deleted, moved to a category she may not see, or turned private, the
  answer is hidden, and it stays hidden until visibility is known. A shown
  source opens its own page.
- Her prompt changes from "you never answer" to "you answer from the journal,
  with evidence; owners answer about their own work".
- #4902's journal Ask row and sheet are already gone; its engine stays.
- **Tests:**
  - routing a journal segment;
  - a named category narrowing the crawl;
  - a category she cannot see reads nothing;
  - evidence in the front thread, persisted and reloaded;
  - privacy rechecks, including a change during the first check.

### B. Multiple chats with history

- A front conversation id on every front record. Events:
  `frontChatCreated`, `renamed`, `archived`, `deleted` (with an optional forget
  of its memory), following query chat's event model.
- Existing messages, which have no conversation id, form one conversation,
  "Earlier", under one fixed id (`front-chat:earlier`). Every device derives
  the same id, so the history never splits after sync, and no migration
  event is written.
- Every new kind decodes tolerantly, but an unknown event is never skipped:
  a conversation holding an event this build does not know is shown as
  unavailable (from a newer version), as `QueryScopeKind.unknown` is, because
  replaying it without, say, a `deleted` or `archived` event would show what
  the writer meant to hide.
- History is paged per chat instead of the global last 50. Recovery and pending
  turns are keyed by conversation.
- A chat is titled from its first question and can be renamed. The list is
  newest first, searchable, with archive and delete.
- The inbox gathers unfiled statements from every chat.
- **UI:** the list beside the conversation on a wide window, and a drawer or
  first page on a phone, as in Claude or ChatGPT.
- **Tests:** create, switch, rename, archive, delete and forget; migration of
  the existing thread; sync of each event; paging.
- **As built (ADR 0154), where it differs from the above:**
  - The conversation id rides on the user turn's payload only; her rows and
    the doors belong to it through their `operationId`. There is no
    `created` event: a conversation exists once it holds a turn.
  - The lifecycle reuses query chat's existing `renamed`, `archived` and
    `deleted` events, so no event kind is new and none can be unknown to a
    build that has this one. A kind added later is not decoded by an older
    build: its sync rejects the event as unrecoverable, as for any agent
    entity it cannot read, so that build keeps the conversation as it last
    knew it. Adding one therefore needs the decoder to tolerate unknown
    kinds first.
  - No "forget" on delete: the front agent keeps no conversation memories.
  - No paging yet: the newest fifty messages are now per conversation.
  - The list opens in place of the thread in the sheet; the list beside the
    conversation on a wide window comes with slice C's panel.
  - Pulled forward from slice C at the owner's request, after the first
    list and header were rejected: her bust leading the conversation (a
    hero that scrolls with the thread), her replies as prose, one talk
    disc that keeps its place while listening and sends what was said
    (`AgentChatView` `conversational`, `voiceFirst`, `leading`). Still for
    slice C: her spoken replies, her listen and think gestures, barge-in,
    the personality block and the large panel.

### C. Voice-first, with her in the layout

- **A new surface, opening over the app like History:** a large panel on
  desktop, full screen on a phone.
- **Layout:**
  - the companion's bust above the conversation;
  - **one large talk control** as the primary input (tap to talk, tap to
    send; hold-to-talk on desktop is an option);
  - the text composer secondary;
  - optional category chips under the header (none selected = her allow-list).
- **She speaks the replies to spoken questions** (the owner's decision)
  through `CompanionSpeaker(sourceId: front-chat:<conversation>)`; a typed
  question gets a written reply only. Her `listen`
  gesture shows while you record and `think` while she works; a stop control
  silences her.
- **Barge-in interlock (REQ-11):** starting to talk stops her voice, and she
  never records herself.
- The personality block comes from `CompanionSass`. Reduced motion and a
  muted voice are respected.
- **Opening it:** the existing `openFrontChat` command (⌘/Ctrl+L), the
  sidebar, the phone launcher, and pressing her bust wherever she appears.
- **Tests:**
  - recording to send;
  - the reply to a spoken question spoken and lip-synced to its source;
  - the reply to a typed question written, never spoken;
  - barge-in;
  - chips narrowing the scope;
  - reduced motion and mute;
  - layout at phone and desktop sizes;
  - before/after screenshots.

### D. "Anything" — the remaining doors

- **Daily OS:** a `day` segment refines today.
- **Project door:** files a statement under a project.
- **Creating** a task, note or goal from a turn, confirmed with one tap
  (decision 1).
- Auto-filing stays an opt-in for later.

## Decided (owner, 2026-10-31)

1. **Order:** A, then B, then C, then D.
2. **Talking:** tap to talk, and tap again to send when done.
3. **Her voice:** she speaks a reply only when the question was spoken.
   A typed question gets a written reply.
