import 'package:flutter/material.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/themes/theme.dart';
import 'package:tinycolor2/tinycolor2.dart';

class EventStatusWidget extends StatelessWidget {
  const EventStatusWidget(
    this.status, {
    super.key,
  });

  final EventStatus status;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = status.color;

    return Chip(
      label: Text(
        status.label,
        style: TextStyle(
          fontSize: fontSizeSmall,
          color: backgroundColor.isLight ? Colors.black : Colors.white,
        ),
      ),
      backgroundColor: status.color,
      visualDensity: VisualDensity.compact,
    );
  }
}
