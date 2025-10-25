import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
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
      return const Center(
        child: Text('No labels match your search.'),
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
}
