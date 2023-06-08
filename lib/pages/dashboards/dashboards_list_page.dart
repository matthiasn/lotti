import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/dashboards/dashboards_page_cubit.dart';
import 'package:lotti/widgets/dashboards/dashboards_app_bar.dart';
import 'package:lotti/widgets/dashboards/dashboards_list.dart';

class DashboardsListPage extends StatelessWidget {
  const DashboardsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DashboardsPageCubit>(
      create: (BuildContext context) => DashboardsPageCubit(),
      child: const Scaffold(
        body: CustomScrollView(
          slivers: <Widget>[
            DashboardsSliverAppBar(),
            DashboardsList(),
          ],
        ),
      ),
    );
  }
}
