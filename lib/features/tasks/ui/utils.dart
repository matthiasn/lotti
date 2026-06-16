import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';

/// Returns the [IconData] that represents [status] in the UI.
///
/// Kept here so both the status chip and the selection modal use the same
/// icons without duplication.
IconData taskIconFromStatusString(String status) =>
    switch (normalizeTaskStatusString(status)) {
      'OPEN' => Icons.radio_button_unchecked,
      'GROOMED' => Icons.edit_outlined,
      'IN PROGRESS' => Icons.play_arrow_rounded,
      'BLOCKED' => Icons.warning_sharp,
      'ON HOLD' => Icons.pause,
      'DONE' => Icons.check_circle_outline,
      'REJECTED' => Icons.close_rounded,
      String() => Icons.help_outline,
    };

/// Returns the theme-aware accent [Color] for [status].
///
/// Normalizes [status] via [normalizeTaskStatusString], then maps each status
/// to a colour from the shared task palette, choosing the lighter or darker
/// variant based on [brightness] (light when `Brightness.light`). Unknown
/// statuses fall back to the grey "open" colour.
Color taskColorFromStatusString(String status, {Brightness? brightness}) {
  final isLight = brightness == Brightness.light;
  return switch (normalizeTaskStatusString(status)) {
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

/// Returns the localized display label for [status].
///
/// Normalizes [status] via [normalizeTaskStatusString] and looks up the
/// matching `context.messages` string; unknown statuses yield `'-'`.
String taskLabelFromStatusString(
  String status,
  BuildContext context,
) => switch (normalizeTaskStatusString(status)) {
  'OPEN' => context.messages.taskStatusOpen,
  'GROOMED' => context.messages.taskStatusGroomed,
  'IN PROGRESS' => context.messages.taskStatusInProgress,
  'BLOCKED' => context.messages.taskStatusBlocked,
  'ON HOLD' => context.messages.taskStatusOnHold,
  'DONE' => context.messages.taskStatusDone,
  'REJECTED' => context.messages.taskStatusRejected,
  String() => '-',
};

/// Canonicalizes a raw [status] string for matching.
///
/// Trims whitespace, upper-cases, and replaces underscores with spaces, then
/// folds a few aliases: `OPENING`/`OPENED` to `OPEN` and `INPROGRESS` to
/// `IN PROGRESS`. Any other value is returned in its trimmed/upper-cased form.
String normalizeTaskStatusString(String status) {
  final normalized = status.trim().toUpperCase().replaceAll('_', ' ');
  return switch (normalized) {
    'OPENING' || 'OPENED' => 'OPEN',
    'INPROGRESS' => 'IN PROGRESS',
    _ => normalized,
  };
}

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
