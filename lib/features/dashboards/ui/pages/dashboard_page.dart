import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboard_widget.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({
    required this.dashboardId,
    super.key,
  });

  final String dashboardId;

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int timeSpanDays = 90;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(getIt<UserActivityService>().updateActivity);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(getIt<UserActivityService>().updateActivity)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = getIt<EntitiesCacheService>().getDashboardById(
      widget.dashboardId,
    );

    if (dashboard == null) {
      beamToNamed('/dashboards');
      return EmptyScaffoldWithTitle(
        context.messages.dashboardNotFound,
      );
    }

    final tokens = context.designTokens;
    final isDesktop = isDesktopLayout(context);

    final rangeStart = DateTime.now()
        .subtract(Duration(days: timeSpanDays))
        .dayAtMidnight;
    final rangeEnd = DateTime.now().dayAtMidnight.add(
      const Duration(hours: 23, minutes: 59, seconds: 59),
    );

    final bottomClearance = DesignSystemBottomNavigationBar.occupiedHeight(
      context,
    );

    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Stable, pinned header: the title and the time-span picker never
            // collapse or scroll away — only the charts scroll beneath them.
            _DashboardHeader(
              title: dashboard.name,
              isDesktop: isDesktop,
              timeSpanDays: timeSpanDays,
              onValueChanged: (value) => setState(() => timeSpanDays = value),
              onEditDefinition: () =>
                  beamToNamed('/settings/dashboards/${widget.dashboardId}'),
            ),
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverPadding(
                    // Same step5 gutter as the dashboards list; the last card
                    // clears the bottom navigation bar.
                    padding: EdgeInsets.fromLTRB(
                      tokens.spacing.step5,
                      0,
                      tokens.spacing.step5,
                      bottomClearance + tokens.spacing.sectionGap,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: DashboardWidget(
                        rangeStart: rangeStart,
                        rangeEnd: rangeEnd,
                        dashboardId: widget.dashboardId,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stable, non-collapsing header for a dashboard. On desktop the title and the
/// time-span picker share one row (no back button — the dashboards list is
/// always visible beside this pane). On mobile the title sits above the picker
/// in a compact, back-navigable block. The title font is fixed at every scroll
/// offset.
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.title,
    required this.isDesktop,
    required this.timeSpanDays,
    required this.onValueChanged,
    required this.onEditDefinition,
  });

  final String title;
  final bool isDesktop;
  final int timeSpanDays;
  final void Function(int) onValueChanged;

  /// Opens the dashboard's definition (the settings editor for this dashboard).
  final VoidCallback onEditDefinition;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final titleStyle = tokens.typography.styles.heading.heading3.copyWith(
      color: tokens.colors.text.highEmphasis,
    );
    final picker = TimeSpanSegmentedControl(
      timeSpanDays: timeSpanDays,
      onValueChanged: onValueChanged,
    );
    final editButton = IconButton(
      tooltip: context.messages.settingsDashboardDetailsLabel,
      onPressed: onEditDefinition,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        Icons.tune_rounded,
        size: tokens.spacing.step6,
        color: tokens.colors.text.mediumEmphasis,
      ),
    );

    if (isDesktop) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.step5,
          tokens.spacing.step5,
          tokens.spacing.step5,
          tokens.spacing.step4,
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: titleStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  editButton,
                ],
              ),
            ),
            SizedBox(width: tokens.spacing.step4),
            picker,
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step2,
        tokens.spacing.step2,
        tokens.spacing.step5,
        tokens.spacing.step3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const BackWidget(),
              Expanded(
                child: Text(
                  title,
                  style: titleStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              editButton,
            ],
          ),
          SizedBox(height: tokens.spacing.step3),
          Padding(
            padding: EdgeInsets.only(left: tokens.spacing.step3),
            child: picker,
          ),
        ],
      ),
    );
  }
}
