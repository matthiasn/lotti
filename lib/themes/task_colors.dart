import 'package:lotti/classes/task.dart';
import 'package:lotti/themes/colors.dart';
import 'package:material_ui/material_ui.dart';

/// The colour a task priority shows in, per brightness.
///
/// Presentation, so it lives with the palette rather than on the model:
/// `lib/classes` ranks below the shared UI layer and may not import it.
extension TaskPriorityColors on TaskPriority {
  /// Color aligned with task status theme tokens.
  Color colorForBrightness(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return switch (this) {
      TaskPriority.p0Urgent => isLight ? taskStatusDarkRed : taskStatusRed,
      TaskPriority.p1High => isLight ? taskStatusDarkOrange : taskStatusOrange,
      TaskPriority.p2Medium => isLight ? taskStatusDarkBlue : taskStatusBlue,
      TaskPriority.p3Low => Colors.grey,
    };
  }
}

/// The colour a task status shows in, per brightness.
extension TaskStatusColors on TaskStatus {
  Color colorForBrightness(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    return switch (this) {
      TaskOpen() => isLight ? taskStatusDarkOrange : taskStatusOrange,
      TaskGroomed() =>
        isLight ? taskStatusDarkGreen : taskStatusLightGreenAccent,
      TaskInProgress() => isLight ? taskStatusDarkBlue : taskStatusBlue,
      TaskBlocked() => isLight ? taskStatusDarkRed : taskStatusRed,
      TaskOnHold() => isLight ? taskStatusDarkRed : taskStatusRed,
      TaskDone() => isLight ? taskStatusDarkGreen : taskStatusGreen,
      TaskRejected() => isLight ? taskStatusDarkRed : taskStatusRed,
    };
  }
}
