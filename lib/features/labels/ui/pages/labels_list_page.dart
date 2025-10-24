import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';
import 'package:lotti/features/labels/ui/widgets/label_editor_sheet.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/search/index.dart';

class LabelsListPage extends ConsumerStatefulWidget {
  const LabelsListPage({super.key});

  @override
  ConsumerState<LabelsListPage> createState() => _LabelsListPageState();
}

class _LabelsListPageState extends ConsumerState<LabelsListPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labelsAsync = ref.watch(labelsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Labels'),
      ),
      body: labelsAsync.when(
        data: (labels) => _buildContent(context, labels),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildErrorState(context, error),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openEditor,
        tooltip: 'Create label',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<LabelDefinition> labels,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: LottiSearchBar(
            controller: _searchController,
            hintText: 'Search labels…',
            onChanged: (value) => setState(() {
              _searchQuery = value.trim().toLowerCase();
            }),
            onClear: () => setState(() {
              _searchQuery = '';
            }),
          ),
        ),
        Expanded(
          child: _buildLabelsList(context, labels),
        ),
      ],
    );
  }

  Widget _buildLabelsList(
    BuildContext context,
    List<LabelDefinition> labels,
  ) {
    final filtered = labels.where((label) {
      if (_searchQuery.isEmpty) return true;
      return label.name.toLowerCase().contains(_searchQuery) ||
          (label.description?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.label_outline,
                size: 64,
                color: Theme.of(context).disabledColor,
              ),
              const SizedBox(height: 16),
              Text(
                'No labels yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).disabledColor,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the + button to create your first label.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).disabledColor,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final label = filtered[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _LabelListCard(
            label: label,
            onEdit: () => _openEditor(label: label),
            onDelete: () => _confirmDelete(label),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load labels',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor({LabelDefinition? label}) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showModalBottomSheet<LabelDefinition>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => LabelEditorSheet(label: label),
    );

    if (!mounted || result == null) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          label == null ? 'Label created successfully' : 'Label updated',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(LabelDefinition label) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete label'),
        content: Text(
          'Are you sure you want to delete "${label.name}"? Tasks with this label will lose the assignment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final controller = ref.read(labelsListControllerProvider.notifier);

    await controller.deleteLabel(label.id);

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Label "${label.name}" deleted')),
    );
  }
}

class _LabelListCard extends StatelessWidget {
  const _LabelListCard({
    required this.label,
    required this.onEdit,
    required this.onDelete,
  });

  final LabelDefinition label;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = colorFromCssHex(label.color, substitute: Colors.blue);
    final isPrivate = label.private ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _LabelColorIndicator(color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label.name,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                      if (isPrivate)
                        Icon(
                          Icons.lock_outline,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  ),
                  if (label.description != null &&
                      label.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      label.description!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: LabelChip(label: label),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Edit'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Delete'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelColorIndicator extends StatelessWidget {
  const _LabelColorIndicator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            color,
            color.withAlpha((0.75 * 255).round()),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha((0.35 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}
