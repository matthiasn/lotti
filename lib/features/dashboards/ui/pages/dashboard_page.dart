import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/dashboards/state/dashboards_page_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboard_widget.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_definition_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/empty_scaffold.dart';
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
    // Watch (don't read once) so the header title and chart set refresh after
    // the definition is edited and saved.
    final dashboard = ref.watch(dashboardByIdProvider(widget.dashboardId));

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
              // Open the definition editor without beaming into the settings
              // tab (which looped). On desktop it slides in as a right side
              // panel that keeps the dashboard in view; on mobile it pushes
              // full-screen. Both pop back here on save/close (popOnClose).
              onEditDefinition: () {
                final editor = DashboardDefinitionPage(
                  dashboard: dashboard,
                  popOnClose: true,
                );
                Navigator.of(context, rootNavigator: true).push(
                  isDesktop
                      ? _DefinitionSidePanelRoute<void>(
                          child: editor,
                          // Names the dismissible scrim for screen readers.
                          barrierLabel: MaterialLocalizations.of(
                            context,
                          ).modalBarrierDismissLabel,
                        )
                      : MaterialPageRoute<void>(builder: (_) => editor),
                );
              },
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
              child: Text(
                title,
                style: titleStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: tokens.spacing.step4),
            picker,
            SizedBox(width: tokens.spacing.step2),
            editButton,
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

/// Right-anchored, full-height side-panel route for the dashboard definition
/// editor on desktop: the dashboard stays dimly visible behind a scrim while
/// the editor slides in from the right. Dismissed by popping (the editor's
/// back/save) or tapping the scrim. The editor fills the panel's bounded box,
/// so its own scaffold and action bar render normally.
class _DefinitionSidePanelRoute<T> extends PageRouteBuilder<T> {
  _DefinitionSidePanelRoute({
    required Widget child,
    required String barrierLabel,
  }) : super(
         opaque: false,
         barrierDismissible: true,
         barrierLabel: barrierLabel,
         barrierColor: const Color(0x66000000),
         transitionDuration: const Duration(milliseconds: 240),
         reverseTransitionDuration: const Duration(milliseconds: 200),
         pageBuilder: (context, animation, secondaryAnimation) {
           final width = (MediaQuery.sizeOf(context).width * 0.5).clamp(
             360.0,
             640.0,
           );
           return Align(
             alignment: Alignment.centerRight,
             child: SizedBox(
               width: width,
               height: double.infinity,
               child: child,
             ),
           );
         },
         transitionsBuilder: (context, animation, secondaryAnimation, child) =>
             SlideTransition(
               position:
                   Tween<Offset>(
                     begin: const Offset(1, 0),
                     end: Offset.zero,
                   ).animate(
                     CurvedAnimation(
                       parent: animation,
                       curve: Curves.easeOutCubic,
                     ),
                   ),
               child: child,
             ),
       );
}
