import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Which of the two read-only projections of the plan is currently
/// being shown.
enum PlanView { agenda, day }

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
    return DsSegmentedToggle<PlanView>(
      selected: selected,
      onChanged: onChanged,
      segments: [
        DsSegment(PlanView.agenda, context.messages.dailyOsNextPlanViewAgenda),
        DsSegment(PlanView.day, context.messages.dailyOsNextPlanViewDay),
      ],
    );
  }
}
