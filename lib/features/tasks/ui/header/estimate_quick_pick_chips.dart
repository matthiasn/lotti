import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/chips/duration_quick_pick_chips.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/tasks/state/task_estimate_suggestions_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The estimate picker's one-tap row: the durations this user estimates in
/// most, as chips above the duration wheel — [DurationQuickPickChips] fed
/// by [taskEstimateSuggestionsControllerProvider], reading in the compact
/// form the task header reads back.
///
/// No "+ Other" chip: the wheel is directly beneath, and a second route to
/// it would be noise. The chip matching the value on show reads selected,
/// so the row doubles as the read-out of what is about to be replaced.
class EstimateQuickPickChips extends ConsumerWidget {
  const EstimateQuickPickChips({
    required this.currentEstimate,
    required this.onPick,
    super.key,
  });

  final Duration currentEstimate;
  final ValueChanged<Duration> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    return DurationQuickPickChips(
      suggestions: ref.watch(taskEstimateSuggestionsControllerProvider).value,
      placeholder: kDefaultEstimateSuggestions,
      current: currentEstimate,
      onPick: onPick,
      hint: messages.taskEstimateQuickPickHint,
      labelOf: formatRangeDuration,
      semanticsLabelOf: messages.taskEstimateQuickPickSemanticsLabel,
      keyPrefix: 'estimate-quick-pick',
    );
  }
}
