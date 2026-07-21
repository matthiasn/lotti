/// Tutorial-video driver: "set up a category".
///
/// Drives the real app through the scenario in
/// `tools/tutorial_videos/config/scenarios/category_setup.yaml`:
///
///  1. open Settings → Categories,
///  2. create a new category (typed name, on camera),
///  3. configure it in the editor (mark as favorite),
///  4. save and see it in the list.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lotti/beamer/beamer_app.dart';

import '../../test/helpers/manual_screenshot_locale.dart';
import '../manual_screenshot_utils.dart';
import 'tutorial_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final manifest = TutorialManifest.fromEnvironment();
  final locale = manualScreenshotLocaleFromEnvironment(Platform.environment);
  String localized({required String en, required String de}) =>
      manualScreenshotText(en: en, de: de);

  testWidgets(
    'drives the category-setup tutorial flow',
    (tester) async {
      tester.platformDispatcher.localeTestValue = locale;
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      final harness = await TutorialAppHarness.setUp(
        aiConfigs: const [],
        languageCode: locale.languageCode,
      );
      addTearDown(harness.dispose);

      final cursor = TutorialCursorController();
      final hudClock = ValueNotifier<Duration>(Duration.zero);
      addTearDown(hudClock.dispose);
      await tester.pumpWidget(
        manualScreenshotBoundary(
          child: TutorialCursorLayer(
            controller: cursor,
            elapsed: hudClock,
            child: ProviderScope(
              overrides: harness.providerOverrides(),
              child: MyBeamerApp(
                navService: harness.navService,
                userActivityService: harness.userActivityService,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final driver =
          TutorialDriver(
              tester: tester,
              manifest: manifest,
              cursor: cursor,
              hud: hudClock,
            )
            ..diagnostics = () {
              final nav = harness.navService;
              return 'currentPath=${nav.currentPath} '
                  'switches=${find.byType(Switch).evaluate().length} '
                  'textFields=${find.byType(TextField).evaluate().length}';
            }
            ..onTimeout = (context) => captureManualScreenshot(
              binding: binding,
              tester: tester,
              name: 'failure_$context',
            );

      final categoryName = localized(
        en: 'Iceberg Maintenance',
        de: 'Eisberg-Wartung',
      );

      await driver.step('intro', () async {
        final settingsRailItem = find
            .text(localized(en: 'Settings', de: 'Einstellungen'))
            .hitTestable();
        await driver.pumpUntilFound(settingsRailItem);
        await driver.holdUntil(const Duration(seconds: 2));
        await driver.tapLikeUser(settingsRailItem);
      });

      await driver.step('open_settings', () async {
        final categoriesTile = find
            .text(localized(en: 'Categories', de: 'Kategorien'))
            .hitTestable();
        await driver.pumpUntilFound(categoriesTile);
        await driver.tapLikeUser(categoriesTile.first);
        await driver.pumpUntil(
          () => harness.navService.currentPath.contains(
            '/settings/categories',
          ),
          description: 'categories list route',
        );
      });

      await driver.step('create_category', () async {
        final createButton = find
            .text(
              localized(en: 'Create category', de: 'Kategorie erstellen'),
            )
            .hitTestable();
        await driver.pumpUntilFound(createButton);
        await driver.tapLikeUser(createButton.first);

        final nameField = find.byType(TextField).hitTestable();
        await driver.pumpUntilFound(nameField);
        await driver.tapLikeUser(nameField.first);
        // Type the name progressively so the viewer sees it appear.
        for (var i = 1; i <= categoryName.length; i++) {
          await tester.enterText(
            nameField.first,
            categoryName.substring(0, i),
          );
          await tester.pump(const Duration(milliseconds: 55));
        }
        await driver.holdUntil(
          driver.timeline.elapsed + const Duration(milliseconds: 400),
        );

        final createConfirm = find
            .text(localized(en: 'Create', de: 'Erstellen'))
            .hitTestable();
        await driver.pumpUntilFound(createConfirm);
        await driver.tapLikeUser(createConfirm.first);
        // Creation lands on the category editor route.
        await driver.pumpUntil(
          () {
            final path = harness.navService.currentPath;
            return path.startsWith('/settings/categories/') &&
                !path.endsWith('/create');
          },
          description: 'category editor route after creation',
        );
      });

      await driver.step('configure', () async {
        final favoriteLabel = find.text(
          localized(en: 'Favorite', de: 'Favorit'),
        );
        await driver.pumpUntilFound(favoriteLabel);
        // The options block lists Favorite first; its Switch is the first
        // switch on the page.
        final favoriteSwitch = find.byType(Switch).hitTestable();
        await driver.pumpUntilFound(favoriteSwitch);
        await driver.tapLikeUser(favoriteSwitch.first);
        await driver.holdUntil(
          driver.timeline.elapsed + const Duration(seconds: 1),
        );
      });

      await driver.step('save_category', () async {
        final saveButton = find
            .text(localized(en: 'Save', de: 'Speichern'))
            .hitTestable();
        await driver.pumpUntilFound(saveButton);
        await driver.tapLikeUser(saveButton.first);
        await driver.pumpUntil(
          () async {
            final categories = await harness.journalDb.getAllCategories();
            return categories.any(
              (category) =>
                  category.name == categoryName && (category.favorite ?? false),
            );
          },
          description: 'favorite category persisted',
        );
        await driver.pumpUntilFound(
          find.text(categoryName),
          timeout: const Duration(seconds: 20),
        );
      });

      await driver.step('outro', () async {});

      driver.timeline.write();
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
