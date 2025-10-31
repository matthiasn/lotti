import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';
import 'package:lotti/features/labels/ui/widgets/label_editor_sheet.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/search/index.dart';

class LabelsListPage extends ConsumerStatefulWidget {
  const LabelsListPage({super.key});

  @override
  ConsumerState<LabelsListPage> createState() => _LabelsListPageState();
}

class _LabelsListPageState extends ConsumerState<LabelsListPage> {
  final _searchController = TextEditingController();
  String _searchRaw = '';
  String _searchLower = '';

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
        title: Text(context.messages.settingsLabelsTitle),
      ),
      body: labelsAsync.when(
        data: (labels) => _buildContent(context, labels),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildErrorState(context, error),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openEditor,
        tooltip: context.messages.settingsLabelsCreateTitle,
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
            hintText: context.messages.settingsLabelsSearchHint,
            textCapitalization: TextCapitalization.words,
            onChanged: (value) => setState(() {
              _searchRaw = value;
              _searchLower = value.trim().toLowerCase();
            }),
            onClear: () => setState(() {
              _searchRaw = '';
              _searchLower = '';
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
    final usageCounts = ref.watch(labelUsageStatsProvider).maybeWhen(
          data: (value) => value,
          orElse: () => const <String, int>{},
        );
    final filtered = labels.where((label) {
      if (_searchLower.isEmpty) return true;
      return label.name.toLowerCase().contains(_searchLower) ||
          (label.description?.toLowerCase().contains(_searchLower) ?? false);
    }).toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    if (filtered.isEmpty) {
      // If user searched for something, offer to create exactly that.
      final query = _searchRaw.trim();
      if (query.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 64,
                  color: Theme.of(context).disabledColor,
                ),
                const SizedBox(height: 12),
                Text(
                  'No labels match "$query"',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => _openEditorWithInitial(query),
                  icon: const Icon(Icons.add),
                  label: Text('Create "$query" label'),
                ),
              ],
            ),
          ),
        );
      }
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
                context.messages.settingsLabelsEmptyState,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).disabledColor,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                context.messages.settingsLabelsEmptyStateHint,
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
            usageCount: usageCounts[label.id] ?? 0,
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
              context.messages.settingsLabelsErrorLoading,
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
          label == null
              ? context.messages.settingsLabelsCreateSuccess
              : context.messages.settingsLabelsUpdateSuccess,
        ),
      ),
    );
  }

  Future<void> _openEditorWithInitial(String initialName) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showModalBottomSheet<LabelDefinition>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => LabelEditorSheet(initialName: initialName),
    );

    if (!mounted || result == null) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(context.messages.settingsLabelsCreateSuccess),
      ),
    );
  }

  Future<void> _confirmDelete(LabelDefinition label) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.messages.settingsLabelsDeleteConfirmTitle),
        content: Text(
          context.messages.settingsLabelsDeleteConfirmMessage(label.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.messages.settingsLabelsDeleteCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.messages.settingsLabelsDeleteConfirmAction),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final controller = ref.read(labelsListControllerProvider.notifier);
    try {
      await controller.deleteLabel(label.id);

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.messages.settingsLabelsDeleteSuccess(label.name),
          ),
        ),
      );
    } catch (e, st) {
      // Log the error without crashing; surface feedback to the user.
      try {
        if (getIt.isRegistered<LoggingService>()) {
          getIt<LoggingService>().captureException(
            e,
            domain: 'LABELS',
            subDomain: 'deleteLabel',
            stackTrace: st,
          );
        }
      } catch (_) {
        // Swallow logging failures silently.
      }

      if (!mounted) return;
      final errText = '${context.messages.commonError}: $e';
      messenger.showSnackBar(
        SnackBar(
          content: Text(errText),
        ),
      );
    }
  }
}

class _LabelListCard extends StatelessWidget {
  const _LabelListCard({
    required this.label,
    required this.onEdit,
    required this.onDelete,
    required this.usageCount,
  });

  final LabelDefinition label;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final int usageCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrivate = label.private ?? false;
    final description = label.description?.trim();
    final cardColor = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.45 : 0.9,
    );

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: context.messages.settingsLabelsActionsTooltip,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: const Icon(Icons.edit),
                      title: Text(context.messages.editMenuTitle),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: Text(context.messages.deleteButton),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              LabelChip(label: label),
              Text(
                label.color.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              if (isPrivate) const _PrivateLabelBadge(),
            ],
          ),

          // Applicable categories (if any)
          Builder(
            builder: (_) {
              final ids = label.applicableCategoryIds;
              if (ids == null || ids.isEmpty) return const SizedBox.shrink();
              final cache = getIt<EntitiesCacheService>();
              final categories = ids
                  .map(cache.getCategoryById)
                  .whereType<CategoryDefinition>()
                  .toList()
                ..sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                );
              if (categories.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final cat in categories) _CategoryPill(category: cat),
                  ],
                ),
              );
            },
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              style: theme.textTheme.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.insights_outlined,
                size: 18,
                color: theme.colorScheme.primary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Text(
                context.messages.settingsLabelsUsageCount(usageCount),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrivateLabelBadge extends StatelessWidget {
  const _PrivateLabelBadge();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            context.messages.privateLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category});

  final CategoryDefinition category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = colorFromCssHex(
      category.color,
      substitute: theme.colorScheme.primary,
    );
    final isDark = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: Chip(
        label: Text(
          category.name,
          style: theme.textTheme.labelSmall?.copyWith(color: fg),
        ),
        backgroundColor: bg,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        // No onDeleted or onPressed -> non-interactive, no hover/ripple.
      ),
    );
  }
}
