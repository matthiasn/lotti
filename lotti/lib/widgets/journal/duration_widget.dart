import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class DurationWidget extends StatelessWidget {
  const DurationWidget({
    Key? key,
    required this.item,
    this.style,
  }) : super(key: key);

  final JournalEntity item;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: entryDuration(item).inMilliseconds > 0,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0, right: 4, top: 2),
            child: Icon(
              MdiIcons.timerOutline,
              color: style?.color,
              size: (style?.fontSize ?? 14) + 2,
            ),
          ),
          Text(
            '${entryDuration(item).toString().split('.').first}',
            style: style,
          ),
        ],
      ),
    );
  }
}
