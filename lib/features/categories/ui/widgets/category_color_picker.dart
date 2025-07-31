import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

/// A color picker widget for selecting category colors.
///
/// This widget displays the current color and allows users to select a new color
/// through a dialog. It's designed to be independent of Riverpod for better testability.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.colorLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showColorPicker(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).dividerColor,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        selectedColor ?? Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  selectedColor != null
                      ? colorToCssHex(selectedColor!)
                      : context.messages.selectColor,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const Spacer(),
                const Icon(Icons.palette_outlined),
              ],
            ),
          ),
        ),
      ],
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
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.messages.cancelButton),
          ),
          TextButton(
            onPressed: () {
              onColorChanged(pickedColor);
              Navigator.of(dialogContext).pop();
            },
            child: Text(context.messages.selectButton),
          ),
        ],
      ),
    );
  }
}
