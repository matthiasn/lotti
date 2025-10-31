import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_editor_sheet.dart';
import 'package:lotti/utils/color.dart';

/// Modern label selection content intended to be embedded inside the
/// shared Wolt modal (see ModalUtils) to match the Category selection
/// look and feel. It exposes an `apply()` method to persist selection
/// via an external controller.
class LabelSelectionModalContent extends ConsumerStatefulWidget {
  const LabelSelectionModalContent({
    required this.taskId,
    required this.initialLabelIds,
    required this.applyController,
    required this.searchQuery,
    this.categoryId,
    super.key,
  });

  final String taskId;
  final List<String> initialLabelIds;
  final String? categoryId;
  final ValueNotifier<Future<bool> Function()?> applyController;
  final ValueListenable<String> searchQuery;

  @override
  ConsumerState<LabelSelectionModalContent> createState() =>
      _LabelSelectionModalContentState();
}

class _LabelSelectionModalContentState
    extends ConsumerState<LabelSelectionModalContent> {
  late final Set<String> _selectedLabelIds = widget.initialLabelIds.toSet();
  String _searchRaw = '';
  String _searchLower = '';

  @override
  void initState() {
    super.initState();
    widget.applyController.value = apply;
  }

  Future<bool> apply() async {
    final repository = ref.read(labelsRepositoryProvider);
    final ids = _selectedLabelIds.toList();
    final result = await repository.setLabels(
      journalEntityId: widget.taskId,
      labelIds: ids,
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final categoryId = widget.categoryId;
    final available = ref.watch(
      availableLabelsForCategoryProvider(categoryId),
    );

    return ValueListenableBuilder<String>(
      valueListenable: widget.searchQuery,
      builder: (context, query, _) {
        _searchRaw = query;
        _searchLower = query.trim().toLowerCase();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildList(context, available),
          ],
        );
      },
    );
  }

  Widget _buildList(BuildContext context, List<LabelDefinition> labels) {
    final filtered = labels.where((label) {
      if (_searchLower.isEmpty) {
        return true;
      }
      return label.name.toLowerCase().contains(_searchLower) ||
          (label.description?.toLowerCase().contains(_searchLower) ?? false);
    }).toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    if (filtered.isEmpty) {
      final hasQuery = _searchRaw.trim().isNotEmpty;
      return _EmptyState(
        isSearching: hasQuery,
        searchQuery: hasQuery ? _searchRaw.trim() : null,
        onCreateLabel: () => _openLabelCreator(defaultName: _searchRaw.trim()),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (context, __) => Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
      ),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
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
