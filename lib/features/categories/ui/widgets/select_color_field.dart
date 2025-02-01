import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:lotti/features/categories/ui/widgets/categories_type_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';

class SelectColorField extends StatefulWidget {
  const SelectColorField({
    required this.hexColor,
    required this.onColorChanged,
    super.key,
  });

  final String? hexColor;
  final ValueChanged<Color> onColorChanged;

  @override
  State<SelectColorField> createState() => _SelectColorFieldState();
}

class _SelectColorFieldState extends State<SelectColorField> {
  bool valid = true;

  final controller = TextEditingController();

  @override
  void initState() {
    controller.text = widget.hexColor ?? '';
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    controller.addListener(() {
      final regex = RegExp('#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?');
      final text = controller.text;
      final validHex = regex.hasMatch(text);

      setState(() {
        valid = validHex;
      });

      if (validHex) {
        widget.onColorChanged(colorFromCssHex(text));
      }
    });

    final style = context.textTheme.titleMedium;

    final color = widget.hexColor != null
        ? colorFromCssHex(widget.hexColor)
        : context.colorScheme.outline;

    Future<void> onTap() async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext _) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ColorPicker(
                    pickerColor: color,
                    enableAlpha: false,
                    labelTypes: const [],
                    onColorChanged: widget.onColorChanged,
                    pickerAreaBorderRadius: BorderRadius.circular(10),
                  ),
                ],
              ),
            ),
          );
        },
      );
      controller.text = widget.hexColor ?? '';
    }

    return TextField(
      controller: controller,
      decoration: inputDecoration(
        labelText: widget.hexColor == null || !valid
            ? ''
            : context.messages.colorLabel,
        semanticsLabel: 'Select color',
        themeData: Theme.of(context),
      ).copyWith(
        icon: ColorIcon(color),
        hintText: context.messages.colorPickerHint,
        hintStyle: style?.copyWith(
          color: context.colorScheme.outline.withAlpha(127),
        ),
        suffixIcon: IconButton(
          onPressed: onTap,
          icon: Icon(
            Icons.color_lens_outlined,
            color: context.colorScheme.outline,
            semanticLabel: 'Pick color',
          ),
        ),
        errorText: valid ? null : context.messages.colorPickerError,
      ),
      style: style,
    );
  }
}
