import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os/widgetbook/my_daily_widgetbook.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_button_widgetbook.dart';
import 'package:lotti/features/projects/widgetbook/project_widgetbook.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_widget.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/features/tasks/widgetbook/task_widgetbook.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/widgetbook/mock_data.dart';
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
        ZoomAddon(),
        MaterialThemeAddon(
          themes: [lightTheme, darkTheme],
          initialTheme: darkTheme,
        ),
      ],
      appBuilder: (context, child) => MaterialApp(
        themeMode: ThemeMode.dark,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        home: Scaffold(
          body: child,
        ),
      ),
      directories: [
        buildDesignSystemWidgetbookFolder(),
        buildMyDailyWidgetbookFolder(),
        buildProjectsWidgetbookFolder(),
        buildTasksWidgetbookFolder(),
        WidgetbookFolder(
          name: 'Task Widgets',
          children: [
            WidgetbookComponent(
              name: 'Checkbox widget',
              useCases: [
                WidgetbookUseCase(
                  name: 'CheckboxItemWidget',
                  builder: (context) => ChecklistItemWidget(
                    title: 'Create PR',
                    isChecked: true,
                    onChanged: (checked) {},
                  ),
                ),
                WidgetbookUseCase(
                  name: 'TitleTextField',
                  builder: (context) => TitleTextField(
                    onSave: (title) {
                      debugPrint('Saved: $title');
                    },
                  ),
                ),
                WidgetbookUseCase(
                  name: 'CheckboxItemsList',
                  builder: (context) => ProviderScope(
                    overrides: [
                      checklistItemControllerProvider.overrideWithBuild(
                        (ref, params) async => checklistItem1,
                      ),
                    ],
                    child: ChecklistWidget(
                      id: '1',
                      title: 'Checklist',
                      taskId: '12',
                      itemIds: [
                        checklistItem1.meta.id,
                        checklistItem2.meta.id,
                        checklistItem3.meta.id,
                        checklistItem4.meta.id,
                      ],
                      completionRate: 0.5,
                      onCreateChecklistItem: (title) async {
                        return null;
                      },
                      onTitleSave: (title) {},
                      updateItemOrder: (items) async {},
                    ),
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
