import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/state/task_link_groups_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/relationship_type_selector.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// One rendered group inside [TaskRelationshipSections]: a header + its rows.
class _Section {
  const _Section({
    required this.title,
    required this.entries,
    required this.splitByDirection,
  });

  final String title;
  final List<TaskLinkEntry> entries;

  /// True for the two `blocks` sections (Blocks / Blocked by), where the
  /// section header alone disambiguates direction and rows show no per-row
  /// caption. False for the merged bidirectional sections (Follow-ups,
  /// Duplicates, Fixes, Supersedes), where each row needs its own caption
  /// since the section holds both directions.
  final bool splitByDirection;
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

/// The 6 typed-relationship sections on the linked-tasks card, rendered above
/// the existing flat plain-link list: Blocked by, Blocks (each split by
/// direction — the highest-signal relationship, feeding the header's blocked
/// chip and the status-enrichment flow), then Follow-ups, Duplicates, Fixes,
/// and Supersedes (each merged — both directions in one section, disambiguated
/// per row — so a relationship is never silently hidden just because only one
/// direction got a dedicated section).
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

    final sections = <_Section>[
      _Section(
        title: context.messages.linkedTasksBlockedBySectionTitle,
        entries: entriesOf(
          TaskLinkKind.blocks,
          direction: TaskLinkDirection.incoming,
        ),
        splitByDirection: true,
      ),
      _Section(
        title: context.messages.linkedTasksBlocksSectionTitle,
        entries: entriesOf(
          TaskLinkKind.blocks,
          direction: TaskLinkDirection.outgoing,
        ),
        splitByDirection: true,
      ),
      _Section(
        title: context.messages.linkedTasksFollowUpsSectionTitle,
        entries: entriesOf(TaskLinkKind.followsUp),
        splitByDirection: false,
      ),
      _Section(
        title: context.messages.linkedTasksDuplicatesSectionTitle,
        entries: entriesOf(TaskLinkKind.duplicates),
        splitByDirection: false,
      ),
      _Section(
        title: context.messages.linkedTasksFixesSectionTitle,
        entries: entriesOf(TaskLinkKind.fixes),
        splitByDirection: false,
      ),
      _Section(
        title: context.messages.linkedTasksSupersedesSectionTitle,
        entries: entriesOf(TaskLinkKind.supersedes),
        splitByDirection: false,
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
      children.add(_SectionHeader(title: sections[s].title));
      for (final entry in sections[s].entries) {
        children.add(
          LinkedTaskRow(
            taskId: taskId,
            data: LinkedTaskRowData(
              task: entry.task,
              direction: entry.direction == TaskLinkDirection.outgoing
                  ? LinkDirection.outgoing
                  : LinkDirection.incoming,
              caption: sections[s].splitByDirection
                  ? null
                  : _rowCaption(context, entry),
            ),
            manageMode: manageMode,
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

    return Column(children: children);
  }

  String? _rowCaption(BuildContext context, TaskLinkEntry entry) {
    final pair = relationshipPhrasePair(context, _entryLinkTypeFor(entry.kind));
    if (pair == null) return null;
    return entry.direction == TaskLinkDirection.outgoing ? pair.$1 : pair.$2;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step3,
        tokens.spacing.step5,
        tokens.spacing.step1,
      ),
      child: Text(
        title,
        style: tokens.typography.styles.others.caption.copyWith(
          color: tokens.colors.text.mediumEmphasis,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
