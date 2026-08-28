import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/ui/ai_summary_card.dart';
import 'package:lotti/features/design_system/components/motion/staggered_entrance.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/checklists_widget.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header_connector.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_tasks_widget.dart';
import 'package:lotti/features/tasks/ui/widgets/task_first_run_actions.dart';
import 'package:lotti/features/tasks/ui/widgets/viewport_stable_animated_size.dart';

/// Composes the task detail form for the task identified by [taskId].
///
/// Watches `entryControllerProvider` and, once the entry resolves to a
/// [Task], stacks (top to bottom): the [DesktopTaskHeaderConnector] header,
/// an [EditorWidget] for legacy entries that already contain rich text, the
/// [AiSummaryCard] (whose proposals can be scrolled into view via
/// [suggestionsFocusKey]), the [ChecklistsWidget], the [LinkedTasksWidget],
/// and — on a task with no content at all — [TaskFirstRunActions].
///
/// Every band a confirmed agent proposal can resize reports its geometry to
/// the task page's pre-paint scroll stabilizer, because an unreported change
/// displaces the proposals under the user's pointer for a frame before the
/// fallback anchor snaps them back:
///
/// * **header** — title, tagline and metadata; the only band above the AI
///   card, so its growth is compensated unconditionally to keep the proposals
///   still under the user's pointer
/// * **AI card** — every resolved proposal collapses its row and so shrinks
///   the card, whether it was confirmed or dismissed (both gestures run the
///   same resolve-then-collapse path), and the Confirm-all rail and the
///   section itself collapse after the last row. Whichever edge the page has
///   pinned — the card's own bottom while it is visible, the seam below the
///   work bands once it has scrolled above the viewport — sits *below* this
///   band, so its delta is absorbed unconditionally: the content under that
///   edge never moves, and the collapse is paid for by the summary above
///   sliding down into the space the rows leave.
/// * **checklist**, off-screen only — items added, checked off, archived or
///   migrated. Below the card's pinned edge, so while the card is visible its
///   growth is the visible reflow under the proposals — new content appears
///   and only what is beneath it moves; only the below-card hold absorbs it.
/// * **linked tasks**, off-screen only — `create_follow_up_task` links a new
///   task here, and the first link is a large step: two tall empty-state
///   actions plus a divider give way to one compact row while the card header
///   gains a chevron, count badge and Link button. Same below-the-card rule
///   as the checklist band.
///
/// The legacy body band is deliberately not reported: no agent tool writes the
/// task's own `entryText`, and [EditorWidget] changes height on focus and while
/// typing, which an armed hold would consume as a scroll correction.
///
/// Each reporter carries a distinct, task-scoped key. [StaggeredEntrance] maps
/// its children through `flutter_animate`, which does not forward their keys,
/// so the children are matched positionally — without distinct keys, toggling
/// the body band would let one band's render object (and its measured height
/// baseline) be reused for another and emit a bogus delta.
///
/// Renders nothing until the entry loads as a task.
class TaskForm extends ConsumerWidget {
  const TaskForm({
    required this.taskId,
    this.suggestionsFocusKey,
    this.cardRegionKey,
    this.linkedTasksRegionKey,
    this.onSuggestionResolveStart,
    super.key,
  });

  final String taskId;
  final GlobalKey? suggestionsFocusKey;

  /// Marks the AI card band so the page can measure where it sits relative to
  /// the viewport. Deliberately the reporter's own child, so the page's
  /// off-screen predicate and this band's reporting can never disagree: the
  /// seam below the card (the linked-entries sliver) sits a whole two sections
  /// lower, and in that span the card is already out of sight while the seam
  /// is not.
  final GlobalKey? cardRegionKey;

  /// Marks the linked-tasks band. Unlike the bands resized by a gesture on the
  /// card, this one can change from a background write — a follow-up task
  /// linking itself, or a sync — while the user is reading somewhere else
  /// entirely, so the page has to check where it sits before compensating it.
  final GlobalKey? linkedTasksRegionKey;

  final VoidCallback? onSuggestionResolveStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(taskId);
    final entryState = ref.watch(provider).value;
    final task = entryState?.entry;

    if (task == null || task is! Task) {
      return const SizedBox.shrink();
    }

    // only show editor for legacy entries where there is text already
    final plainText = entryState?.entry?.entryText?.plainText.trim() ?? '';
    final hasBody =
        entryState?.entry?.entryText != null && plainText.isNotEmpty;
    final tokens = context.designTokens;

    // A task with nothing on it gets the first-run block instead of half a
    // screen of nothing, and the block carries the agent offer itself — so
    // the AI card's standalone CTA stands down while it is showing.
    final isFirstRun = watchTaskIsFirstRun(ref, task);

    // Reading zones top-to-bottom: identity (header), the legacy body, the
    // AI summary, then the user's WORK (checklists + linked tasks). The AI
    // card leads the page so a reader lands on "what is this task about and
    // where does it stand" before scrolling into the work; the model
    // attribution stays inside the card's own footer — nothing renders a
    // standalone attribution strip under the title. Inter-section spacing is
    // baked into each section's leading padding so the staggered entrance
    // cascades evenly.
    return StaggeredEntrance(
      children: [
        ViewportStableSizeReporter(
          key: ValueKey('header-size-reporter-$taskId'),
          child: DesktopTaskHeaderConnector(taskId: taskId),
        ),
        if (hasBody)
          Padding(
            padding: EdgeInsets.only(top: tokens.spacing.sectionGap),
            // A faint top rule marks the body as its own band between the
            // identity header and the sections below, so they read as even,
            // anchored regions rather than one floating bullet line.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(
                  height: 1,
                  thickness: 1,
                  color: tokens.colors.decorative.level01,
                ),
                SizedBox(height: tokens.spacing.step4),
                EditorWidget(entryId: taskId, margin: EdgeInsets.zero),
              ],
            ),
          ),
        ViewportStableSizeReporter(
          key: ValueKey('ai-card-size-reporter-$taskId'),
          child: Padding(
            key: cardRegionKey,
            // A step4 top bonds the card to the identity header above it, the
            // same rhythm the header uses between its own tiers. No bottom
            // padding: the sections below (checklists step5, linked tasks
            // step3) bring their own leading gap.
            // On a first-run task the card renders nothing at all (no agent,
            // and its assign CTA is suppressed in favour of the block below),
            // so its band must not still charge the page for the gap above a
            // card that isn't there.
            padding: isFirstRun
                ? EdgeInsets.zero
                : EdgeInsets.only(top: tokens.spacing.step4),
            child: AiSummaryCard(
              taskId: taskId,
              proposalsFocusKey: suggestionsFocusKey,
              onSuggestionResolveStart: onSuggestionResolveStart,
              showAssignCta: !isFirstRun,
            ),
          ),
        ),
        // Both work bands sit BELOW the AI card, so their deltas are
        // consumed only while the page armed the below-card hold (card fully
        // above the viewport, `_belowCardAnchor` pinning the linked-entries
        // seam). While the card is visible its bottom edge is the anchor, and
        // a checklist or linked-task growing underneath it is the visible
        // reflow — compensating it would drag the proposals out from under
        // the user's pointer.
        ViewportStableSizeReporter(
          key: ValueKey('checklist-size-reporter-$taskId'),
          offscreenOnly: true,
          child: ChecklistsWidget(entryId: taskId, task: task),
        ),
        ViewportStableSizeReporter(
          key: ValueKey('linked-tasks-size-reporter-$taskId'),
          offscreenOnly: true,
          child: KeyedSubtree(
            key: linkedTasksRegionKey,
            child: LinkedTasksWidget(taskId: taskId),
          ),
        ),
        if (isFirstRun)
          Padding(
            // A full sectionGap: the block is a different register from the
            // identity header above it — what you can *do* next, rather than
            // what this task *is* — and the page has nothing else to separate
            // them with.
            padding: EdgeInsets.only(top: tokens.spacing.sectionGap),
            child: TaskFirstRunActions(task: task),
          ),
      ],
    );
  }
}
