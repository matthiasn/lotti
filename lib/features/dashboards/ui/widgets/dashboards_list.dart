import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/dashboards/dashboards_page_cubit.dart';
import 'package:lotti/blocs/dashboards/dashboards_page_state.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboards_card.dart';

class DashboardsList extends StatelessWidget {
  const DashboardsList({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardsPageCubit, DashboardsPageState>(
      builder: (context, DashboardsPageState state) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              children: [
                ...state.filteredSortedDashboards.mapIndexed(
                  (index, dashboard) => DashboardCard(dashboard: dashboard),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
