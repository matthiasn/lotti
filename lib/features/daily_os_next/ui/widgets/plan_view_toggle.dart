import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

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
              icon: useIcons ? LottiIcons.list : null,
              activeIcon: useIcons ? LottiIcons.list : null,
            ),
            DsSegment(
              PlanView.day,
              context.messages.dailyOsNextPlanViewDay,
              icon: useIcons ? LottiIcons.viewRows : null,
              activeIcon: useIcons ? LottiIcons.viewRows : null,
            ),
            DsSegment(
              PlanView.activity,
              context.messages.dailyOsNextPlanViewActivity,
              icon: useIcons ? LottiIcons.timeline : null,
              activeIcon: useIcons ? LottiIcons.timeline : null,
            ),
          ],
        );
      },
    );
  }
}
