import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/nav_service.dart';

class DesktopMenuWrapper extends StatelessWidget {
  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();
  final Widget body;

  DesktopMenuWrapper(
    this.body, {
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) {
      return body;
    }

    return PlatformMenuBar(
      body: body,
      menus: <MenuItem>[
        const PlatformMenu(
          label: 'Lotti',
          menus: [
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.about,
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.servicesSubmenu,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hide,
                ),
              ],
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.quit,
            ),
          ],
        ),
        PlatformMenu(
          label: 'File',
          menus: [
            PlatformMenuItem(
              label: 'New Entry',
              onSelected: () async {
                String? linkedId = await getIdFromSavedRoute();
                if (linkedId != null) {
                  _persistenceLogic.createTextEntry(
                    EntryText(plainText: ''),
                    linkedId: linkedId,
                    started: DateTime.now(),
                  );
                } else {
                  pushNamedRoute('/journal/create/$linkedId');
                }
              },
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyN,
                meta: true,
              ),
            ),
            PlatformMenu(
              label: 'New ...',
              menus: [
                PlatformMenuItem(
                  label: 'Task',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyT,
                    meta: true,
                  ),
                  onSelected: () async {
                    String? linkedId = await getIdFromSavedRoute();
                    pushNamedRoute('/tasks/create/$linkedId');
                  },
                ),
              ],
            ),
          ],
        ),
        const PlatformMenu(
          label: 'Edit',
          menus: [],
        ),
        const PlatformMenu(
          label: 'View',
          menus: [
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.toggleFullScreen,
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.zoomWindow,
            ),
          ],
        ),
      ],
    );
  }
}
