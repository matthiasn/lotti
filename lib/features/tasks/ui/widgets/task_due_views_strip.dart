import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_page_state.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/tasks/state/task_due_views_provider.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the due-date smart views above the task list.
@visibleForTesting
abstract final class TaskDueViewsStripKeys {
  static const Key root = Key('task-due-views-strip');
  static Key view(TaskDueFilter view) => Key('task-due-view-${view.name}');
}

/// The "Overdue" and "Due today" smart views, riding the top of the task
/// list on every layout.
///
/// Each view narrows whatever the list currently shows to its open tasks —
/// it is one more clause, not a replacement filter — and tapping it again
/// lifts that clause. They exist to answer "what is burning?" before
/// anything else is read, so they are built for a glance:
///
/// ```text
///  ┌─────────────────────┐ ┌─────────────────────┐
///  │ ▲  Overdue       3  │ │ ▦  Due today     2  │
///  └─────────────────────┘ └─────────────────────┘
///   solid error fill,        warning-ink tint,
///   on-alert ink             warning ink
/// ```
///
/// - **Two loudness steps.** Overdue is the one solid-filled pill on the
///   page; Due today is the app's tinted urgent-due shell, the same one the
///   task header's due chip escalates to. Red outranks orange by fill as well
///   as hue.
/// - **Never colour alone.** Each view carries its own glyph (warning
///   triangle, calendar) and its name, so the two stay apart for colour-blind
///   readers and in a greyscale screenshot.
/// - **Absent when empty.** A view with nothing in it is not rendered, and
///   with neither the strip takes no space — no zero badges to read past.
///   The exception is the active view: it stays, at zero, with a close glyph,
///   so finishing the last overdue task never strands the list in an empty
///   filter with no visible way out.
/// - **Counts that cannot lie.** The number is what tapping would list
///   ([taskDueViewCountsProvider]); stale-while-revalidate keeps it steady
///   through background refreshes instead of flashing.
class TaskDueViewsStrip extends ConsumerWidget {
  const TaskDueViewsStrip({super.key});

  /// Display order: the most urgent first, where the eye lands.
  static const List<TaskDueFilter> views = [
    TaskDueFilter.overdue,
    TaskDueFilter.dueToday,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final active = ref.watch(
      journalPageControllerProvider(true).select((state) => state.dueFilter),
    );
    final counts = ref.watch(taskDueViewCountsProvider).value;

    final shown = [
      for (final view in views)
        if (view == active || (counts != null && counts.of(view) > 0)) view,
    ];
    if (shown.isEmpty) {
      return const SizedBox.shrink(key: TaskDueViewsStripKeys.root);
    }

    final controller = ref.read(journalPageControllerProvider(true).notifier);
    return DetailContentWidth(
      key: TaskDueViewsStripKeys.root,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
        child: Semantics(
          container: true,
          label: context.messages.tasksDueViewsSemantics,
          child: SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: tokens.spacing.step3,
              runSpacing: tokens.spacing.step3,
              children: [
                for (final view in shown)
                  _DueViewPill(
                    key: TaskDueViewsStripKeys.view(view),
                    view: view,
                    count: counts?.of(view),
                    active: view == active,
                    onTap: () async {
                      await controller.applyBatchFilterUpdate(
                        dueFilter: view == active ? TaskDueFilter.all : view,
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DueViewPill extends StatelessWidget {
  const _DueViewPill({
    required this.view,
    required this.count,
    required this.active,
    required this.onTap,
    super.key,
  });

  final TaskDueFilter view;
  final int? count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final overdue = view == TaskDueFilter.overdue;
    final label = overdue
        ? messages.tasksDueViewOverdue
        : messages.tasksDueViewDueToday;
    // The solid pill's ink is the on-alert token; the tinted pill reads the
    // AA-safe warning ink for both its wash and its text, exactly like the
    // header's urgent due chip.
    final ink = overdue
        ? tokens.colors.text.onInteractiveAlert
        : TaskShowcasePalette.warningInk(context);
    final textStyle = tokens.typography.styles.others.caption.copyWith(
      color: ink,
      fontWeight: tokens.typography.weight.semiBold,
      height: 1,
    );
    final count = this.count;

    return Semantics(
      // Its own node: without the boundary the two views merge into the
      // group's label as a single, single-action button.
      container: true,
      button: true,
      selected: active,
      label: [
        label,
        if (count != null) messages.tasksSavedFiltersTaskCount(count),
      ].join(', '),
      onTap: onTap,
      child: ExcludeSemantics(
        child: DsPill(
          variant: overdue ? DsPillVariant.solid : DsPillVariant.tinted,
          color: overdue
              ? TaskShowcasePalette.error(context)
              : TaskShowcasePalette.warningInk(context),
          selected: active,
          leading: Icon(
            overdue ? LottiIcons.warning : LottiIcons.today,
            size: tokens.spacing.step4,
            color: ink,
          ),
          labelWidget: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count != null) Text('$count', style: textStyle),
              // The way back out, stated rather than implied: an active view
              // reads as a removable clause, like the chips below it.
              if (active) ...[
                SizedBox(width: tokens.spacing.step2),
                Icon(LottiIcons.close, size: tokens.spacing.step4, color: ink),
              ],
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
