import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The status filter (due / later / done / all) rendered with the shared
/// [DsSegmentedToggle] so it speaks the same visual language as the Time
/// Analysis chart-mode switch and the Daily OS plan-view toggle — instead of a
/// default-Material `SegmentedButton` with its own outline and selected-icon
/// chrome.
class HabitStatusSegmentedControl extends StatelessWidget {
  const HabitStatusSegmentedControl({
    required this.filter,
    required this.onValueChanged,
    super.key,
  });

  final HabitDisplayFilter filter;
  final void Function(HabitDisplayFilter) onValueChanged;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    return DsSegmentedToggle<HabitDisplayFilter>(
      selected: filter,
      onChanged: onValueChanged,
      segments: [
        DsSegment(HabitDisplayFilter.openNow, messages.habitsFilterOpenNow),
        DsSegment(
          HabitDisplayFilter.pendingLater,
          messages.habitsFilterPendingLater,
        ),
        DsSegment(HabitDisplayFilter.completed, messages.habitsFilterCompleted),
        DsSegment(HabitDisplayFilter.all, messages.habitsFilterAll),
      ],
    );
  }
}
