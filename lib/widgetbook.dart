import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/checkbox_widget.dart';
import 'package:widgetbook/widgetbook.dart';

void main() {
  runApp(const WidgetbookApp());
}

class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      addons: [
        DeviceFrameAddon(devices: Devices.ios.all),
        InspectorAddon(),
        GridAddon(100),
        AlignmentAddon(),
        ZoomAddon(),
        MaterialThemeAddon(
          themes: [
            WidgetbookTheme(
              name: 'Light',
              data: ThemeData.light(),
            ),
            WidgetbookTheme(
              name: 'Dark',
              data: ThemeData.dark(),
            ),
          ],
        ),
      ],
      appBuilder: (context, child) => MaterialApp(
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: child,
        ),
      ),
      directories: [
        WidgetbookFolder(
          name: 'Task Widgets',
          children: [
            WidgetbookComponent(
              name: 'Checkbox widget',
              useCases: [
                WidgetbookUseCase(
                  name: 'UI implementation',
                  builder: (context) => CheckboxItemWidget(
                    title: 'Create PR',
                    isChecked: true,
                    onChanged: (checked) {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
