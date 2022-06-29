import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/screenshots.dart';

class DesktopMenuWrapper extends StatelessWidget {
  DesktopMenuWrapper(
    this.body, {
    super.key,
  });

  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();
  final JournalDb _db = getIt<JournalDb>();
  final Widget body;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) {
      return body;
    }

    return StreamBuilder<bool>(
      //stream: getIt<ThemeService>().getStream(),
      stream: _db.watchConfigFlag(showBrightSchemeFlagName),
      builder: (context, snapshot) {
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
                    final linkedId = await getIdFromSavedRoute();
                    if (linkedId != null) {
                      await _persistenceLogic.createTextEntry(
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
                        final linkedId = await getIdFromSavedRoute();
                        pushNamedRoute('/tasks/create/$linkedId');
                      },
                    ),
                    PlatformMenuItem(
                      label: 'Screenshot',
                      shortcut: const SingleActivator(
                        LogicalKeyboardKey.keyS,
                        meta: true,
                        alt: true,
                      ),
                      onSelected: () async {
                        await takeScreenshotWithLinked();
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
            PlatformMenu(
              label: 'View',
              menus: [
                const PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.toggleFullScreen,
                ),
                const PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.zoomWindow,
                ),
                PlatformMenuItemGroup(
                  members: [
                    PlatformMenuItem(
                      label: snapshot.data ?? false
                          ? 'Disable Bright Theme'
                          : 'Enable Bright theme',
                      shortcut: const SingleActivator(
                        LogicalKeyboardKey.keyS,
                        meta: true,
                        alt: true,
                      ),
                      onSelected: () async {
                        await _db.toggleConfigFlag(showBrightSchemeFlagName);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
