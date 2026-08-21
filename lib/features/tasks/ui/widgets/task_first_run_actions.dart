import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/assign_agent_cta_part.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/entry_creation_service.dart';

/// How far the first-run question has been answered for a task.
///
/// Three states, not two: "we do not know yet" is a real answer, and the two
/// surfaces that branch on it (`TaskForm` and `TaskDetailsPage`) have to be
/// able to tell it apart from "established". Collapsing it into either
/// boolean reflows the page a frame or two after it paints — which is what
/// creating a task looked like: the established layout (wide measure, AI card
/// with its assign CTA) rendered first, then the answer arrived and the whole
/// view narrowed, re-centred and swapped the card for the block.
enum TaskFirstRunState {
  /// The database has not answered yet. Callers must hold, not guess.
  unresolved,

  /// The task has nothing on it: no agent, no content, no linked notes.
  firstRun,

  /// The task has content of some kind.
  established,
}

/// Whether [task] should be treated as first-run, watching the two providers
/// that answer "does this task have anything on it".
///
/// **Unresolved is not blank — and it is not established either.** Both
/// providers start without a value, so reading them as `?? false` claimed "no
/// agent, no linked entries" for the frames before the database answered, and
/// a task that has both flashed the first-run offer. Reading them as
/// established instead just moves the flash onto every *new* task. Hence the
/// third state: the caller holds until the answer is real.
///
/// Two conditions deliberately resolve as [TaskFirstRunState.established]
/// rather than holding, because neither is guaranteed to ever settle: a
/// provider that failed, and a link whose target never resolves (a dangling
/// edge leaves `resolved.length` permanently short). Holding on those would
/// leave the page on its loading shell forever.
///
/// Shared by `TaskForm` and `TaskDetailsPage`, which have to agree: they
/// separately decide the block, the column measure, the compact action bar and
/// whether the AI card shows its own assign CTA.
TaskFirstRunState watchTaskFirstRunState(WidgetRef ref, Task task) {
  final id = task.meta.id;
  // A task carrying its own content is established whatever the providers
  // say, so answer before waiting on them: an agent or a linked note can only
  // ever *add* content, never take the checklist or the body text away. This
  // keeps the hold below off the path an ordinary task open takes.
  if (!TaskFirstRunActions.isBlank(task, hasAgent: false)) {
    return TaskFirstRunState.established;
  }

  final agent = ref.watch(taskAgentProvider(id));
  final links = ref.watch(linkedEntriesControllerProvider(id));
  if (agent.hasError || links.hasError) return TaskFirstRunState.established;
  if (!agent.hasValue || !links.hasValue) return TaskFirstRunState.unresolved;

  // A link is only evidence of content once its target has resolved. Until
  // then "no linked note" is a not-yet, not a fact — the same wrong-for-a-frame
  // state one level down.
  final resolved = ref.watch(resolvedOutgoingLinkedEntriesProvider(id));
  if (resolved.length < links.value!.length) {
    return TaskFirstRunState.established;
  }

  return TaskFirstRunActions.isBlank(
        task,
        hasAgent: agent.value != null,
        // Linked *tasks* are not this task's content. The page hides them from the
        // linked-entries list (`hideTaskEntries: true`) and gives them their own
        // card, and counting them made the block depend on link *direction*: this
        // controller reports outgoing links only, while the Linked Tasks card
        // resolves relationships both ways, so one relationship read as content
        // from the `fromId` end and as nothing from the `toId` end — flipping the
        // block, the page measure and the compact action bar with it.
        hasLinkedEntries: ref.watch(hasNonTaskLinkedEntriesProvider(id)),
      )
      ? TaskFirstRunState.firstRun
      : TaskFirstRunState.established;
}

/// Whether [task] is first-run *right now*, for callers that render inside a
/// page which already held until [watchTaskFirstRunState] resolved.
bool watchTaskIsFirstRun(WidgetRef ref, Task task) =>
    watchTaskFirstRunState(ref, task) == TaskFirstRunState.firstRun;

/// The "what now?" block on a task that has nothing on it yet.
///
/// A brand-new task used to render as a header, a chip lane and then roughly
/// half a screen of nothing — the empty-state review panel measured 41% of the
/// phone viewport and 44% of the desktop window as unauthored remainder, and
/// every reviewer read it the same way: as a page that had failed to load
/// rather than a task waiting to be filled in. The actions were all present,
/// but only as unlabelled glyphs in the sticky bar at the very bottom of the
/// screen, which is the last place a first-time user looks.
///
/// This block spends that space on the four things a task most often needs
/// next, worded, in the same card grammar as every other section on the page.
/// Writing leads, because typing something down is what a journaling app's
/// user came for — and it was the one path the empty page did not offer.
/// It is deliberately *not* a tutorial or a dismissible tip: each row performs
/// the action directly, and the whole block disappears the moment the task has
/// any content at all — so a returning user never sees it twice on the same
/// task.
///
/// The agent row is the same offer [AssignAgentCta] makes, folded in here so
/// an empty task shows one block instead of a card plus an orphaned CTA. When
/// this block renders, `TaskForm` suppresses the standalone CTA.
class TaskFirstRunActions extends ConsumerWidget {
  const TaskFirstRunActions({required this.task, super.key});

  final Task task;

  /// The measure the whole page adopts while this block is showing.
  ///
  /// The design system's [kActionListContentMaxWidth] — the measure for a
  /// column of worded action rows, narrower than the prose measure for the
  /// reasons documented there. `TaskDetailsPage` caps its content column to
  /// this on a first-run task so the title field, the chip lane and this block
  /// share one right edge instead of three.
  static const double maxWidth = kActionListContentMaxWidth;

  /// Whether [task] is blank enough to warrant the block: no checklists, no
  /// body text, no linked entries, and no agent attached.
  ///
  /// [hasLinkedEntries] is what retires the block after "Write a note" — that
  /// row's note lands in the linked-entries list rather than the task's own
  /// `entryText`, so without it the block kept offering a row the user had
  /// already used.
  ///
  /// Deliberately ignores the title, the status, the priority and the due
  /// date. Those are pre-filled or set from the chip lane in one tap, and a
  /// user who has only named their task still has nothing *in* it — which is
  /// precisely when the next step is worth showing.
  static bool isBlank(
    Task task, {
    required bool hasAgent,
    bool hasLinkedEntries = false,
  }) {
    if (hasAgent || hasLinkedEntries) return false;
    if ((task.data.checklistIds ?? const []).isNotEmpty) return false;
    return (task.entryText?.plainText.trim() ?? '').isEmpty;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.l);
    final rows = <Widget>[
      // First, because writing something down is what a journaling app's user
      // came to do. The page offered a voice note and a checklist and no way
      // at all to type — the body editor only renders for a task that already
      // has text (`TaskForm`), so on an empty task the plain-text path existed
      // solely behind the action bar's unlabelled "..." menu.
      _FirstRunRow(
        icon: LottiIcons.note,
        opensPicker: false,
        label: context.messages.taskFirstRunWriteNote,
        subtitle: context.messages.taskFirstRunWriteNoteHint,
        // …and then scroll to it. `createTextEntry` only navigates for an
        // *unlinked* entry; linked to a task it writes a row into the linked
        // entries below and returns. With the new note off-screen under a
        // screenful of nothing, the row read as a dead button — it could be
        // tapped repeatedly, each tap silently making another empty note.
        onTap: () async {
          final entry = await ref
              .read(entryCreationServiceProvider)
              .createTextEntry(
                linkedId: task.meta.id,
                categoryId: task.meta.categoryId,
              );
          if (entry == null) return false;
          ref
              .read(taskFocusControllerProvider(task.meta.id).notifier)
              .publishTaskFocus(entryId: entry.meta.id);
          return true;
        },
      ),
      _FirstRunRow(
        icon: LottiIcons.checkAll,
        opensPicker: false,
        label: context.messages.taskFirstRunAddChecklist,
        subtitle: context.messages.taskFirstRunAddChecklistHint,
        // No focus publish here, deliberately: the checklists section keys
        // its rows itself rather than through the page's entry-key registry,
        // so a focus intent for the new checklist id has no rendered key to
        // land on and would only spin the scroll-retry loop. The section
        // renders directly under the header, above the fold.
        onTap: () async =>
            await ref
                .read(entryCreationServiceProvider)
                .createChecklist(task: task) !=
            null,
      ),
      _FirstRunRow(
        icon: LottiIcons.mic,
        label: context.messages.taskFirstRunRecordAudio,
        // This subtitle answers the fear reviewers voiced verbatim — "does
        // tapping start recording?": the tap only opens the recorder sheet,
        // and nothing is captured until the user starts it there.
        subtitle: context.messages.taskFirstRunRecordAudioHint,
        // Opens a modal and returns; the recording (and the entry it makes)
        // happens in there. Nothing to latch off — cancelling the sheet has to
        // leave the row live.
        onTap: () async {
          ref
              .read(entryCreationServiceProvider)
              .showAudioRecordingModal(
                context,
                linkedId: task.meta.id,
                categoryId: task.meta.categoryId,
              );
          return false;
        },
      ),
      _FirstRunRow(
        icon: LottiIcons.aiSpark,
        // No colour override: `aiCard.accent` resolves to the same colour as
        // the default `interactive.enabled` in both themes, so the override
        // promised a distinction it never rendered. The sparkle glyph carries
        // the "different kind of offer" reading on its own.
        //
        // The block's own sentence-case label, not the chip's Title Case
        // one: three rows reading "Write a note / Add a checklist / Assign
        // Agent" made the third look imported from somewhere else.
        label: context.messages.taskFirstRunAssignAgent,
        // One short sentence describing what the tap does. It first named
        // the category-default alternative instead, which described a
        // different screen than the row it sat under; then it did both,
        // which made the card's most optional row its largest — and
        // truncated in German on a phone. The category route now belongs to
        // the picker this row opens. Every row now carries a subtitle like
        // this one, so the card's rhythm is 1-1-1-1 with order (not bulk)
        // carrying priority.
        subtitle: context.messages.taskAgentAssignHint,
        // Same: the picker may be dismissed without assigning anything.
        onTap: () async {
          await showAssignTaskAgentPicker(context, ref, task.meta.id);
          return false;
        },
      ),
    ];

    // Its own measure, narrower than the page's reading column. A row of a
    // few words stretched across a 960pt column puts its chevron most of a
    // screen away from its label — three horizontal rules rather than a list.
    // Non-binding on a phone, where the column is already narrower than this.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.background.level02,
          borderRadius: radius,
          border: Border.all(color: tokens.colors.decorative.level01),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                // Inset to the rows' gutter: a full-bleed rule was the one
                // element on the card that ignored the alignment system
                // everything else obeys.
                if (i > 0) DesignSystemDivider(indent: tokens.spacing.step5),
                rows[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One row of the block. A worded action with its glyph and a chevron —
/// the same anatomy the linked-tasks card's rows use, so the two cards read
/// as one component family rather than two takes on the same idea.
class _FirstRunRow extends StatefulWidget {
  const _FirstRunRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.opensPicker = true,
  });

  final IconData icon;
  final String label;

  /// One line on what the tap does. Required, not optional: a lone subtitle
  /// on one row bottom-weighted the card and read as that row mattering most,
  /// so the rhythm contract is all four rows or none.
  final String subtitle;

  /// Runs the row's action and reports whether it created content. `true`
  /// latches the row off for good — see [_FirstRunRowState._spent].
  final Future<bool> Function() onTap;

  /// Whether the tap opens a picker or modal (chevron) or creates something in
  /// place (plus). Four identical chevrons over four different behaviours told
  /// the user nothing about what a tap would do — and two of these rows retire
  /// the whole card from under the finger.
  final bool opensPicker;

  @override
  State<_FirstRunRow> createState() => _FirstRunRowState();
}

class _FirstRunRowState extends State<_FirstRunRow> {
  /// A tap is in flight. The block only retires once the write lands and the
  /// provider rebuilds, so on a slow database every tap in that window started
  /// another independent `createTextEntry` / `createChecklist` — a handful of
  /// empty notes from one impatient user. The row goes inert until its own
  /// future resolves.
  bool _pending = false;

  /// This row already created something. Retiring the block is driven by a
  /// provider rebuild, which lands some frames after the write resolves — so
  /// re-enabling on completion left a second window in which the same tap made
  /// a second note. A row that has done its job never comes back; only a failed
  /// or cancelled action re-arms it.
  bool _spent = false;

  Future<void> _handleTap() async {
    if (_pending || _spent) return;
    setState(() => _pending = true);
    var created = false;
    try {
      created = await widget.onTap();
    } finally {
      // The successful path usually unmounts this row — the task now has
      // content — so `mounted` is the common case, not the exception.
      if (mounted) {
        setState(() {
          _pending = false;
          _spent = created;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final icon = widget.icon;
    final opensPicker = widget.opensPicker;
    return DesignSystemListItem(
      onTap: _pending || _spent ? null : _handleTap,
      title: widget.label,
      titleMaxLines: 2,
      subtitle: widget.subtitle,
      subtitleMaxLines: 2,
      // No emphasis override: the component's own `text.mediumEmphasis` is
      // right. At lowEmphasis the page's single explanatory sentence was also
      // its faintest text.
      //
      // Left at the component's default `medium` size on purpose. The `small`
      // spec titles rows in `body.bodySmall` (14/w400) — the same weight as
      // body copy — so the four actions this card exists to offer would read
      // lighter than the default status chip above them. Medium carries
      // `subtitle.subtitle2` (14/w600) and a looser title/subtitle gap, which
      // is the ramp this block wants.
      leading: Icon(
        icon,
        // IconSizes.s, the list-row glyph tier — not a borrowed spacing step.
        size: IconSizes.s,
        color: tokens.colors.interactive.enabled,
      ),
      // While the row's own future is in flight the glyph gives way to a
      // small spinner: on a slow database the inert window used to look like
      // a dead button, when it is actually the re-entrancy guard protecting
      // the user from minting duplicates. A row that has DONE its job shows
      // a check until the provider rebuild retires the whole card — the
      // latch window must read as "done", never as a button that ignores
      // taps.
      trailingExtra: _pending
          ? SizedBox(
              width: IconSizes.s,
              height: IconSizes.s,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: tokens.colors.text.mediumEmphasis,
              ),
            )
          : _spent
          ? Icon(
              LottiIcons.confirm,
              size: IconSizes.s,
              color: tokens.colors.text.mediumEmphasis,
            )
          : Icon(
              // Rounded chevron, not `arrow_forward_ios`: one icon family
              // across the card and the Add sheet, with the plus and the
              // chevron at one size so the two behavioural glyphs carry
              // equal ink.
              opensPicker ? LottiIcons.chevronRight : LottiIcons.add,
              size: IconSizes.s,
              // Medium, not low: this glyph is the card's only behavioural
              // semantic — creates-in-place versus opens-a-sheet — and at
              // lowEmphasis it was the faintest ink on the card, outranked
              // by the dividers between the rows it was meant to explain.
              color: tokens.colors.text.mediumEmphasis,
            ),
    );
  }
}
