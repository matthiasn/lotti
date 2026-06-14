import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/dashboards/state/dashboards_page_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboards_card.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

class DashboardsList extends ConsumerWidget {
  const DashboardsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredSortedDashboards = ref.watch(
      filteredSortedDashboardsProvider,
    );
    final tokens = context.designTokens;

    if (filteredSortedDashboards.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final borderRadius = BorderRadius.circular(tokens.radii.m);

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.colors.background.level02,
            borderRadius: borderRadius,
            border: Border.all(color: tokens.colors.decorative.level01),
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...filteredSortedDashboards.mapIndexed(
                  (index, dashboard) => DashboardCard(
                    dashboard: dashboard,
                    showDivider: index < filteredSortedDashboards.length - 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
