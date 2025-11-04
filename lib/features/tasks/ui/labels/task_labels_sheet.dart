import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_editor_sheet.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';

class TaskLabelsSheet extends ConsumerStatefulWidget {
  const TaskLabelsSheet({
    required this.taskId,
    required this.initialLabelIds,
    this.categoryId,
    super.key,
  });

  final String taskId;
  final List<String> initialLabelIds;
  final String? categoryId;

  @override
  ConsumerState<TaskLabelsSheet> createState() => _TaskLabelsSheetState();
}

class _TaskLabelsSheetState extends ConsumerState<TaskLabelsSheet> {
  late final Set<String> _selectedLabelIds = widget.initialLabelIds.toSet();
  String _searchRaw = '';
  String _searchLower = '';

  @override
  Widget build(BuildContext context) {
    final categoryId = widget.categoryId;
    final available = ref.watch(
      availableLabelsForCategoryProvider(categoryId),
    );

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
                  context.messages.tasksLabelsSheetTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: context.messages.tasksLabelsSheetSearchHint,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (value) {
                    setState(() {
                      _searchRaw = value;
                      _searchLower = value.trim().toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildList(context, available)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.messages.cancelButton),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final repository = ref.read(labelsRepositoryProvider);
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          final messages = context.messages;
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
                              SnackBar(
                                content: Text(messages.tasksLabelsUpdateFailed),
                              ),
                            );
                          }
                        },
                        child: Text(context.messages.tasksLabelsSheetApply),
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
    // Union available labels with currently assigned ones to ensure
    // out-of-scope assigned labels can be unassigned.
    final cache = getIt<EntitiesCacheService>();
    final assignedDefs = widget.initialLabelIds
        .map(cache.getLabelById)
        .whereType<LabelDefinition>()
        .toList();
    final availableIds = labels.map((e) => e.id).toSet();
    final byId = <String, LabelDefinition>{
      for (final l in labels) l.id: l,
      for (final l in assignedDefs) l.id: l,
    };

    final union = byId.values.toList();

    final filtered = union.where((label) {
      if (_searchLower.isEmpty) {
        return true;
      }
      return label.name.toLowerCase().contains(_searchLower) ||
          (label.description?.toLowerCase().contains(_searchLower) ?? false);
    }).toList()
      ..sort((a, b) {
        final aAssigned = _selectedLabelIds.contains(a.id) ? 0 : 1;
        final bAssigned = _selectedLabelIds.contains(b.id) ? 0 : 1;
        final byAssigned = aAssigned.compareTo(bAssigned);
        if (byAssigned != 0) return byAssigned;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    if (filtered.isEmpty) {
      final hasQuery = _searchRaw.trim().isNotEmpty;
      return _EmptyState(
        isSearching: hasQuery,
        searchQuery: hasQuery ? _searchRaw.trim() : null,
        onCreateLabel: () => _openLabelCreator(defaultName: _searchRaw.trim()),
      );
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final label = filtered[index];
        final isSelected = _selectedLabelIds.contains(label.id);
        final outOfCategory = isSelected && !availableIds.contains(label.id);
        final color = colorFromCssHex(label.color, substitute: Colors.grey);

        return CheckboxListTile(
          value: isSelected,
          title: Text(label.name),
          subtitle: () {
            final desc = label.description?.trim();
            final note = outOfCategory ? 'Out of category' : null;
            final text = note != null && (desc != null && desc.isNotEmpty)
                ? '$note • $desc'
                : (note ?? (desc?.isNotEmpty ?? false ? desc : null));
            return text != null ? Text(text) : null;
          }(),
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
