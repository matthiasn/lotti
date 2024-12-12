import 'package:flutter/material.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/themes/theme.dart';

class EventStatusWidget extends StatelessWidget {
  const EventStatusWidget(
    this.status, {
    super.key,
  });

  final EventStatus status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        status.label,
        style: const TextStyle(fontSize: fontSizeSmall),
      ),
      backgroundColor: status.color.withAlpha(153),
      visualDensity: VisualDensity.compact,
    );
  }
}
