# ADR 0154: The Front Agent Keeps Many Conversations

- Status: Accepted
- Date: 2026-10-31
- Reverses: decision 7 of the
  [single-entry-point plan](../implementation_plans/2026-10-23_single_agent_entry_point.md)
  (one continuous thread)
- Plan: [voice-first front agent](../implementation_plans/2026-10-31_voice_first_front_agent.md), slice B
- Concept: [front agent](../../knowledge/features/front_agent.md#conversations)

## Context

The front agent kept one continuous thread with day dividers. Once she
answers journal questions (ADR 0153) and becomes the place from which the
user does anything, one thread mixes unrelated subjects: the routing model
reads the last few turns, so yesterday's census question steers today's
krill question, and the user cannot return to an earlier subject or put one
away. The owner asked for multiple chats with history, as in Claude or
ChatGPT.

## Decision

1. **A conversation is the user turns that name it.** A user turn's payload
   carries `conversationId`; nothing ever rewrites a user turn's payload,
   and an older build ignores the key and shows the turn in its one thread.
   Her reply, her question and the doors belong to the turn's conversation
   through the `operationId` they already carry. There is no creation
   record: a conversation exists once it holds a turn, and a new one is an
   id the surface holds until the first send.
2. **Turns from before are one fixed conversation.** A turn that names none
   belongs to `front-chat:earlier`. Every device derives the same id from
   the same untagged turns, so the history never splits after sync and no
   migration event is written.
3. **Lifecycle reuses query chat's synced events.** Renaming, archiving and
   deleting write query chat's `renamed`, `archived` and `deleted` events
   under the front agent's id, with the conversation as the chat. They need
   no new entity type — the agent entity union is frozen at its size — and
   query chat's projection never lists them, because it lists only chats
   with a `created` event. A title is the first question until renamed.
4. **Deleting hides; it does not erase.** A deleted conversation leaves the
   list and its turns leave every view, the inbox included, on every device
   that knows the event. Anything filed from it stays where it was filed.
5. **Each conversation is its own context.** The thread shows one
   conversation (still the newest fifty messages, now per conversation),
   and the routing prompt's recent turns come from the pending turn's own
   conversation only.
6. **The inbox spans all of them.** What waits on the user is gathered from
   every conversation not deleted, and the header's count is that total.
7. **The title is the way to the list.** On a phone the header has no width
   for another icon, so the conversation's title opens the list, as in a
   ChatGPT window; a new-conversation action sits beside it.

## Consequences

- A build before this one shows every conversation's turns in its single
  thread and ignores renames, archives and deletes.
- Deleting a conversation does not tombstone its messages; a later decision
  can erase them if the owner wants deletion to mean that.
- There is still no paging past the newest fifty messages of a
  conversation; with subjects split into conversations that bound is reached
  far later than in one thread.
