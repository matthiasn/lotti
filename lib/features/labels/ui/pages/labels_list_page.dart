import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/cards/index.dart';
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
        onPressed: () => beamToNamed('/settings/labels/create'),
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
                  onPressed: () {
                    final encoded = Uri.encodeComponent(query);
                    beamToNamed('/settings/labels/create?name=$encoded');
                  },
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
}

class _LabelListCard extends StatelessWidget {
  const _LabelListCard({
    required this.label,
    required this.usageCount,
  });

  final LabelDefinition label;
  final int usageCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrivate = label.private ?? false;
    final description = label.description?.trim();
    final cache = getIt<EntitiesCacheService>();

    final ids = label.applicableCategoryIds;
    final List<CategoryDefinition> categories;
    if (ids == null || ids.isEmpty) {
      categories = <CategoryDefinition>[];
    } else {
      categories = ids
          .map(cache.getCategoryById)
          .whereType<CategoryDefinition>()
          .toList()
        ..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }

    return ModernBaseCard(
      onTap: () => beamToNamed('/settings/labels/${label.id}'),
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(
          label.name,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
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
            if (categories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final cat in categories) _CategoryPill(category: cat),
                  ],
                ),
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
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurfaceVariant,
        ),
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
