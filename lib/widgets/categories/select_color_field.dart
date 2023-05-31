import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/settings/categories/categories_type_card.dart';

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
    final localizations = AppLocalizations.of(context)!;

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

    final style =
        widget.hexColor != null ? searchFieldHintStyle() : searchFieldStyle();

    final color = widget.hexColor != null
        ? colorFromCssHex(widget.hexColor)
        : styleConfig().secondaryTextColor;

    Future<void> onTap() async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext _) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
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
                  )
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
        labelText:
            widget.hexColor == null || !valid ? '' : localizations.colorLabel,
        semanticsLabel: 'Select color',
      ).copyWith(
        icon: ColorIcon(color),
        hintText: localizations.colorPickerHint,
        hintStyle: style.copyWith(
          color: styleConfig().secondaryTextColor.withOpacity(0.5),
        ),
        suffixIcon: IconButton(
          onPressed: onTap,
          icon: Icon(
            Icons.color_lens_outlined,
            color: styleConfig().secondaryTextColor,
            semanticLabel: 'Pick color',
          ),
        ),
        errorText: valid ? null : localizations.colorPickerError,
      ),
      style: style,
      //onChanged: widget.onChanged,
    );
  }
}
