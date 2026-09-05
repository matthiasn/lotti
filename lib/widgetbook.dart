import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/features/ai/widgetbook/ai_shader_animations_widgetbook.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_button_widgetbook.dart';
import 'package:lotti/features/projects/widgetbook/project_widgetbook.dart';
import 'package:lotti/features/settings/widgetbook/settings_widgetbook.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/features/tasks/widgetbook/checklist_widgetbook.dart';
import 'package:lotti/features/tasks/widgetbook/task_widgetbook.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:lotti/widgetbook/zoom_pan_wrapper.dart';
import 'package:material_ui/material_ui.dart';
import 'package:widgetbook/widgetbook.dart';

void main() {
  getIt.registerSingleton<UpdateNotifications>(UpdateNotifications());

  runApp(const WidgetbookApp());
}

class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightTheme = WidgetbookTheme(
      name: 'Design System Light',
      data: DesignSystemTheme.light(),
    );
    final darkTheme = WidgetbookTheme(
      name: 'Design System Dark',
      data: DesignSystemTheme.dark(),
    );

    return Widgetbook.material(
      addons: [
        InspectorAddon(),
        GridAddon(100),
        AlignmentAddon(),
        ThemeAddon<ThemeData>(
          themeBuilder: (context, theme, child) => Theme(
            data: theme,
            child: LegacyMaterialBridge(
              child: ColoredBox(
                color: theme.scaffoldBackgroundColor,
                child: DefaultTextStyle(
                  style: theme.textTheme.bodyMedium!,
                  child: child,
                ),
              ),
            ),
          ),
          themes: [lightTheme, darkTheme],
          initialTheme: darkTheme,
        ),
      ],
      appBuilder: (context, child) => MaterialApp(
        builder: LegacyMaterialBridge.builder,
        themeMode: ThemeMode.dark,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Scaffold(
          body: ZoomPanWrapper(child: child),
        ),
      ),
      directories: [
        buildAiWidgetbookFolder(),
        buildDesignSystemWidgetbookFolder(),
        buildProjectsWidgetbookFolder(),
        buildSettingsWidgetbookFolder(),
        buildChecklistWidgetbookFolder(),
        buildTasksWidgetbookFolder(),
        WidgetbookFolder(
          name: 'Task Widgets',
          children: [
            WidgetbookComponent(
              name: 'TitleTextField',
              useCases: [
                WidgetbookUseCase(
                  name: 'TitleTextField',
                  builder: (context) => TitleTextField(
                    onSave: (title) {
                      debugPrint('Saved: $title');
                    },
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
