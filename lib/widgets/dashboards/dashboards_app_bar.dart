import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/dashboards/dashboards_page_cubit.dart';
import 'package:lotti/blocs/dashboards/dashboards_page_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/dashboards/dashboards_filter.dart';
import 'package:lotti/widgets/settings/settings_icon.dart';

class DashboardsSliverAppBar extends StatelessWidget {
  const DashboardsSliverAppBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardsPageCubit, DashboardsPageState>(
      builder: (context, DashboardsPageState state) {
        return SliverAppBar(
          backgroundColor: styleConfig().negspace,
          expandedHeight: 50,
          primary: false,
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DashboardsFilter(),
              SettingsButton('/settings/dashboards'),
            ],
          ),
          pinned: true,
          automaticallyImplyLeading: false,
        );
      },
    );
  }
}
