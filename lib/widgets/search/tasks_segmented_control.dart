import 'package:flutter/cupertino.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/misc/segmented_control.dart';

class TasksSegmentedControl extends StatelessWidget {
  const TasksSegmentedControl({
    required this.showTasks,
    required this.onValueChanged,
    super.key,
  });

  final bool showTasks;

  // ignore: avoid_positional_boolean_parameters
  final void Function(bool) onValueChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoSegmentedControl<bool>(
      selectedColor: styleConfig().primaryColor,
      unselectedColor: styleConfig().negspace,
      borderColor: styleConfig().primaryColor,
      groupValue: showTasks,
      onValueChanged: onValueChanged,
      children: const {
        false: TextSegment('Journal'),
        true: TextSegment('Tasks'),
      },
    );
  }
}
