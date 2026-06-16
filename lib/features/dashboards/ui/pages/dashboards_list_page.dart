import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboard_page.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboards_filter.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboards_list.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_detail_empty_state.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

/// Extra scroll space so the last card clears the bottom navigation bar.
const double _kBottomListClearance = 120;

/// The Insights tab entry point: the scrollable list of dashboards
/// ([DashboardsList]) with a category filter in the header.
///
/// On mobile this is the whole screen. On desktop it becomes a resizable
/// master/detail layout — the list on the left, and on the right the
/// [DashboardPage] for the currently selected dashboard (tracked via
/// `NavService.desktopSelectedDashboardId`) or an empty-state prompt when none
/// is selected.
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
      // Match the Tasks list pane exactly: the app-standard near-black
      // `background.level01` (#181818). Set explicitly because the shell's
      // MaterialApp theme falls back to `Colors.black87` (a darker, off-token
      // near-black) when no Scaffold background is given.
      backgroundColor: tokens.colors.background.level01,
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

    final paneWidths = ref.watch(paneWidthControllerProvider);

    return Row(
      children: [
        SizedBox(
          width: paneWidths.listPaneWidth,
          child: listScaffold,
        ),
        ResizableDivider(
          onDrag: (delta) => ref
              .read(paneWidthControllerProvider.notifier)
              .updateListPaneWidth(delta),
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
