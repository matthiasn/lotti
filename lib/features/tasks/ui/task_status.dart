import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/themes/theme.dart';
import 'package:tinycolor2/tinycolor2.dart';

/// A [Chip] showing the [task]'s status.
///
/// The chip's background colour comes from the status' `colorForBrightness`
/// (resolved against the current theme brightness) and its text from the
/// status' `localizedLabel`; the label colour flips to black or white based
/// on the background's luminance.
class TaskStatusWidget extends StatelessWidget {
  const TaskStatusWidget(
    this.task, {
    super.key,
  });

  final Task task;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final backgroundColor = task.data.status.colorForBrightness(brightness);
    final label = task.data.status.localizedLabel(context);

    return Chip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: fontSizeSmall,
          color: backgroundColor.isLight ? Colors.black : Colors.white,
        ),
      ),
      backgroundColor: backgroundColor,
      visualDensity: VisualDensity.compact,
    );
  }
}
