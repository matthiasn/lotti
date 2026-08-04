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

/// Whether [task] should be treated as first-run, watching the two providers
/// that answer "does this task have anything on it".
///
/// **Unresolved is not blank.** Both providers start without a value, so
/// reading them as `?? false` claimed "no agent, no linked entries" for the
/// frames before the database answered — and a task that has both flashed the
/// first-run offer, with the page narrowed to its measure and the action bar
/// compacted, before the established UI replaced it. On a slow database that
/// wrong state is long enough to tap.
///
/// Shared by `TaskForm` and `TaskDetailsPage`, which have to agree: they
/// separately decide the block, the column measure, the compact action bar and
/// whether the AI card shows its own assign CTA.
bool watchTaskIsFirstRun(WidgetRef ref, Task task) {
  final agent = ref.watch(taskAgentProvider(task.meta.id));
  final linked = ref.watch(linkedEntriesControllerProvider(task.meta.id));
  if (!agent.hasValue || !linked.hasValue) return false;
  return TaskFirstRunActions.isBlank(
    task,
    hasAgent: agent.value != null,
    hasLinkedEntries: linked.value?.isNotEmpty ?? false,
  );
}

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
        icon: Icons.notes_rounded,
        opensPicker: false,
        label: context.messages.taskFirstRunWriteNote,
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
          if (entry == null) return;
          ref
              .read(taskFocusControllerProvider(task.meta.id).notifier)
              .publishTaskFocus(entryId: entry.meta.id);
        },
      ),
      _FirstRunRow(
        icon: Icons.checklist_rounded,
        opensPicker: false,
        label: context.messages.taskFirstRunAddChecklist,
        onTap: () async {
          await ref
              .read(entryCreationServiceProvider)
              .createChecklist(task: task);
        },
      ),
      _FirstRunRow(
        icon: Icons.mic_rounded,
        label: context.messages.taskFirstRunRecordAudio,
        // Synchronous — it pushes a modal route and returns — so there is no
        // in-flight window to guard, only the `Future<void>` signature to
        // satisfy.
        onTap: () async => ref
            .read(entryCreationServiceProvider)
            .showAudioRecordingModal(
              context,
              linkedId: task.meta.id,
              categoryId: task.meta.categoryId,
            ),
      ),
      _FirstRunRow(
        icon: Icons.auto_awesome_rounded,
        // The AI accent, the one place this palette appears on an empty
        // task, so the agent row reads as a different kind of offer from
        // the two manual ones above it.
        iconColor: tokens.colors.aiCard.accent,
        // The block's own sentence-case label, not the chip's Title Case
        // one: three rows reading "Write a note / Add a checklist / Assign
        // Agent" made the third look imported from somewhere else.
        label: context.messages.taskFirstRunAssignAgent,
        // One short sentence describing what the tap does. It first named
        // the category-default alternative instead, which described a
        // different screen than the row it sat under; then it did both,
        // which made the card's most optional row its largest — and
        // truncated in German on a phone. The category route now belongs to
        // the picker this row opens.
        subtitle: context.messages.taskAgentAssignHint,
        onTap: () => showAssignTaskAgentPicker(context, ref, task.meta.id),
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
                if (i > 0) const DesignSystemDivider(),
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
    required this.onTap,
    this.subtitle,
    this.iconColor,
    this.opensPicker = true,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? iconColor;
  final Future<void> Function() onTap;

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

  Future<void> _handleTap() async {
    if (_pending) return;
    setState(() => _pending = true);
    try {
      await widget.onTap();
    } finally {
      // The successful path usually unmounts this row — the task now has
      // content — so `mounted` is the common case, not the exception.
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final icon = widget.icon;
    final iconColor = widget.iconColor;
    final opensPicker = widget.opensPicker;
    return DesignSystemListItem(
      onTap: _pending ? null : _handleTap,
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
        size: tokens.spacing.step5,
        color: iconColor ?? tokens.colors.interactive.enabled,
      ),
      trailingExtra: Icon(
        opensPicker ? Icons.arrow_forward_ios : Icons.add_rounded,
        size: tokens.spacing.step4,
        color: tokens.colors.text.lowEmphasis,
      ),
    );
  }
}
