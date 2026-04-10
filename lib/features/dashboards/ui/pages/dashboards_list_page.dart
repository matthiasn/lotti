import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboard_page.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboards_app_bar.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboards_list.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_detail_empty_state.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

class DashboardsListPage extends ConsumerStatefulWidget {
  const DashboardsListPage({super.key});

  @override
  ConsumerState<DashboardsListPage> createState() => _DashboardsListPageState();
}

class _DashboardsListPageState extends ConsumerState<DashboardsListPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    final listener = getIt<UserActivityService>().updateActivity;
    _scrollController.addListener(listener);
    super.initState();
  }

  @override
  void dispose() {
    final listener = getIt<UserActivityService>().updateActivity;
    _scrollController
      ..removeListener(listener)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = isDesktopLayout(context);

    final listScaffold = Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: const <Widget>[
          DashboardsSliverAppBar(),
          DashboardsList(),
        ],
      ),
    );

    if (!isDesktop) {
      return listScaffold;
    }

    return Row(
      children: [
        SizedBox(
          width: 540,
          child: listScaffold,
        ),
        Expanded(
          child: ValueListenableBuilder<String?>(
            valueListenable: getIt<NavService>().desktopSelectedDashboardId,
            builder: (context, selectedDashboardId, _) {
              if (selectedDashboardId != null) {
                return DashboardPage(dashboardId: selectedDashboardId);
              }
              return DesktopDetailEmptyState(
                message: context.messages.desktopEmptyStateSelectDashboard,
              );
            },
          ),
        ),
      ],
    );
  }
}
