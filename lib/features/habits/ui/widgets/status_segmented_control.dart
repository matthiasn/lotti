import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// "due · later · done · all" — the redesign's status filter pill row.
///
/// Selected pill: filled with the interactive teal and dark text. Unselected
/// pills are bare text in medium-emphasis. The pill row drives
/// `HabitDisplayFilter` changes on the habits controller.
class HabitStatusSegmentedControl extends StatelessWidget {
  const HabitStatusSegmentedControl({
    required this.filter,
    required this.onValueChanged,
    super.key,
  });

  final HabitDisplayFilter filter;
  final void Function(HabitDisplayFilter?) onValueChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatusPill(
          value: HabitDisplayFilter.openNow,
          selected: filter,
          label: context.messages.habitsFilterOpenNow,
          semanticsLabel: 'Habits - due',
          onTap: onValueChanged,
        ),
        SizedBox(width: tokens.spacing.step1),
        _StatusPill(
          value: HabitDisplayFilter.pendingLater,
          selected: filter,
          label: context.messages.habitsFilterPendingLater,
          semanticsLabel: 'Habits - later',
          onTap: onValueChanged,
        ),
        SizedBox(width: tokens.spacing.step1),
        _StatusPill(
          value: HabitDisplayFilter.completed,
          selected: filter,
          label: context.messages.habitsFilterCompleted,
          semanticsLabel: 'Habits - done',
          onTap: onValueChanged,
        ),
        SizedBox(width: tokens.spacing.step1),
        _StatusPill(
          value: HabitDisplayFilter.all,
          selected: filter,
          label: context.messages.habitsFilterAll,
          semanticsLabel: 'Habits - all',
          onTap: onValueChanged,
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.value,
    required this.selected,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
  });

  final HabitDisplayFilter value;
  final HabitDisplayFilter selected;
  final String label;
  final String semanticsLabel;
  final void Function(HabitDisplayFilter?) onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isSelected = value == selected;

    final background = isSelected
        ? tokens.colors.interactive.enabled
        : Colors.transparent;
    final foreground = isSelected
        ? tokens.colors.text.onInteractiveAlert
        : tokens.colors.text.mediumEmphasis;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(value),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step3,
            vertical: tokens.spacing.step1,
          ),
          child: Text(
            label,
            semanticsLabel: semanticsLabel,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: foreground,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
