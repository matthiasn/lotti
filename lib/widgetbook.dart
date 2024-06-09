import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/features/tasks/ui/checkbox_item_widget.dart';
import 'package:lotti/features/tasks/ui/checkbox_items_list.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/widgetbook/mock_controllers.dart';
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
        localizationsDelegates: const [
          AppLocalizations.delegate,
        ],
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
                    onEdit: () {
                      debugPrint('Edit');
                    },
                  ),
                ),
                WidgetbookUseCase(
                  name: 'With provider wrapper',
                  builder: (context) => ProviderScope(
                    overrides: [
                      checklistItemControllerProvider
                          .getProviderOverride(
                            ChecklistItemControllerProvider(
                              id: checklistItem1.meta.id,
                            ),
                          )
                          .overrideWith(
                            () => MockChecklistItemControllerProvider(
                              value: Future.value(
                                checklistItem1,
                              ),
                            ),
                          ),
                      checklistItemControllerProvider
                          .getProviderOverride(
                            ChecklistItemControllerProvider(
                              id: checklistItem2.meta.id,
                            ),
                          )
                          .overrideWith(
                            () => MockChecklistItemControllerProvider(
                              value: Future.value(
                                checklistItem2,
                              ),
                            ),
                          ),
                      checklistItemControllerProvider
                          .getProviderOverride(
                            ChecklistItemControllerProvider(
                              id: checklistItem3.meta.id,
                            ),
                          )
                          .overrideWith(
                            () => MockChecklistItemControllerProvider(
                              value: Future.value(
                                checklistItem3,
                              ),
                            ),
                          ),
                    ],
                    child: CheckboxItemsList(
                      itemIds: [
                        checklistItem1.meta.id,
                        checklistItem2.meta.id,
                        checklistItem3.meta.id,
                      ],
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
