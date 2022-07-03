import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/themes_service.dart';

class ThemeConfigWidget extends StatelessWidget {
  const ThemeConfigWidget({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('ThemeConfigWidget render');
    return Positioned(
      width: 400,
      height: MediaQuery.of(context).size.height,
      top: 0,
      child: ColoredBox(
        color: Colors.white,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text('bodyBgColor'),
              ColorPicker(
                hexInputBar: true,
                enableAlpha: false,
                portraitOnly: true,
                pickerColor: getIt<ColorsService>().current.bodyBgColor,
                onColorChanged: (Color color) {
                  getIt<ColorsService>().setTheme(
                    getIt<ColorsService>().current.copyWith(bodyBgColor: color),
                  );
                },
              ),
              const Divider(
                color: Colors.grey,
                thickness: 2,
              ),
              const Text('headerBgColor'),
              ColorPicker(
                portraitOnly: true,
                hexInputBar: true,
                enableAlpha: false,
                pickerColor: getIt<ColorsService>().current.headerBgColor,
                onColorChanged: (Color color) {
                  getIt<ColorsService>().setTheme(
                    getIt<ColorsService>()
                        .current
                        .copyWith(headerBgColor: color),
                  );
                },
              ),
              const Divider(
                color: Colors.grey,
                thickness: 2,
              ),
              const Text('entryCardColor'),
              ColorPicker(
                portraitOnly: true,
                hexInputBar: true,
                enableAlpha: false,
                pickerColor: getIt<ColorsService>().current.entryCardColor,
                onColorChanged: (Color color) {
                  getIt<ColorsService>().setTheme(
                    getIt<ColorsService>()
                        .current
                        .copyWith(entryCardColor: color),
                  );
                },
              ),
              const Text('bottomNavBackground'),
              ColorPicker(
                portraitOnly: true,
                hexInputBar: true,
                enableAlpha: false,
                pickerColor: getIt<ColorsService>().current.bottomNavBackground,
                onColorChanged: (Color color) {
                  getIt<ColorsService>().setTheme(
                    getIt<ColorsService>()
                        .current
                        .copyWith(bottomNavBackground: color),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
