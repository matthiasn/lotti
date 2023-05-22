import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/dashboards/dashboards_page_cubit.dart';
import 'package:lotti/widgets/app_bar/sliver_title_bar.dart';
import 'package:lotti/widgets/dashboards/dashboards_app_bar.dart';
import 'package:lotti/widgets/dashboards/dashboards_list.dart';

class DashboardsListPage extends StatelessWidget {
  const DashboardsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocProvider<DashboardsPageCubit>(
      create: (BuildContext context) => DashboardsPageCubit(),
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverTitleBar(
                localizations.navTabTitleInsights,
                pinned: true,
              ),
              const DashboardsSliverAppBar(),
              const DashboardsList(),
            ],
          ),
        ),
      ),
    );
  }
}
