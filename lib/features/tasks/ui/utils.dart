import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';

/// Returns the [IconData] that represents [status] in the UI.
///
/// Kept here so both the status chip and the selection modal use the same
/// icons without duplication.
IconData taskIconFromStatusString(String status) => switch (status) {
  'OPEN' => Icons.radio_button_unchecked,
  'GROOMED' => Icons.edit_outlined,
  'IN PROGRESS' => Icons.play_arrow_rounded,
  'BLOCKED' => Icons.warning_sharp,
  'ON HOLD' => Icons.pause,
  'DONE' => Icons.check_circle_outline,
  'REJECTED' => Icons.close_rounded,
  String() => Icons.help_outline,
};

Color taskColorFromStatusString(String status, {Brightness? brightness}) {
  final isLight = brightness == Brightness.light;
  return switch (status) {
    'OPEN' => isLight ? taskIconColorDarkGrey : taskIconColorGrey,
    'GROOMED' => isLight ? taskIconColorDarkBlue : taskIconColorBlue,
    'IN PROGRESS' => isLight ? taskIconColorDarkBlue : taskIconColorBlue,
    'BLOCKED' => isLight ? taskIconColorDarkRed : taskIconColorRed,
    'ON HOLD' => isLight ? taskIconColorDarkOrange : taskIconColorOrange,
    'DONE' => isLight ? taskIconColorDarkGreen : taskIconColorGreen,
    'REJECTED' => isLight ? taskIconColorDarkRed : taskIconColorRed,
    String() => isLight ? taskIconColorDarkGrey : taskIconColorGrey,
  };
}

String taskLabelFromStatusString(
  String status,
  BuildContext context,
) => switch (status) {
  'OPEN' => context.messages.taskStatusOpen,
  'GROOMED' => context.messages.taskStatusGroomed,
  'IN PROGRESS' => context.messages.taskStatusInProgress,
  'BLOCKED' => context.messages.taskStatusBlocked,
  'ON HOLD' => context.messages.taskStatusOnHold,
  'DONE' => context.messages.taskStatusDone,
  'REJECTED' => context.messages.taskStatusRejected,
  String() => '-',
};

const allTaskStatuses = [
  'OPEN',
  'GROOMED',
  'IN PROGRESS',
  'BLOCKED',
  'ON HOLD',
  'DONE',
  'REJECTED',
];

/// Task statuses that are considered "open" (not completed/rejected).
/// Used for filtering linkable tasks in task linking UI.
const openTaskStatuses = [
  'OPEN',
  'GROOMED',
  'IN PROGRESS',
  'BLOCKED',
  'ON HOLD',
];
