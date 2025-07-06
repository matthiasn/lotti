import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details_widget.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsible_task_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class CollapsibleLinkedEntriesSection extends ConsumerWidget {
  const CollapsibleLinkedEntriesSection({
    required this.task,
    required this.scrollController,
    super.key,
  });

  final Task task;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = linkedEntriesControllerProvider(id: task.id);
    final entryLinks = ref.watch(provider).valueOrNull ?? [];

    if (entryLinks.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalCount = entryLinks.length;

    // Build preview content
    final previewLines = <String>[];
    if (totalCount == 1) {
      previewLines.add('1 linked entry');
    } else {
      previewLines.add('$totalCount linked entries');
    }

    // Add entry type breakdown if we have multiple types
    // This would require fetching the actual entries to determine their types
    // For the preview, we'll keep it simple

    final includeAiEntries =
        ref.watch(includeAiEntriesControllerProvider(id: task.id));

    return CollapsibleTaskSection(
      title: context.messages.journalLinkedEntriesLabel,
      icon: MdiIcons.linkVariant,
      initiallyExpanded: false,
      collapsedChild: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              previewLines.join('\n'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (totalCount > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Tap to view all',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),
          ],
        ),
      ),
      expandedChild: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: List.generate(
            entryLinks.length,
            (int index) {
              final link = entryLinks.elementAt(index);
              final toId = link.toId;

              return EntryDetailsWidget(
                key: Key('${task.id}-$toId'),
                itemId: toId,
                popOnDelete: false,
                parentTags: task.meta.tagIds?.toSet(),
                linkedFrom: task,
                link: link,
                showAiEntry: includeAiEntries,
              );
            },
          ),
        ),
      ),
    );
  }
}
