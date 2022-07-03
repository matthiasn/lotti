import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/themes/themes_service.dart';

class ThemeConfigWidget extends StatelessWidget {
  const ThemeConfigWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final colorNames = getIt<ColorsService>().colorNames();
    return Positioned(
      width: 400,
      height: MediaQuery.of(context).size.height,
      top: 0,
      left: 0,
      child: ColoredBox(
        color: Colors.white,
        child: SingleChildScrollView(
          child: Column(
            children: [
              ...colorNames.map(AppColorPicker.new),
            ],
          ),
        ),
      ),
    );
  }
}

class AppColorPicker extends StatefulWidget {
  const AppColorPicker(this.colorKey, {super.key});

  final String colorKey;

  @override
  State<AppColorPicker> createState() => _AppColorPickerState();
}

class _AppColorPickerState extends State<AppColorPicker> {
  void onColorChanged(Color color) {
    getIt<ColorsService>().setColor(widget.colorKey, color);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Color>(
      stream: getIt<ColorsService>().watchColorByKey(widget.colorKey),
      builder: (context, snapshot) {
        final currentColor = snapshot.data;

        if (currentColor == null) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            Text(widget.colorKey, style: labelStyleLarger()),
            Theme(
              data: ThemeData(
                primarySwatch: Colors.blue,
                textTheme: TextTheme(
                  bodyText1: labelStyleLarger(),
                  bodyText2: const TextStyle(
                    fontFamily: 'ShareTechMono',
                    fontWeight: FontWeight.w100,
                  ),
                ),
              ),
              child: ColorPicker(
                portraitOnly: true,
                hexInputBar: true,
                enableAlpha: false,
                pickerColor: currentColor,
                onColorChanged: onColorChanged,
                labelTypes: const [ColorLabelType.rgb],
                pickerAreaBorderRadius: BorderRadius.circular(16),
              ),
            ),
            const Divider(color: Colors.grey, thickness: 2),
          ],
        );
      },
    );
  }
}
