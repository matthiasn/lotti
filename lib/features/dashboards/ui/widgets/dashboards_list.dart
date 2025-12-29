import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/dashboards/state/dashboards_page_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboards_card.dart';

class DashboardsList extends ConsumerWidget {
  const DashboardsList({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredSortedDashboards =
        ref.watch(filteredSortedDashboardsProvider);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          children: [
            ...filteredSortedDashboards.mapIndexed(
              (index, dashboard) => DashboardCard(dashboard: dashboard),
            ),
          ],
        ),
      ),
    );
  }
}
