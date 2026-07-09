import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/navigation/sidebar_subsection.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

/// Sidebar sub-entry under the Insights destination.
///
/// Highlights via [NavService.desktopShowAiImpact] (written by
/// `DashboardsLocation`, so the URL stays the single source of truth) and opens
/// the full-screen AI Impact dashboard at `/dashboards/impact`.
class ImpactSidebarEntry extends StatelessWidget {
  const ImpactSidebarEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return SidebarSubsectionSurface(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: getIt<NavService>().desktopShowAiImpact,
          builder: (context, active, _) {
            return SidebarSubsectionAction(
              label: context.messages.aiImpactTitle,
              icon: Icons.eco_outlined,
              activeIcon: Icons.eco_rounded,
              active: active,
              onTap: () => beamToNamed('/dashboards/impact'),
            );
          },
        ),
      ],
    );
  }
}
