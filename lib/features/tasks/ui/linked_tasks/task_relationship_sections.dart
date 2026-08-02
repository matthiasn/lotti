import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_helpers.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/state/task_link_groups_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/edit_link_type_modal.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/relationship_type_selector.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';

/// One rendered group inside [TaskRelationshipSections]: a header + its rows.
///
/// Every section is direction-specific, so its header alone says what the
/// relationship is and no row needs a per-row caption. Merged bidirectional
/// sections were tried first and lost: an inline caption ate ~40% of the row
/// width on phone, wrapped long titles to three lines, and left one decorated
/// row template alongside a plain one (design-review-panel round 4).
class _Section {
  const _Section({
    required this.title,
    required this.entries,
    this.accent,
  });

  final String title;
  final List<TaskLinkEntry> entries;

  /// Optional header accent. Only "Blocked by" uses one — it's the single
  /// relationship the task header also surfaces (as the amber "Blocked by N"
  /// chip), and without it the most consequential section rendered
  /// indistinguishably from a stray plain link.
  final Color? accent;
}

/// The [EntryLinkType] a resolved [TaskLinkKind] represents.
EntryLinkType entryLinkTypeForTaskLinkKind(TaskLinkKind kind) {
  switch (kind) {
    case TaskLinkKind.blocks:
      return EntryLinkType.blocks;
    case TaskLinkKind.followsUp:
      return EntryLinkType.followsUp;
    case TaskLinkKind.duplicates:
      return EntryLinkType.duplicates;
    case TaskLinkKind.fixes:
      return EntryLinkType.fixes;
    case TaskLinkKind.supersedes:
      return EntryLinkType.supersedes;
    case TaskLinkKind.basic:
      return EntryLinkType.basic;
  }
}

/// The typed-relationship sections on the linked-tasks card, rendered above
/// the flat plain-link list. Every relationship kind contributes up to two
/// sections — one per direction — titled with that direction's own phrase
/// ("Blocks" / "Is blocked by", "Follows up on" / "Has follow-up", …), so the
/// header states the relationship in full and every row across the whole card
/// renders from one template: status glyph, title, trailing affordance.
class TaskRelationshipSections extends ConsumerWidget {
  const TaskRelationshipSections({
    required this.taskId,
    required this.manageMode,
    super.key,
  });

  final String taskId;
  final bool manageMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typed =
        ref.watch(taskLinkGroupsControllerProvider(taskId)).value?.typed ??
        const [];
    if (typed.isEmpty) return const SizedBox.shrink();

    List<TaskLinkEntry> entriesOf(
      TaskLinkKind kind, {
      TaskLinkDirection? direction,
    }) => typed
        .where(
          (e) =>
              e.kind == kind && (direction == null || e.direction == direction),
        )
        .toList();

    // "Blocked by" leads: it's the one relationship the task header also
    // surfaces, and the one that gates whether work can start at all.
    final blockedBy = entriesOf(
      TaskLinkKind.blocks,
      direction: TaskLinkDirection.incoming,
    );
    // Accented only while something is actually blocking. A closed blocker
    // releases the dependent (ADR 0042 §4, task_blockers_controller.dart), so
    // painting the section amber once every blocker is Done makes a claim the
    // header has already retracted — on the feature's only semantic colour.
    final stillBlocked = blockedBy.any(
      (entry) => !isClosedTask(entry.task),
    );

    final sections = <_Section>[
      _Section(
        title: _directionTitle(
          context,
          TaskLinkKind.blocks,
          TaskLinkDirection.incoming,
        ),
        entries: blockedBy,
        accent: stillBlocked ? TaskShowcasePalette.warning(context) : null,
      ),
      for (final kind in const [
        TaskLinkKind.blocks,
        TaskLinkKind.followsUp,
        TaskLinkKind.duplicates,
        TaskLinkKind.fixes,
        TaskLinkKind.supersedes,
      ])
        for (final direction in TaskLinkDirection.values)
          if (!(kind == TaskLinkKind.blocks &&
              direction == TaskLinkDirection.incoming))
            _Section(
              title: _directionTitle(context, kind, direction),
              entries: entriesOf(kind, direction: direction),
            ),
    ].where((s) => s.entries.isNotEmpty).toList();

    final children = <Widget>[];
    for (var s = 0; s < sections.length; s++) {
      if (s > 0) {
        children.add(
          const DesignSystemDivider(),
        );
      }
      children.add(
        LinkedTaskSectionHeader(
          title: sections[s].title,
          accent: sections[s].accent,
          tightTop: s == 0,
        ),
      );
      for (final entry in sections[s].entries) {
        children.add(
          LinkedTaskRow(
            data: LinkedTaskRowData(task: entry.task),
            manageMode: manageMode,
            onEdit: () => EditLinkTypeModal.show(
              context: context,
              linkId: entry.linkId,
              currentType: entryLinkTypeForTaskLinkKind(entry.kind),
              currentDirection: entry.direction,
              linkedTaskTitle: entry.task.data.title,
            ),
            onUnlink: () {
              final fromId = entry.direction == TaskLinkDirection.outgoing
                  ? taskId
                  : entry.task.meta.id;
              final toId = entry.direction == TaskLinkDirection.outgoing
                  ? entry.task.meta.id
                  : taskId;
              return ref
                  .read(journalRepositoryProvider)
                  .removeTypedLink(
                    fromId: fromId,
                    toId: toId,
                    linkType: taskLinkKindDbType(entry.kind),
                  );
            },
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// Section title for one direction of a relationship kind — the very phrase
/// the picker offered for it, so the card reads back exactly the words the
/// user chose. One source, one grammatical form, no hand-written variants.
String _directionTitle(
  BuildContext context,
  TaskLinkKind kind,
  TaskLinkDirection direction,
) {
  final pair = relationshipPhrasePair(
    context,
    entryLinkTypeForTaskLinkKind(kind),
  )!;
  return direction == TaskLinkDirection.outgoing ? pair.$1 : pair.$2;
}

/// Shared section-header caption for the linked-tasks card — used both by the
/// typed-relationship sections here and by the flat/plain-link section in
/// `LinkedTasksWidget`, so a plain link is never left to read as an unlabeled
/// continuation of the typed section above it.
class LinkedTaskSectionHeader extends StatelessWidget {
  const LinkedTaskSectionHeader({
    required this.title,
    this.accent,
    this.tightTop = false,
    this.leadingRailWidth,
    super.key,
  });

  final String title;

  /// Set on the first section, which follows the card header's own bottom
  /// padding — without it the two stack into the largest gap on the card.
  /// Trims the top inset to a hairline so the first label sits under the card
  /// title rather than floating between it and the first row.
  final bool tightTop;

  /// Tints the label and adds a leading glyph. Deliberately the only colour
  /// on the card: rows stay neutral so a single accented header reads as
  /// signal rather than as one more competing hue.
  final Color? accent;

  /// Width of the reserved glyph column. Defaults to the card's own leading
  /// rail; the picker sheets reserve a wider one, and without matching it the
  /// header sits left of the rows it labels instead of on their edge.
  final double? leadingRailWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = this.accent;
    final label = Text(
      title,
      // Long localized phrases ("Is superseded by" and its translations) must
      // ellipsize rather than overflow once the glyph column and both step5
      // insets are taken off a phone-width card.
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      // Overline, not caption+w600: its tracking is what distinguishes a
      // section eyebrow from row metadata at the same size, and it removes an
      // off-ramp weight override. Medium, not high: the titles beneath own the
      // card's brightest ink, and three roles tied at #FFFFFF read as one flat
      // plane no matter how the sizes rank.
      // Never the accent: the ⊘ glyph beside it already carries the blocked
      // semantic in a shape no status glyph uses, and amber text here sits a
      // hue apart from an On Hold row's own orange — close enough to read as
      // the same thing while meaning something else.
      style: tokens.typography.styles.others.overline.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        // Bound to the rows below it, not floated between two sections, and
        // only just: the gap below the label is the step1 here plus the row's
        // own step3 top padding, so a step4 above clears it by the smallest
        // margin that still groups the label downward. Anything larger (this
        // was step7 between sections) stopped reading as a tighter-than-below
        // gap and started reading as empty card.
        tightTop ? tokens.spacing.step2 : tokens.spacing.step4,
        tokens.spacing.step5,
        tokens.spacing.step1,
      ),
      // The accent glyph occupies a reserved column that plain headers leave
      // empty, so every section label starts on the same left rail rather
      // than the accented one sitting alone off-grid.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: leadingRailWidth ?? tokens.spacing.step5,
            child: accent == null
                ? null
                : Icon(Icons.block, size: tokens.spacing.step5, color: accent),
          ),
          // Same gap DesignSystemListItem puts after its leading slot, so the
          // header label lands on the row title's left edge instead of near it.
          SizedBox(width: tokens.spacing.step3),
          Flexible(child: label),
        ],
      ),
    );
  }
}
