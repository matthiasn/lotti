# Companion chat redesign: "Sidecar"

**Date:** 2026-11-11
**Status:** Implemented on `feat/companion-chat-sidecar`, stacked on
`feat/companion-genui-surfaces` (#5071).

**Decisions as taken:** 1–4 and 6 as their defaults. 5: yes — opening the
drawer keeps a recording; only changing or starting a conversation cancels
it (regression test in `front_chat_pane_test.dart`, run once with the change
reverted). 7: tokens only, no new layout constant — the drawer over a phone's
thread is `kDetailContentMaxWidth × FrontChatPane.listShare` (the list's
desktop width) at most, and a tap target narrower than the pane. The
composer needed no new slot: `DesignSystemChatInput.leading` already existed,
so `AgentChatView` gained only `composerLeading`, forwarding to it. After
review: the header carries no inbox count, only a dot on the drawer toggle;
the count is the drawer's Inbox row's.

**Design:** direction D on the "Round 2 · Drawer" page of the
[Companion Chat Redesign canvas](https://claude.ai/artifact/75GpeGGGRPSaTdEXrauGv2)
(private to its owner until shared): `D · Chat`, `D · Drawer open`,
`D · Pick a category`.

## Problem

The companion chat is meant to become the app's default surface, and today it
does not read as designed:

- The header carries the list glyph, the inbox count, her face, her name, the
  voice button, an overflow and the close, with the conversation's title on a
  second line under them.
- On a phone the conversation list is a *page that replaces the thread*
  (`frontConversationListOpenProvider` swaps `FrontChatThreadView` for
  `FrontConversationList` in `FrontChatPane`).
- New chat, the mute switch, the AI profile, the internals and the
  conversation's own actions all live in one overflow menu.
- The composer shows two hint lines ("Ask anything…" and "Type @ to name a
  category").
- Nothing in the list says which category a conversation was about.

## Goal

A chat that feels like Claude or ChatGPT at first glance and is still Lotti's:

1. **One-row header.** Drawer toggle (with the inbox count), her face, her
   name, new chat, close. No title line, no overflow.
2. **A side drawer** that slides over the thread and carries everything else:
   search, new chat, categories, the dated history, and her settings.
3. **A thread that shows only what was said.** No helper line, no per-turn
   cost line.
4. **The category is picked in the composer** and applies to every turn sent
   from then on.
5. **The close button stays** for as long as the chat is a surface over the
   app rather than the app itself.

## What exists today

| Piece | Where | Relevant behaviour |
|---|---|---|
| Surface | `lib/features/front_agent/ui/front_chat_surface.dart` | Full screen below `WoltModalConfig.pageBreakpoint` (560), a panel above it; on a desktop layout the list sits beside the thread at `listShare` 0.38. |
| Pane | `lib/features/front_agent/ui/front_chat_pane.dart` | Chooses list or thread; `PopScope` closes the list, then the inbox, then the surface; cancels a live recording when the list opens or the conversation changes. |
| Header | `lib/features/front_agent/ui/front_chat_header.dart` | Two modes (conversation, list page); owns the overflow menu. |
| List | `lib/features/front_agent/ui/front_conversation_list.dart` | Inbox row, search, recency sections, archived group, per-row menu. |
| Row actions | `lib/features/front_agent/ui/front_conversation_actions.dart` | Rename, archive, delete; `FrontMenuButton`. |
| Voice | `front_voice_controls.dart`, `front_voice_switch.dart` | "Say it again" button; the mute switch and its menu-item form. |
| Profile, internals | `front_profile_choice.dart`, `AgentInternalsPanel.show` | Already callable from anywhere with a context. |
| Composer | `AgentChatView` → `DesignSystemChatInput` | `composerHelper` is the `@` hint; `mentionOptions` come from `frontMentionCategoriesProvider`. |
| Category scope | `lib/features/front_agent/model/front_conversation.dart` | A user turn's payload may carry `categoryIds` (`frontCategoriesKey`). The workflow reads it as `chosenCategoryIds` and narrows her allow-list with `frontNarrowedCategories`. |

Two findings shape the plan:

- **The read side of the category scope is already built; the write side is
  not.** `FrontAgentWorkflow` and `FrontDoorWalker` read `categoryIds` from the
  turn's payload, but `FrontChatService.sendMessage` and `appendMessage` take
  only `text` and `conversationId`. A search for `frontCategoriesKey` finds no
  writer. The composer chip is therefore mostly a matter of passing a value
  through an existing seam, not a new mechanism.
- **`FrontConversation` has no category.** The drawer's coloured squares and
  the category filter need one, derived from the conversation's turns.

## Decisions to confirm before building

Each has a default the plan assumes; change any of them and only the named
phase moves.

1. **One category or several?** The payload holds a set. The mockup shows a
   single choice plus "Everything". *Default:* single-select in the UI, stored
   as a set of one, so nothing in the workflow changes. (Phase 3)
2. **Where does a conversation's category live?** *Default:* nowhere new. It
   is the `categoryIds` of the conversation's newest user turn, which keeps the
   rule that a conversation has no creation record. A chat not yet begun holds
   its pick in a keep-alive provider beside the draft. (Phase 3)
3. **Does `@` in the text also set the chip?** *Default:* no. `@` keeps
   narrowing that one question, as the contract already teaches her; the chip
   is the standing scope. (Phase 3)
4. **Where does "say it again" go?** The mockup has no slot for
   `FrontVoiceButton`. *Default:* a trailing icon on the drawer's "Spoken
   answers" row. (Phase 2)
5. **Does opening the drawer cancel a live recording?** Today opening the list
   does, because the thread is unmounted. With a drawer the thread stays
   mounted. *Default:* only changing the conversation cancels; opening the
   drawer does not. This touches the behaviour fixed on
   `fix/companion-chat-recording-cutoff`, so it wants an explicit yes. (Phase 2)
6. **The per-turn cost line.** *Default:* `FrontTurnCostLine` leaves the
   thread; the drawer's "Agent internals" row shows the open conversation's
   total. (Phase 5)
7. **New visual values.** The mockup's `#2A2A2A` bubble, `#1E1E1E` drawer and
   324 px drawer width are approximations, not tokens. *Default:* bubble and
   drawer use `background.level02` / `surface.enabled`, the scrim uses
   `ModalUtils.getModalBarrierColor`, and the drawer width is a share of the
   pane (0.84, capped at the list's desktop width). The width share is a new
   layout constant and needs approval under the design-system rule. (Phase 2)

## Phases

One branch per phase, stacked, shipped as a single pull request from the head
branch. Each phase ends green: analyzer clean, formatter run, the touched
files' tests passing.

### Phase 0: Baseline

- Rebase onto `main` once `feat/companion-genui-surfaces` has merged; it
  rewrites parts of `front_chat_pane.dart`, and building on it avoids resolving
  the same file twice.
- Capture the **before** screenshots now, with the screenshot harness and the
  penguin demo world: thread, list, overflow menu, at phone and desktop sizes.
  They cannot be reconstructed later.

### Phase 1: One-row header

**Change** `front_chat_header.dart`:

- Conversation mode becomes: drawer toggle with the inbox badge, her face, her
  name, new chat, close.
- Remove the title line (`_Identity`'s subtitle, the archived glyph) and the
  overflow menu. The archived state is still said on the conversation's row in
  the drawer.
- Remove the list-page mode (back, "Chats", list actions). The drawer has its
  own top row.
- Keep `listBeside`: beside the list the row drops the toggle and new chat, as
  it does now.
- Simplify or delete `frontBandContentHeight` / `frontTitleLineHeight` if the
  header was their only reason for two heights.

**Tests** `front_chat_header_test.dart`: the five controls are present and
labelled; the title key is her name; nothing from the old overflow is in the
header; the `listBeside` variant; the 360 dp fit test still holds.

### Phase 2: The drawer

**New** `lib/features/front_agent/ui/front_chat_drawer.dart`:

- `FrontChatDrawer`: top row (search field, close-drawer glyph), a "New chat"
  row, then `FrontConversationList` as its body, then a footer.
- `FrontChatDrawerFooter`: "Spoken answers" (`FrontVoiceSwitch`, with the
  say-again icon per decision 4), "AI profile" with the current profile's name
  as its value, "Agent internals". The footer reuses the existing calls
  (`FrontProfileChoice.choose`, `AgentInternalsPanel.show`), moved out of the
  header.

**Change** `front_chat_pane.dart`:

- Phone layout becomes a `Stack`: header and thread underneath, then a scrim,
  then the drawer, slid in from the leading edge. `frontConversationListOpenProvider`
  stays the open/closed state, so `PopScope` and Escape keep working unchanged.
- The thread is no longer unmounted when the list opens. This satisfies
  stay-while-reload for free and removes a rebuild of the whole thread on every
  close.
- Tapping the scrim, picking a conversation, or starting a new chat closes the
  drawer.
- Recording: apply decision 5 in `letHerGo`.
- Desktop (`listWidth != null`) keeps the list beside the thread and gains the
  same footer, so both layouts hold the same things in the same order.

**Change** `front_conversation_list.dart`: drop the parts the drawer's top row
now owns (the list's own band and `FrontConversationListActions`, if nothing
else uses them); keep inbox row, sections, archived group and row menus.

**Motion:** `MotionDurations` / `MotionCurves` from the design system; honour
reduced motion.

**Accessibility:** the drawer is a modal region with a label; focus moves into
it on open and returns to the toggle on close; the scrim is a labelled button.

**Tests** `front_chat_drawer_test.dart`, `front_chat_pane_test.dart`,
`front_conversation_list_test.dart`: opens and closes by toggle, scrim, back
and Escape; the thread's element survives an open/close (same `State`); each
footer row calls what it should; picking a row opens that conversation and
closes the drawer; desktop shows the footer beside the thread.

### Phase 3: Category in the composer

**Model and service**

- `FrontChatService.appendMessage` / `sendMessage` take
  `Set<String> categoryIds` and write it under `frontCategoriesKey` when not
  empty. An older build ignores the key, as it does `conversationId`.
- `FrontConversation` gains `categoryIds`, filled by `FrontConversationService`
  from the newest user turn of the conversation.

**State** new `lib/features/front_agent/state/front_chat_category.dart`:

- `frontChatCategoryProvider`: the open conversation's category. It reads the
  conversation's `categoryIds`, overlaid by what the user picked since. Keep
  alive, reset on `startConversation` / `openConversation`.
- Options come from the existing `frontMentionCategoriesProvider`, so lockdown
  and her allow-list are respected without new code.
- A stored category she may no longer see shows as "Everything"; the workflow
  already refuses to widen her scope.

**Controller** `front_chat_controller.dart`: `sendText` passes the current
category to `sendMessage`, including on retry.

**UI**

- New `lib/features/front_agent/ui/front_category_chip.dart`: the chip
  (category colour square, name, chevron) and `FrontCategorySheet`, a modal
  sheet with one row per category plus "Everything", a check on the current
  one, and the two explanatory lines from the mockup.
- `DesignSystemChatInput` and `AgentChatView` gain a `leadingActions` slot (a
  list of widgets beside the attach button) rather than knowing about
  categories. The front chat passes the chip; other chats pass nothing.
- `composerHelper` is no longer set by the front chat. `frontChatMentionHint`
  moves into the sheet's footnote.

**Tests**

- Service: the payload carries the ids; an empty set writes no key.
- Conversation service: the conversation's category follows its newest turn.
- Provider: pick, reset on new chat, fallback when the category is gone.
- Controller: `sendText` and retry both pass the category. Note the mocktail
  rule: every existing `when(() => service.sendMessage(...))` needs
  `any(named: 'categoryIds')` once the parameter exists.
- Chip and sheet: selection, semantics, the "Everything" row.
- An end-to-end widget test: pick a category, send, and assert the stored
  turn's `categoryIds`.

### Phase 4: Category in the drawer

- Each conversation row leads with its category's colour square; an outlined
  square for none. Colour never stands alone: the row's semantics name the
  category.
- A "Categories" section above the history lists the categories that have at
  least one conversation, with counts. Tapping one filters the history
  (`frontConversationCategoryFilterProvider`, cleared with the search); tapping
  it again clears it.
- A conversation waiting on the user keeps its existing "waiting" mark.

**Tests** `front_conversation_list_test.dart`: the square's colour and
semantic label per row; the filter narrows and clears; counts follow the index.

### Phase 5: Thread declutter

- Remove `FrontTurnCostLine` from the thread and show the conversation's total
  on the drawer's "Agent internals" row (decision 6). If no per-conversation
  total is exposed yet, add a small provider over what the cost line already
  reads rather than recomputing.
- User bubble and reply spacing to the mockup, using design-system spacing and
  type tokens only. This is in `AgentChatView`'s conversational styling, so
  check that the goal and person chats, which share it, are meant to change
  too; if not, make it a parameter.
- Delete what is now unused: old header keys, the list-page header strings,
  `frontVoiceMenuItem` if the footer row replaced its only caller.

### Phase 6: Strings, docs, proof

- **Localization.** New labels (drawer open/close, "Categories",
  "Spoken answers", the sheet's title and two lines, "Everything") go into
  every catalog in `lib/l10n/`, translated, in the register the localization
  concept sets per language. Then `make l10n` and `make sort_arb_files`.
- **Knowledge.** Update `knowledge/features/front_agent.md` (header, drawer,
  category scope, with a state diagram for the drawer and the category
  provider) and `lib/features/front_agent/README.md`. Run
  `make knowledge_check`.
- **Screenshots.** After shots for the same surfaces as phase 0, plus the
  drawer and the category sheet, published with the before set and linked from
  the pull request. No images in the repository.
- **Changelog.** One fragment,
  `changelog.d/2026-11-11-companion-chat-sidecar.md`, under `### Changed`.
- **Checks before the first push.** Whole-project analyze, `make layer_check`,
  the file-size ratchet, and the extra validators the CI analyze job runs.

## Risks

- **Shared composer.** `DesignSystemChatInput` serves every chat. The new slot
  must default to empty so the others are unchanged; their tests are the guard.
- **Category chips in old builds.** A device on an older build will not show or
  honour the scope of a turn written by a newer one. It ignores the key, so
  nothing breaks, but her answer there is unscoped.
- **The GenUI branch.** Until it merges, any work on `front_chat_pane.dart`
  will conflict with it.
- **Recording.** Decision 5 changes when a take is cancelled. Whichever way it
  goes, it needs its own regression test, run once with the change reverted.

## Out of scope

- Making the chat the app's default surface and removing the close button.
- Directions E and F from the canvas (category-coloured composer, right-hand
  panel).
- Multi-category scopes in the UI.
