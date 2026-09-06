import 'package:lotti/features/design_system/components/time_pickers/duration_picker_modal.dart';
import 'package:lotti/features/tasks/ui/header/estimate_quick_pick_chips.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

Future<void> showEstimatePicker({
  required BuildContext context,
  required Duration initialDuration,
  required Future<void> Function(Duration newDuration) onEstimateChanged,
}) {
  final messages = context.messages;
  return showDurationPicker(
    context: context,
    title: messages.taskEstimateModalTitle,
    initialDuration: initialDuration,
    quickPicks: (context, current, onQuickPick) =>
        EstimateQuickPickChips(currentEstimate: current, onPick: onQuickPick),
    semanticsLabelOf: (duration) =>
        '${messages.taskEstimateModalTitle}: '
        '${messages.designSystemMyDailyDurationHoursMinutesCompact(duration.inHours, duration.inMinutes.remainder(60))}',
    onDurationChanged: onEstimateChanged,
  );
}
