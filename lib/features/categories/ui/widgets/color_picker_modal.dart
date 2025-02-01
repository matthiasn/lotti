import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

class ColorPickerModal extends StatelessWidget {
  const ColorPickerModal({
    required this.onColorSelected,
    this.initialColor,
    super.key,
  });

  final void Function(String) onColorSelected;
  final String? initialColor;

  @override
  Widget build(BuildContext context) {
    var pickerColor =
        initialColor != null ? colorFromCssHex(initialColor) : Colors.red;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.messages.colorLabel,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ColorPicker(
            pickerColor: pickerColor,
            enableAlpha: false,
            labelTypes: const [],
            onColorChanged: (color) {
              pickerColor = color;
            },
            pickerAreaBorderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.messages.cancelButton),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  final hexColor = colorToCssHex(pickerColor);
                  onColorSelected(hexColor);
                  Navigator.pop(context);
                },
                child: Text(context.messages.saveLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
