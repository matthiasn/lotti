---
type: Convention
title: Stay while reload
description: "A surface that has shown its content never trades it for a loading state, and never tears it down and builds it again, because its data reloads."
resource: ../../lib/features/relationships/ui/pages/relationship_details_page.dart
tags: [convention, ui, riverpod, async, loading, flicker]
status: draft
generated: { by: claude-code/opus-5.5, at: 2026-10-20T12:00:00Z }
stale_after: 2027-04-20
sources:
  - id: agents-md
    resource: ../../AGENTS.md
    title: Repository guidelines (the guardrail that links here)
    last_modified: 2026-10-20
  - id: person-page
    resource: ../../lib/features/relationships/ui/pages/relationship_details_page.dart
    title: The person page, whose flicker after a check-in this rule was written from
    last_modified: 2026-10-20
  - id: person-timeline
    resource: ../../lib/features/relationships/ui/widgets/person_timeline_view.dart
    title: The person timeline's keyed builder list, and its opened rows kept alive
    last_modified: 2026-10-24
  - id: person-contact-row
    resource: ../../lib/features/relationships/ui/widgets/person_contact_row.dart
    title: The contact row, which compares a reload's copy of the person by value
    last_modified: 2026-10-24
  - id: riverpod-async-value
    resource: https://pub.dev/documentation/riverpod/3.4.3/riverpod/AsyncValue-class.html
    title: Riverpod 3.4.3 AsyncValue — when, value, whenData, unwrapPrevious
    last_modified: 2026-10-20
---

# The rule

**Once a surface has shown its content, nothing about a reload may take that
content off the screen.** Not a spinner, not a skeleton, not an empty
placeholder, not a blank frame, and not a teardown and rebuild of the same
content. The data that is on screen stays on screen until the new data
replaces it in place.

This is a hard rule, not a preference. A loading state is allowed in exactly
two places:

- **The first load** — there is nothing to show yet.
- **A deliberate change of subject** — the user picked another day, another
  person, another route. What was on screen is no longer what they asked
  for.

A reload caused by anything else — a database notification, a sync, an agent
wake, a transcript landing, a dependency the provider watches — keeps what is
shown. Progress for that reload, where it is worth showing at all, is a local
and quiet affordance (a status line, a small inline indicator), never a
replacement for the content.

# Why

A reload is not news to the reader. Most of the app's surfaces reload many
times a minute while in use — a check-in alone writes the check-in, moves
each recording into it, lands the transcript and its summary, and wakes the
person's agent, and each write reloads the page that shows it. A surface
that blanks, folds or re-decodes on each of those does not read as "updating";
it reads as broken. The person page did exactly that after every check-in
(2026-10-20), and "felt completely broken" is the report it earned.

# Four ways to break it

## Swapping content for a loading state

In Riverpod 3.4.3, as this repository pins it:

| Read | During a reload keeps the previous data? |
|------|-------------------------------------------|
| `async.value` | **Yes**, through both refresh (`invalidate`, `invalidateSelf`) and reload (a watched dependency changed) |
| `async.when(...)` | Only on refresh. `skipLoadingOnReload` defaults to **false**, so a reload runs `loading:` |
| `switch (async) { AsyncData() => …, _ => spinner }` | Only on refresh. A reload is an `AsyncLoading` carrying the old value, and falls into the spinner |
| `async.whenData(...)` | **No.** Its loading branch is a bare `AsyncLoading` |
| `async.unwrapPrevious()` | **No**, on refresh or reload. A later `when(skipLoadingOnReload: true)` cannot bring the value back |

So the default way to read async state on a surface is `.value`, with a
loading shell only when it is null:

```dart
// Before: every reload of a watched dependency blanks the card.
return ref.watch(agentReportProvider(agentId)).when(
  data: (report) => ReportCard(report: report),
  loading: () => const DesignSystemSpinner(),
  error: (_, _) => const ReportUnavailable(),
);

// After: the shown report stays until the next one replaces it.
final async = ref.watch(agentReportProvider(agentId));
final report = async.value;
if (report == null) {
  // First load only: nothing has been shown yet.
  return async.hasError
      ? const ReportUnavailable()
      : const DesignSystemSpinner();
}
return ReportCard(report: report);
```

Where `.when` reads better, pass `skipLoadingOnReload: true`. Never reach for
`whenData` or `unwrapPrevious` on something a surface renders.

Not every loading state is a Riverpod one. A `FutureBuilder` or
`StreamBuilder` whose future or stream is created in `build` starts over in
`ConnectionState.waiting` on every rebuild; hold the future in state, and check
for data before checking `waiting`.

## Tearing the content down and building it again

The subtler break, and the one behind the person page. A reload that adds or
removes an item shifts everything after it to a new position. A list that
matches its children **by position** then finds a different widget at each
shifted index, discards the element that was there and builds a new one.
Nothing ever shows a spinner, yet every shifted child starts over: its state
resets (a card the reader opened folds, a transcript they expanded collapses),
its images resolve and decode again — and on a device, a decode that has left
the image cache paints blank and fades back in. Below a new check-in that was
the whole page.

Keys are what let a list find a child again after it moved:

- **`SliverList.builder` / `ListView.builder`** (any `SliverChildBuilderDelegate`)
  matches by index **even when the children carry keys**. Give it a
  `findChildIndexCallback` that maps each key back to its index.
- **`SliverList.list`, `SliverChildListDelegate`, `Column`, `Row`, `Stack`**
  match keyed children by key. Key every child whose presence above another
  can change.

```dart
// Before: a check-in arriving at the top moves every row down one index,
// and each is rebuilt from scratch — keys and all.
return SliverList.builder(
  itemCount: rows.length,
  itemBuilder: (context, index) =>
      TimelineRow(key: ValueKey(rows[index].id), item: rows[index]),
);

// After: each row is found again by its key, wherever it moved.
final indexOfKey = {
  for (final (index, row) in rows.indexed) ValueKey(row.id): index,
};
return SliverList.builder(
  itemCount: rows.length,
  itemBuilder: (context, index) =>
      TimelineRow(key: ValueKey(rows[index].id), item: rows[index]),
  findChildIndexCallback: (key) => indexOfKey[key],
);
```

The person page is the worked example: its timeline
([`PersonTimelineSliver`](../../lib/features/relationships/ui/widgets/person_timeline_view.dart))
looks each slot up by key, and its header and briefing blocks
([`RelationshipDetailsPage`](../../lib/features/relationships/ui/pages/relationship_details_page.dart))
each carry a `person-block-*` key, because the brief card appears above the
agent's card as soon as a check-in brings notes for next time.

Keys keep an element through a reload; they do not keep it through a scroll.
A lazy list drops the rows outside its cache extent and builds them again on
the way back, folded, so state the reader set in a row — *Show more* on a
transcript — is lost the moment they scroll far enough, and the row comes
back shorter above the viewport, which moves the history under them. A row
holding such state keeps itself alive while it holds it:
`AutomaticKeepAliveClientMixin` with `wantKeepAlive` true only while opened
(and `updateKeepAlive()` on each toggle), so folded rows are dropped as usual
and an opened one is not. The shared `FoldedWords`
(`lib/widgets/transcript/folded_words.dart`) does this, so every check-in
history — the person timeline, a goal's rail — gets it.

## Letting a row fetch what decides its height

The quietest break. A row in a lazy list that reads its own async data — a
per-row `autoDispose` provider, a `FutureBuilder` — is built without that
data every time the list builds it: the first time, after every reload that
rebuilt it, and every time it scrolls back into view, since the list drops
rows outside its cache extent and the provider is disposed with its last
listener. The row is laid out one way and changes height a frame later. Above
the viewport that forces a scroll-offset correction; below it the scroll
extent shrinks under the reader. On a long list every flick lands on rows
that then collapse, so the end keeps receding and the content keeps shifting:
the person timeline "scrolled forever" and its rows "were being replaced"
(2026-10-20).

**A row is its data.** Whatever decides a row's size is read with the page's
own load and handed down, so the first layout is the final one. The person
page reads each recording's summary line with its detail
([`getRecordingSummaries`](../../lib/features/relationships/repository/person_timeline_repository.dart))
and the timeline rows take it as a value. The same shape, from the other
side, is the Goals list, which stopped being lazy at all: its cards are heavy
and few, so it builds them whole and keeps them resident, and gates only
their animation on visibility ([goals](../features/goals.md)).

```dart
// Before: the row looks its line up; the lookup disposes with the row.
class _FoldedWordsState extends ConsumerState<FoldedWords> {
  Widget build(BuildContext context) {
    final line = ref.watch(summaryProvider(widget.audioId)).value;
    return Text(line ?? widget.transcript, maxLines: line == null ? 3 : 1);
  }
}

// After: the page read the line with its detail; the row takes it.
class FoldedWords extends StatefulWidget {
  const FoldedWords({required this.transcript, this.line});
  final String? line;
  ...
}
```

## Taking a reload's fresh copy for a change

The reload hands every widget a new object for the same data: a person read
from the database again is a new `RelationshipEntry` with a new list of the
same contact channels. A `didUpdateWidget` that compares the old and new by
identity — a plain `!=` on a `List`, a `Map`, or anything else without value
equality — sees a change on every reload, and whatever it does on a change
happens on every write: state reset, a probe started, a cache dropped. The
person page's contact row did exactly that: each reload emptied the Call,
Message and Email buttons, asked the platform again which it can service,
and filled them in a moment later — long after the rest of the page had
learned to stay put.

```dart
// Before: a new list of the same channels is "a change", on every reload.
void didUpdateWidget(PersonContactRow oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.relationship.data.contactChannels != _channels) {
    setState(() => _reachable = null);
    _resolve();
  }
}

// After: the row reacts only when the channels themselves differ.
if (!listEquals(oldWidget.relationship.data.contactChannels, _channels)) {
```

Compare by value (`listEquals`, `mapEquals`, `DeepCollectionEquality`, or the
value type's own `==`), and test it with a *fresh copy*: build the widget
twice from equal, non-identical data and assert the element and its state
survive. A `const` fixture is canonicalised and identical, so it cannot catch
this.

# Testing it

A test of this rule must observe the reload **while it is in flight** and must
be able to fail:

- Hold the refetch open with a `Completer`, trigger the reload the way
  production does (an `UpdateNotifications` event, an invalidation), pump,
  and assert the content is still there before releasing it.
- Assert the absence of the spinner the surface actually uses —
  `DesignSystemSpinner`, not Material's `CircularProgressIndicator`, which a
  page built on the design system never shows. The person page's own test
  checked the wrong one and could not fail.
- For the identity half, take the `Element` of a child below the change
  (`tester.element(find.byKey(...))`) before the reload and assert it is
  `identical` afterwards, or assert state the reader set (an expanded row)
  survives. Feed the reload *fresh copies* of unchanged data — `List.of`, not
  a `const` list — so a widget that compares by identity is caught too.
- For a row's kept state, open it, jump far enough that the lazy list drops
  it, jump back, and assert it is still open and the same height.
- For a lazy list, jump far enough that rows are dropped, jump back, and
  assert `maxScrollExtent` is the same on every frame after the jump: a row
  rebuilt at the wrong height moves it.
- Re-run the test with the fix reverted, as
  [testing conventions](testing.md#the-vacuous-pass-traps) require; an
  `AsyncLoading` carrying the previous value makes a careless assertion pass
  for free.

# Related

* [Testing conventions](testing.md) — fake time, `Completer`-held stages, and
  the vacuous-pass traps.
* [Component contracts](../features/design_system/component-contracts.md) —
  the design system's spinner and progress affordances.
