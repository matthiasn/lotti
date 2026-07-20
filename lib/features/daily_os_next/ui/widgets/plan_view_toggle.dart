import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Which read-only projection of the day is currently being shown.
enum PlanView { agenda, day, activity }

/// Pill-shaped segmented control that swaps between the Agenda
/// (intent) and Day (mechanics) projections. A thin wrapper over the shared
/// [DsSegmentedToggle] so it speaks the same visual language as the Time
/// Analysis chart-mode toggle. Mirrors the toggle in
/// `prototype/screens/plan.jsx → PlanDesktop`.
class PlanViewToggle extends StatelessWidget {
  const PlanViewToggle({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final PlanView selected;
  final ValueChanged<PlanView> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useIcons =
            MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
            constraints.maxWidth < 400;
        return DsSegmentedToggle<PlanView>(
          selected: selected,
          onChanged: onChanged,
          segments: [
            DsSegment(
              PlanView.agenda,
              context.messages.dailyOsNextPlanViewAgenda,
              icon: useIcons ? Icons.view_agenda_outlined : null,
              activeIcon: useIcons ? Icons.view_agenda_rounded : null,
            ),
            DsSegment(
              PlanView.day,
              context.messages.dailyOsNextPlanViewDay,
              icon: useIcons ? Icons.calendar_view_day_outlined : null,
              activeIcon: useIcons ? Icons.calendar_view_day_rounded : null,
            ),
            DsSegment(
              PlanView.activity,
              context.messages.dailyOsNextPlanViewActivity,
              icon: useIcons ? Icons.timeline_outlined : null,
              activeIcon: useIcons ? Icons.timeline_rounded : null,
            ),
          ],
        );
      },
    );
  }
}
