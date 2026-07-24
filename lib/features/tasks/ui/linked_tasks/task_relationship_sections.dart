import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/state/task_link_groups_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/edit_link_type_modal.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/relationship_type_selector.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

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
  /// relationship the task header also surfaces (as the amber "Waiting on X"
  /// chip), and without it the most consequential section rendered
  /// indistinguishably from a stray plain link.
  final Color? accent;
}

EntryLinkType _entryLinkTypeFor(TaskLinkKind kind) {
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
/// ("Blocked by" / "Blocks", "Follows up on" / "Has follow-up", …), so the
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

    final tokens = context.designTokens;

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
    final sections = <_Section>[
      _Section(
        title: context.messages.linkedTasksBlockedBySectionTitle,
        entries: entriesOf(
          TaskLinkKind.blocks,
          direction: TaskLinkDirection.incoming,
        ),
        accent: TaskShowcasePalette.warning(context),
      ),
      _Section(
        title: context.messages.linkedTasksBlocksSectionTitle,
        entries: entriesOf(
          TaskLinkKind.blocks,
          direction: TaskLinkDirection.outgoing,
        ),
      ),
      for (final kind in const [
        TaskLinkKind.followsUp,
        TaskLinkKind.duplicates,
        TaskLinkKind.fixes,
        TaskLinkKind.supersedes,
      ])
        for (final direction in TaskLinkDirection.values)
          _Section(
            title: _directionTitle(context, kind, direction),
            entries: entriesOf(kind, direction: direction),
          ),
    ].where((s) => s.entries.isNotEmpty).toList();

    final children = <Widget>[];
    for (var s = 0; s < sections.length; s++) {
      if (s > 0) {
        children.add(
          Divider(
            height: 1,
            thickness: 1,
            color: tokens.colors.decorative.level01,
          ),
        );
      }
      children.add(
        LinkedTaskSectionHeader(
          title: sections[s].title,
          accent: sections[s].accent,
        ),
      );
      for (final entry in sections[s].entries) {
        children.add(
          LinkedTaskRow(
            taskId: taskId,
            data: LinkedTaskRowData(task: entry.task),
            manageMode: manageMode,
            onEdit: () => EditLinkTypeModal.show(
              context: context,
              linkId: entry.linkId,
              currentType: _entryLinkTypeFor(entry.kind),
              currentDirection: entry.direction,
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

/// Section title for one direction of a relationship kind — the same phrase
/// pair the link picker's direction toggle offers, so a relationship is
/// described identically wherever it's read.
String _directionTitle(
  BuildContext context,
  TaskLinkKind kind,
  TaskLinkDirection direction,
) {
  final pair = relationshipPhrasePair(context, _entryLinkTypeFor(kind))!;
  return direction == TaskLinkDirection.outgoing ? pair.$1 : pair.$2;
}

/// Shared section-header caption for the linked-tasks card — used both by the
/// typed-relationship sections here and by the flat/plain-link section in
/// `LinkedTasksWidget`, so a plain link is never left to read as an unlabeled
/// continuation of the typed section above it.
class LinkedTaskSectionHeader extends StatelessWidget {
  const LinkedTaskSectionHeader({required this.title, this.accent, super.key});

  final String title;

  /// Tints the label and adds a leading glyph. Deliberately the only colour
  /// on the card: rows stay neutral so a single accented header reads as
  /// signal rather than as one more competing hue.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = this.accent;
    final label = Text(
      title,
      style: tokens.typography.styles.others.caption.copyWith(
        color: accent ?? tokens.colors.text.mediumEmphasis,
        fontWeight: FontWeight.w600,
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        // Bound to the rows below it, not floated between two sections.
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step1,
      ),
      child: accent == null
          ? label
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block, size: 12, color: accent),
                SizedBox(width: tokens.spacing.step2),
                label,
              ],
            ),
    );
  }
}
