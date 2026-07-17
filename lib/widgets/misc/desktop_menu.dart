import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_catalog.dart';
import 'package:lotti/features/keyboard/domain/app_command_text.dart';
import 'package:lotti/features/keyboard/ui/app_command_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/services/nav_service.dart';

class DesktopMenuWrapper extends StatelessWidget {
  const DesktopMenuWrapper({
    required this.child,
    this.onZoomIn,
    this.onZoomOut,
    this.onZoomReset,
    this.onOpenManual,
    super.key,
  });

  final Widget child;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onZoomReset;
  final VoidCallback? onOpenManual;

  @override
  Widget build(BuildContext context) {
    // Gate on the *target* platform rather than the host OS (`Platform.isMacOS`).
    // `PlatformProvidedMenuItem` is only valid when `defaultTargetPlatform` is
    // macOS; in widget tests that value defaults to `TargetPlatform.android`,
    // so a host check would build the macOS menu on a Mac dev box and throw
    // "Platform android has no platform provided menu". In a real macOS build
    // `defaultTargetPlatform` is `TargetPlatform.macOS`, so behavior there is
    // unchanged.
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return child;
    }

    // Preserve the app-level delegates while introducing the localization
    // scope required by PlatformMenuBar. Inheriting them avoids shadowing
    // editor localizations and automatically includes delegates added later.
    return Localizations.override(
      context: context,
      child: Builder(
        builder: (context) {
          final commandController = AppCommandControllerProvider.maybeOf(
            context,
          );

          PlatformMenuItem commandItem(AppCommandId id) {
            final definition = AppCommandCatalog.definition(id);
            final shortcut =
                definition.bindings.first.resolve(TargetPlatform.macOS)
                    as MenuSerializableShortcut?;
            VoidCallback? onSelected;
            if (commandController != null) {
              if (commandController.isAvailable(context, id)) {
                onSelected = () => unawaited(
                  commandController.invoke(context, id),
                );
              }
            } else {
              onSelected = switch (id) {
                AppCommandId.zoomIn => onZoomIn,
                AppCommandId.zoomOut => onZoomOut,
                AppCommandId.resetZoom => onZoomReset,
                AppCommandId.createTextEntry => () async {
                  final linkedId = await getIdFromSavedRoute();
                  await createTextEntry(linkedId: linkedId);
                },
                AppCommandId.createTask => () async {
                  final linkedId = await getIdFromSavedRoute();
                  await createTask(linkedId: linkedId);
                },
                AppCommandId.captureScreenshot => () async {
                  final linkedId = await getIdFromSavedRoute();
                  await createScreenshot(linkedId: linkedId);
                },
                _ => null,
              };
            }
            return PlatformMenuItem(
              label: AppCommandText.label(context.messages, id),
              shortcut: shortcut,
              onSelected: onSelected,
            );
          }

          return PlatformMenuBar(
            menus: [
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
                label: context.messages.fileMenuTitle,
                menus: [
                  commandItem(AppCommandId.createTextEntry),
                  PlatformMenu(
                    label: context.messages.fileMenuNewEllipsis,
                    menus: [
                      commandItem(AppCommandId.createTask),
                      commandItem(AppCommandId.captureScreenshot),
                    ],
                  ),
                ],
              ),
              PlatformMenu(
                label: context.messages.editMenuTitle,
                menus: [],
              ),
              PlatformMenu(
                label: context.messages.viewMenuTitle,
                menus: [
                  commandItem(AppCommandId.zoomIn),
                  commandItem(AppCommandId.zoomOut),
                  commandItem(AppCommandId.resetZoom),
                  const PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.toggleFullScreen,
                  ),
                  const PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.zoomWindow,
                  ),
                ],
              ),
              PlatformMenu(
                label: context.messages.goMenuTitle,
                menus: [
                  commandItem(AppCommandId.navigateTasks),
                  commandItem(AppCommandId.navigateDailyOs),
                  commandItem(AppCommandId.navigateProjects),
                  commandItem(AppCommandId.navigateHabits),
                  commandItem(AppCommandId.navigateDashboards),
                  commandItem(AppCommandId.navigateJournal),
                  commandItem(AppCommandId.navigateEvents),
                  commandItem(AppCommandId.navigateSettings),
                ],
              ),
              PlatformMenu(
                label: context.messages.helpMenuTitle,
                menus: [
                  PlatformMenuItem(
                    label: context.messages.navSidebarManualLabel,
                    onSelected: onOpenManual,
                  ),
                  commandItem(AppCommandId.openCommandPalette),
                  commandItem(AppCommandId.openShortcutHelp),
                ],
              ),
            ],
            child: child,
          );
        },
      ),
    );
  }
}
