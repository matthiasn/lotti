import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';

/// Color picker for the category editor, rendered as a
/// [SettingsPickerField] (label above, leading color swatch, hex value,
/// chevron) so it matches the design-system fields around it. Picking
/// happens in an [AlertDialog] hosting the wheel [ColorPicker]. It's
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
    final tokens = context.designTokens;
    final color = selectedColor;

    return SettingsPickerField(
      label: context.messages.colorLabel,
      valueText: color != null ? colorToCssHex(color) : null,
      hintText: context.messages.selectColor,
      leading: color != null
          ? Container(
              width: tokens.spacing.step6,
              height: tokens.spacing.step6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(tokens.radii.xs),
                border: Border.all(color: tokens.colors.decorative.level01),
              ),
            )
          : null,
      onTap: () => _showColorPicker(context),
    );
  }

  void _showColorPicker(BuildContext context) {
    var pickedColor = selectedColor ?? Colors.red;

    showDialog<Color>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.messages.selectColor),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickedColor,
            onColorChanged: (color) {
              pickedColor = color;
            },
            enableAlpha: false,
            labelTypes: const [],
            pickerAreaBorderRadius: BorderRadius.circular(10),
          ),
        ),
        actions: [
          LottiTertiaryButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            label: context.messages.cancelButton,
          ),
          LottiTertiaryButton(
            onPressed: () {
              onColorChanged(pickedColor);
              Navigator.of(dialogContext).pop();
            },
            label: context.messages.selectButton,
          ),
        ],
      ),
    );
  }
}
