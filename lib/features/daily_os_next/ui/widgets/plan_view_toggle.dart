import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Which of the two read-only projections of the plan is currently
/// being shown.
enum PlanView { agenda, day }

/// Pill-shaped segmented control that swaps between the Agenda
/// (intent) and Day (mechanics) projections. Mirrors the toggle in
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
    final tokens = context.designTokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleItem(
            label: context.messages.dailyOsNextPlanViewAgenda,
            isSelected: selected == PlanView.agenda,
            onTap: () => onChanged(PlanView.agenda),
          ),
          _ToggleItem(
            label: context.messages.dailyOsNextPlanViewDay,
            isSelected: selected == PlanView.day,
            onTap: () => onChanged(PlanView.day),
          ),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  const _ToggleItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step4,
          vertical: tokens.spacing.step2,
        ),
        decoration: BoxDecoration(
          color: isSelected ? teal.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        ),
        child: Text(
          label,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: isSelected ? teal : tokens.colors.text.mediumEmphasis,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
