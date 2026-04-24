import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:lotti/widgets/search/index.dart';

/// Embeddable body alias for the Settings V2 detail pane (plan
/// step 8). See `CategoriesListBody` for the polish note about the
/// duplicate header.
class LabelsListBody extends StatelessWidget {
  const LabelsListBody({super.key});

  @override
  Widget build(BuildContext context) => const LabelsListPage();
}

/// Labels list page using [DesignSystemListItem] in a grouped container.
///
/// Each label row shows a colored dot, the label name, an optional
/// description subtitle, status icons, and a chevron.
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
      body: CustomScrollView(
        slivers: [
          SettingsPageHeader(
            title: context.messages.settingsLabelsTitle,
            showBackButton: !isDesktopLayout(context),
          ),
          ...labelsAsync.when(
            data: (labels) => _buildContentSlivers(context, labels),
            loading: () => [
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (error, stackTrace) => [
              SliverFillRemaining(
                child: _buildErrorState(context, error),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: DesignSystemBottomNavigationFabPadding(
        child: FloatingActionButton(
          onPressed: () => beamToNamed('/settings/labels/create'),
          tooltip: context.messages.settingsLabelsCreateTitle,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  List<Widget> _buildContentSlivers(
    BuildContext context,
    List<LabelDefinition> labels,
  ) {
    final usageCounts = ref
        .watch(labelUsageStatsProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const <String, int>{},
        );
    final filtered =
        labels.where((label) {
          if (_searchLower.isEmpty) return true;
          return label.name.toLowerCase().contains(_searchLower) ||
              (label.description?.toLowerCase().contains(_searchLower) ??
                  false);
        }).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    return [
      SliverToBoxAdapter(
        child: Padding(
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
      ),
      if (filtered.isEmpty)
        _buildEmptySliver(context, labels.isEmpty)
      else
        SliverToBoxAdapter(
          child: DesignSystemGroupedList(
            children: [
              for (final (index, label) in filtered.indexed)
                _LabelListItem(
                  label: label,
                  usageCount: usageCounts[label.id] ?? 0,
                  showDivider: index < filtered.length - 1,
                ),
            ],
          ),
        ),
    ];
  }

  Widget _buildEmptySliver(BuildContext context, bool noLabelsAtAll) {
    final query = _searchRaw.trim();
    if (!noLabelsAtAll && query.isNotEmpty) {
      return SliverFillRemaining(
        child: Center(
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
                  context.messages.settingsLabelsNoMatchQuery(query),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () {
                    final encoded = Uri.encodeComponent(query);
                    beamToNamed('/settings/labels/create?name=$encoded');
                  },
                  icon: const Icon(Icons.add),
                  label: Text(
                    context.messages.settingsLabelsNoMatchCreate(query),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SliverFillRemaining(
      child: Center(
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
      ),
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

/// A single label row using [DesignSystemListItem].
class _LabelListItem extends StatelessWidget {
  const _LabelListItem({
    required this.label,
    required this.usageCount,
    required this.showDivider,
  });

  final LabelDefinition label;
  final int usageCount;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isPrivate = label.private ?? false;
    final description = label.description?.trim();
    final subtitle = description != null && description.isNotEmpty
        ? description
        : context.messages.settingsLabelsUsageCount(usageCount);

    return DesignSystemListItem(
      title: label.name,
      subtitle: subtitle,
      leading: _LabelColorDot(
        color: colorFromCssHex(
          label.color,
          substitute: Theme.of(context).colorScheme.primary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPrivate)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.lock_outline,
                size: 18,
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          Icon(
            Icons.chevron_right_rounded,
            size: tokens.spacing.step6,
            color: tokens.colors.text.lowEmphasis,
          ),
        ],
      ),
      showDivider: showDivider,
      dividerIndent:
          tokens.spacing.step5 +
          _LabelColorDot.containerSize +
          tokens.spacing.step3,
      onTap: () => beamToNamed('/settings/labels/${label.id}'),
    );
  }
}

/// Colored dot indicator for label leading position.
class _LabelColorDot extends StatelessWidget {
  const _LabelColorDot({required this.color});

  final Color color;

  static const double dotSize = 14;
  static const double containerSize = 36;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: containerSize,
      height: containerSize,
      child: Center(
        child: Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
