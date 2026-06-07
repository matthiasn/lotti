import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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
  const InsightsSidebarEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return ValueListenableBuilder<bool>(
      valueListenable: getIt<NavService>().desktopShowTimeAnalysis,
      builder: (context, active, _) {
        return Padding(
          padding: EdgeInsets.only(top: tokens.spacing.step1),
          child: Material(
            color: active ? tokens.colors.surface.selected : Colors.transparent,
            borderRadius: BorderRadius.circular(tokens.radii.s),
            child: InkWell(
              onTap: () => beamToNamed('/calendar/time'),
              borderRadius: BorderRadius.circular(tokens.radii.s),
              hoverColor: tokens.colors.surface.hover,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step3,
                  vertical: tokens.spacing.step2,
                ),
                child: Row(
                  children: [
                    Icon(
                      active
                          ? Icons.bar_chart_rounded
                          : Icons.bar_chart_outlined,
                      size: tokens.spacing.step5,
                      color: active
                          ? tokens.colors.text.highEmphasis
                          : tokens.colors.text.mediumEmphasis,
                    ),
                    SizedBox(width: tokens.spacing.step3),
                    Expanded(
                      child: Text(
                        context.messages.insightsTimeAnalysisTitle,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: active
                              ? tokens.colors.text.highEmphasis
                              : tokens.colors.text.mediumEmphasis,
                          fontWeight: active
                              ? tokens.typography.weight.semiBold
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
