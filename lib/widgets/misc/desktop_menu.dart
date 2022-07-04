import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
    final localizations = AppLocalizations.of(context)!;

    if (!Platform.isMacOS) {
      return body;
    }

    return StreamBuilder<Set<String>>(
      stream: _db.watchActiveConfigFlagNames(),
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
              label: localizations.fileMenuTitle,
              menus: [
                PlatformMenuItem(
                  label: localizations.fileMenuNewEntry,
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
                  label: localizations.fileMenuNewEllipsis,
                  menus: [
                    PlatformMenuItem(
                      label: localizations.fileMenuNewTask,
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
                      label: localizations.fileMenuNewScreenshot,
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
            PlatformMenu(
              label: localizations.editMenuTitle,
              menus: [],
            ),
            PlatformMenu(
              label: localizations.viewMenuTitle,
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
                      label:
                          snapshot.data?.contains(showBrightSchemeFlagName) ??
                                  false
                              ? localizations.viewMenuDisableBrightTheme
                              : localizations.viewMenuEnableBrightTheme,
                      shortcut: const SingleActivator(
                        LogicalKeyboardKey.keyS,
                        meta: true,
                        alt: true,
                      ),
                      onSelected: () async {
                        await _db.toggleConfigFlag(showBrightSchemeFlagName);
                      },
                    ),
                    PlatformMenuItem(
                      label: snapshot.data?.contains(showThemeConfigFlagName) ??
                              false
                          ? localizations.viewMenuHideThemeConfig
                          : localizations.viewMenuShowThemeConfig,
                      shortcut: const SingleActivator(
                        LogicalKeyboardKey.keyS,
                        meta: true,
                        alt: true,
                      ),
                      onSelected: () async {
                        await _db.toggleConfigFlag(showThemeConfigFlagName);
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
