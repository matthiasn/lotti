import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/settings/settings_color_picker_field.dart';

/// Color picker for the category editor — a thin wrapper around the
/// shared [SettingsColorPickerField], so categories and labels edit
/// color through one interaction model: swatch + palette name in the
/// field, the full preset/wheel picker in the shared modal. It's
/// designed to be independent of Riverpod for better testability.
class CategoryColorPicker extends StatelessWidget {
  const CategoryColorPicker({
    required this.selectedColor,
    required this.onColorChanged,
    super.key,
  });

  final Color? selectedColor;
  final ValueChanged<Color> onColorChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsColorPickerField(
      // The hosting section lists several fields, so the field carries
      // its own label (unlike the labels editor's single-field section).
      label: context.messages.colorLabel,
      color: selectedColor,
      onColorChanged: onColorChanged,
    );
  }
}
