import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/services/nav_service.dart';

class DesktopMenuWrapper extends StatelessWidget {
  const DesktopMenuWrapper({
    required this.child,
    this.onZoomIn,
    this.onZoomOut,
    this.onZoomReset,
    super.key,
  });

  final Widget child;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onZoomReset;

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

    // Use Localizations instead of MaterialApp to avoid creating an extra
    // root Navigator. An outer MaterialApp would shadow the themed
    // MaterialApp.router below and cause modals opened with
    // useRootNavigator:true to lose the app's dark/light theme.
    final locale =
        Localizations.maybeLocaleOf(context) ??
        ui.PlatformDispatcher.instance.locale;

    return Localizations(
      locale: locale,
      delegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      child: Builder(
        builder: (context) {
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
                  PlatformMenuItem(
                    label: context.messages.fileMenuNewEntry,
                    onSelected: () async {
                      final linkedId = await getIdFromSavedRoute();
                      await createTextEntry(linkedId: linkedId);
                    },
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyN,
                      meta: true,
                    ),
                  ),
                  PlatformMenu(
                    label: context.messages.fileMenuNewEllipsis,
                    menus: [
                      PlatformMenuItem(
                        label: context.messages.fileMenuNewTask,
                        shortcut: const SingleActivator(
                          LogicalKeyboardKey.keyT,
                          meta: true,
                        ),
                        onSelected: () async {
                          final linkedId = await getIdFromSavedRoute();
                          await createTask(linkedId: linkedId);
                        },
                      ),
                      PlatformMenuItem(
                        label: context.messages.fileMenuNewScreenshot,
                        shortcut: const SingleActivator(
                          LogicalKeyboardKey.keyS,
                          meta: true,
                          alt: true,
                        ),
                        onSelected: () async {
                          final linkedId = await getIdFromSavedRoute();
                          await createScreenshot(linkedId: linkedId);
                        },
                      ),
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
                  PlatformMenuItem(
                    label: context.messages.viewMenuZoomIn,
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.add,
                      meta: true,
                    ),
                    onSelected: onZoomIn,
                  ),
                  PlatformMenuItem(
                    label: context.messages.viewMenuZoomOut,
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.minus,
                      meta: true,
                    ),
                    onSelected: onZoomOut,
                  ),
                  PlatformMenuItem(
                    label: context.messages.viewMenuZoomReset,
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.digit0,
                      meta: true,
                    ),
                    onSelected: onZoomReset,
                  ),
                  const PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.toggleFullScreen,
                  ),
                  const PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.zoomWindow,
                  ),
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
