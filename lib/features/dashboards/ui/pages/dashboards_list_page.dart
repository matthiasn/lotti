import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/dashboards/dashboards_page_cubit.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboards_app_bar.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboards_list.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';

class DashboardsListPage extends StatefulWidget {
  const DashboardsListPage({super.key});

  @override
  State<DashboardsListPage> createState() => _DashboardsListPageState();
}

class _DashboardsListPageState extends State<DashboardsListPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    final listener = getIt<UserActivityService>().updateActivity;
    _scrollController.addListener(listener);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DashboardsPageCubit>(
      create: (BuildContext context) => DashboardsPageCubit(),
      child: Scaffold(
        body: CustomScrollView(
          controller: _scrollController,
          slivers: const <Widget>[
            DashboardsSliverAppBar(),
            DashboardsList(),
          ],
        ),
      ),
    );
  }
}
