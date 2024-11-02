import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/dashboards/dashboards_page_cubit.dart';
import 'package:lotti/blocs/dashboards/dashboards_page_state.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboards_filter.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class DashboardsSliverAppBar extends StatelessWidget {
  const DashboardsSliverAppBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardsPageCubit, DashboardsPageState>(
      builder: (context, DashboardsPageState state) {
        return SliverAppBar(
          expandedHeight: 130,
          titleSpacing: 0,
          scrolledUnderElevation: 10,
          elevation: 10,
          actions: const [
            DashboardsFilter(),
          ],
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              context.messages.navTabTitleInsights,
              style: appBarTextStyleNewLarge.copyWith(
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          pinned: true,
          automaticallyImplyLeading: false,
        );
      },
    );
  }
}
