import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/settings/categories/categories_type_card.dart';

class SelectColorField extends StatelessWidget {
  const SelectColorField({
    required this.hexColor,
    required this.onColorChanged,
    super.key,
  });

  final String? hexColor;
  final ValueChanged<Color> onColorChanged;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final controller = TextEditingController()..text = hexColor ?? '';

    controller.addListener(() {
      final regex = RegExp('#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?');
      final text = controller.text;
      final validHex = regex.hasMatch(text);
      debugPrint('$text $validHex');
      if (validHex) {
        onColorChanged(colorFromCssHex(text));
      }
    });

    final style =
        hexColor != null ? searchFieldHintStyle() : searchFieldStyle();

    final color = hexColor != null
        ? colorFromCssHex(hexColor!)
        : styleConfig().secondaryTextColor.withOpacity(0.2);

    void onTap() {
      showModalBottomSheet<void>(
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
                    onColorChanged: onColorChanged,
                    pickerAreaBorderRadius: BorderRadius.circular(10),
                  )
                ],
              ),
            ),
          );
        },
      );
    }

    return TextField(
      focusNode: FocusNode(),
      controller: controller,
      decoration: inputDecoration(
        labelText: hexColor == null ? '' : localizations.colorLabel,
        semanticsLabel: 'Select color',
      ).copyWith(
        icon: ColorIcon(color),
        hintText: localizations.colorPickerHint,
        hintStyle: style,
        border: InputBorder.none,
        suffixIcon: IconButton(
          onPressed: onTap,
          icon: Icon(
            Icons.color_lens_outlined,
            color: styleConfig().secondaryTextColor,
          ),
        ),
      ),
      style: style,
      //onChanged: widget.onChanged,
    );
  }
}
