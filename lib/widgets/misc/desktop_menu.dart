import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/services/nav_service.dart';

class DesktopMenuWrapper extends StatelessWidget {
  final Widget body;

  const DesktopMenuWrapper(
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
              onSelected: () {
                pushNamedRoute('/journal/create/${null}');
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
                  onSelected: () {
                    pushNamedRoute('/tasks/create/${null}');
                  },
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: 'Edit',
          menus: [
            PlatformMenuItem(
              label: 'Cut',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyX,
                meta: true,
              ),
              onSelected: () {
                debugPrint('Cut');
              },
            ),
            PlatformMenuItem(
              label: 'Copy',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyC,
                meta: true,
              ),
              onSelected: () {
                debugPrint('Copy');
              },
            ),
          ],
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
