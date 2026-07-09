import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/navigation/sidebar_subsection.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

/// Sidebar sub-entry under the Daily OS destination, beneath the month
/// calendar.
///
/// Rendered in the expanded desktop sidebar while the tab is active — the
/// same slot Tasks uses for its saved-filters tree. Highlights via
/// [NavService.desktopShowTimeAnalysis] (written by `CalendarLocation`, so
/// the URL stays the single source of truth) and opens the full-screen
/// analytics surface at `/calendar/time`.
class InsightsSidebarEntry extends StatelessWidget {
  const InsightsSidebarEntry({
    this.wrapInSurface = true,
    super.key,
  });

  final bool wrapInSurface;

  @override
  Widget build(BuildContext context) {
    final entry = ValueListenableBuilder<bool>(
      valueListenable: getIt<NavService>().desktopShowTimeAnalysis,
      builder: (context, active, _) {
        return SidebarSubsectionAction(
          label: context.messages.insightsTimeAnalysisTitle,
          icon: Icons.bar_chart_outlined,
          activeIcon: Icons.bar_chart_rounded,
          active: active,
          onTap: () => beamToNamed('/calendar/time'),
        );
      },
    );

    if (!wrapInSurface) return entry;
    return SidebarSubsectionSurface(children: [entry]);
  }
}
