import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboard_page.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboards_filter.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboards_list.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_detail_empty_state.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

/// Extra scroll space so the last card clears the bottom navigation bar.
const double _kBottomListClearance = 120;

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
    final tokens = context.designTokens;

    final listScaffold = Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.step5,
                  tokens.spacing.step5,
                  tokens.spacing.step5,
                  tokens.spacing.step4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.messages.navTabTitleInsights,
                        style: tokens.typography.styles.heading.heading3
                            .copyWith(
                              color: tokens.colors.text.highEmphasis,
                            ),
                      ),
                    ),
                    const DashboardsFilter(),
                  ],
                ),
              ),
            ),
            const DashboardsList(),
            const SliverToBoxAdapter(
              child: SizedBox(height: _kBottomListClearance),
            ),
          ],
        ),
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
