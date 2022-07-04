import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/utils/platform.dart';

class ThemeConfigWidget extends StatelessWidget {
  const ThemeConfigWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final colorNames = getIt<ColorsService>().colorNames();
    return Positioned(
      width: 360,
      height: MediaQuery.of(context).size.height,
      top: 0,
      left: 0,
      child: Material(
        child: ColoredBox(
          color: Colors.white,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 8),
                ...colorNames.map(AppColorPicker.new),
              ],
            ),
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

  bool expanded = false;
  void onTap() => setState(() => expanded = !expanded);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Color>(
      stream: getIt<ColorsService>().watchColorByKey(widget.colorKey),
      builder: (context, snapshot) {
        final currentColor = snapshot.data;

        if (currentColor == null) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: onTap,
          child: Column(
            children: [
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, right: 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 2,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 60,
                          height: 40,
                          color: currentColor,
                        ),
                      ),
                    ),
                  ),
                  Text(widget.colorKey, style: labelStyleLarger()),
                  const Spacer(),
                  IconButton(
                    onPressed: onTap,
                    icon: Icon(
                      expanded
                          ? Icons.keyboard_double_arrow_up
                          : Icons.keyboard_double_arrow_down,
                      color: colorConfig().entryTextColor,
                    ),
                  ),
                ],
              ),
              if (expanded)
                Theme(
                  data: ThemeData(
                    primarySwatch: Colors.blue,
                    textTheme: TextTheme(
                      bodyText1: labelStyleLarger(),
                      bodyText2: pickerMonoTextStyle(),
                      subtitle1: pickerMonoTextStyle(),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
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
                ),
              const Divider(color: Colors.grey, thickness: 1),
            ],
          ),
        );
      },
    );
  }
}

class ThemeConfigWrapper extends StatelessWidget {
  ThemeConfigWrapper(this.child, {super.key});

  final Widget child;
  final JournalDb _db = getIt<JournalDb>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: _db.watchActiveConfigFlagNames(),
      builder: (context, snapshot) {
        final showThemeConfig = snapshot.data != null &&
            snapshot.data!.contains('show_theme_config') &&
            isDesktop;

        if (!showThemeConfig) {
          return MaterialApp(home: child);
        }

        return MaterialApp(
          home: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 360),
                child: child,
              ),
              if (showThemeConfig) const ThemeConfigWidget(),
            ],
          ),
        );
      },
    );
  }
}
