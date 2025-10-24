import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/utils/color.dart';

class LabelChip extends StatelessWidget {
  const LabelChip({
    required this.label,
    super.key,
  });

  final LabelDefinition label;

  @override
  Widget build(BuildContext context) {
    final color = colorFromCssHex(label.color, substitute: Colors.blue);
    final brightness = ThemeData.estimateBrightnessForColor(color);
    final textColor =
        brightness == Brightness.dark ? Colors.white : Colors.black87;

    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
      ),
      backgroundColor: color.withAlpha((0.15 * 255).round()),
      label: Text(
        label.name,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}
