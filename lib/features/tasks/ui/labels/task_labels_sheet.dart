import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_editor_sheet.dart';
import 'package:lotti/utils/color.dart';

class TaskLabelsSheet extends ConsumerStatefulWidget {
  const TaskLabelsSheet({
    required this.taskId,
    required this.initialLabelIds,
    super.key,
  });

  final String taskId;
  final List<String> initialLabelIds;

  @override
  ConsumerState<TaskLabelsSheet> createState() => _TaskLabelsSheetState();
}

class _TaskLabelsSheetState extends ConsumerState<TaskLabelsSheet> {
  late final Set<String> _selectedLabelIds = widget.initialLabelIds.toSet();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final labelsAsync = ref.watch(labelsStreamProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Select labels',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search labels…',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim().toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: labelsAsync.when(
                  data: (labels) => _buildList(context, labels),
                  error: (error, _) => Center(child: Text(error.toString())),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final repository = ref.read(labelsRepositoryProvider);
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          final ids = _selectedLabelIds.toList();
                          final result = await repository.setLabels(
                            journalEntityId: widget.taskId,
                            labelIds: ids,
                          );
                          if (!mounted) return;
                          if (result ?? false) {
                            navigator.pop(ids);
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update labels'),
                              ),
                            );
                          }
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<LabelDefinition> labels) {
    final filtered = labels.where((label) {
      if (_searchQuery.isEmpty) {
        return true;
      }
      return label.name.toLowerCase().contains(_searchQuery) ||
          (label.description?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    if (filtered.isEmpty) {
      final hasQuery = _searchQuery.isNotEmpty;
      return _EmptyState(
        isSearching: hasQuery,
        searchQuery: hasQuery ? _searchQuery : null,
        onCreateLabel: () => _openLabelCreator(defaultName: _searchQuery),
      );
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final label = filtered[index];
        final isSelected = _selectedLabelIds.contains(label.id);
        final color = colorFromCssHex(label.color, substitute: Colors.grey);

        return CheckboxListTile(
          value: isSelected,
          title: Text(label.name),
          subtitle: label.description != null && label.description!.isNotEmpty
              ? Text(label.description!)
              : null,
          secondary: CircleAvatar(
            backgroundColor: color,
            radius: 12,
          ),
          onChanged: (checked) {
            setState(() {
              if (checked ?? false) {
                _selectedLabelIds.add(label.id);
              } else {
                _selectedLabelIds.remove(label.id);
              }
            });
          },
        );
      },
    );
  }

  Future<void> _openLabelCreator({String? defaultName}) async {
    final trimmed = defaultName?.trim();
    final initialName = (trimmed?.isEmpty ?? true) ? null : trimmed;
    final result = await showModalBottomSheet<LabelDefinition>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => LabelEditorSheet(initialName: initialName),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _selectedLabelIds.add(result.id);
    });
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.isSearching,
    required this.onCreateLabel,
    this.searchQuery,
  });

  final bool isSearching;
  final VoidCallback onCreateLabel;
  final String? searchQuery;

  @override
  Widget build(BuildContext context) {
    final querySnippet =
        searchQuery != null && searchQuery!.isNotEmpty ? '"$searchQuery"' : '';
    final message = isSearching && querySnippet.isNotEmpty
        ? 'No labels match $querySnippet.'
        : isSearching
            ? 'No labels match your search.'
            : 'No labels available yet.';
    final buttonLabel = searchQuery != null && searchQuery!.isNotEmpty
        ? 'Create $querySnippet label'
        : 'Create label';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.label_outline,
              size: 48,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreateLabel,
              icon: const Icon(Icons.add),
              label: Text(buttonLabel),
            ),
            if (searchQuery != null && searchQuery!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'A new label will be prefilled with $querySnippet',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).hintColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
