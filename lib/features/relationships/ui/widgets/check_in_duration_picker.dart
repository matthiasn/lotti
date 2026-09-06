import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/chips/duration_quick_pick_chips.dart';
import 'package:lotti/features/design_system/components/time_pickers/duration_picker_modal.dart';
import 'package:lotti/features/relationships/state/check_in_duration_suggestions_controller.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The length label the check-in surfaces share: `11 min`, `1 h`, `1 h 30`,
/// and *No duration* for zero — the wheel's "none" position.
String checkInDurationLabel(BuildContext context, Duration duration) =>
    relationshipDurationLabelOf(context, duration) ??
    context.messages.checkInNoDuration;

/// The check-in duration picker's one-tap row: the lengths this user logs
/// most, ranked by [checkInDurationSuggestionsControllerProvider], above
/// the wheel.
class CheckInDurationQuickPickChips extends ConsumerWidget {
  const CheckInDurationQuickPickChips({
    required this.current,
    required this.onPick,
    super.key,
  });

  final Duration current;
  final ValueChanged<Duration> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    return DurationQuickPickChips(
      suggestions: ref
          .watch(checkInDurationSuggestionsControllerProvider)
          .value,
      placeholder: kCheckInDurationPositions
          .take(kCheckInDurationSuggestionCount)
          .toList(growable: false),
      current: current,
      onPick: onPick,
      hint: messages.checkInDurationQuickPickHint,
      labelOf: (duration) => checkInDurationLabel(context, duration),
      semanticsLabelOf: messages.checkInDurationSemanticsLabel,
      keyPrefix: 'check-in-duration-pick',
    );
  }
}

/// Opens the duration picker for a check-in (design 2026-09-06 §5): quick
/// picks over the wheel, *Clear* meaning "no duration". Resolves to the
/// chosen length, or null when the user backed out without changing it.
Future<Duration?> showCheckInDurationPicker({
  required BuildContext context,
  required Duration initialDuration,
}) async {
  final messages = context.messages;
  Duration? chosen;
  await showDurationPicker(
    context: context,
    title: messages.journalDurationLabel,
    initialDuration: initialDuration,
    quickPicks: (context, current, onQuickPick) =>
        CheckInDurationQuickPickChips(current: current, onPick: onQuickPick),
    semanticsLabelOf: (duration) =>
        '${messages.journalDurationLabel}: '
        '${checkInDurationLabel(context, duration)}',
    onDurationChanged: (duration) async => chosen = duration,
  );
  return chosen;
}
