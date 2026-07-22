/// Tutorial-video driver: "set up a category".
///
/// Drives the real app through the scenario in
/// `tools/tutorial_videos/config/scenarios/category_setup.yaml`:
///
///  1. open Settings → Categories,
///  2. create a new category (typed name, on camera),
///  3. configure it in the editor (mark as favorite),
///  4. save and see it in the list.
@Tags(['tutorial-video'])
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
  String localized({
    required String en,
    required String de,
    String? fr,
    String? it,
    String? es,
    String? cs,
    String? nl,
    String? ro,
    String? pt,
    String? da,
    String? sv,
  }) => manualScreenshotText(
    en: en,
    de: de,
    fr: fr,
    it: it,
    es: es,
    cs: cs,
    nl: nl,
    ro: ro,
    pt: pt,
    da: da,
    sv: sv,
  );

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
            .text(
              localized(
                en: 'Settings',
                de: 'Einstellungen',
                fr: 'Paramètres',
                it: 'Impostazioni delle impostazioni',
                es: 'Ajustes',
                cs: 'Nastavení',
                nl: 'Instellingen',
                ro: 'Setări',
                pt: 'Configurações',
                da: 'Indstillinger',
                sv: 'Miljöer',
              ),
            )
            .hitTestable();
        await driver.pumpUntilFound(settingsRailItem);
        await driver.holdUntil(const Duration(seconds: 2));
        await driver.tapLikeUser(settingsRailItem);
      });

      await driver.step('open_settings', () async {
        // Categories lives under the "Definitions" settings section
        // (habits, categories, labels, ...), not as a top-level tile.
        final definitionsTile = find
            .text(
              localized(
                en: 'Definitions',
                de: 'Definitionen',
                fr: 'Définitions',
                it: 'Definizioni',
                es: 'Definiciones',
                cs: 'Definice',
                nl: 'Definities',
                ro: 'Definiții',
                pt: 'Definições',
                da: 'Definitioner',
                sv: 'Definitioner',
              ),
            )
            .hitTestable();
        await driver.pumpUntilFound(definitionsTile);
        await driver.tapLikeUser(definitionsTile.first);

        final categoriesTile = find
            .text(
              localized(
                en: 'Categories',
                de: 'Kategorien',
                fr: 'Catégories',
                it: 'Categorie',
                es: 'Categorías',
                cs: 'Kategorie',
                nl: 'Categorieën',
                ro: 'Categorii',
                pt: 'Categorias',
                da: 'Kategorier',
                sv: 'Kategorier',
              ),
            )
            .hitTestable();
        await driver.pumpUntilFound(categoriesTile);
        await driver.tapLikeUser(categoriesTile.first);
        // The nested Settings delegate doesn't update navService.currentPath,
        // so assert on the loaded page's own content instead of the route.
        await driver.pumpUntilFound(
          find.text(
            localized(
              en: 'Create category',
              de: 'Kategorie erstellen',
              fr: 'Créer une catégorie',
              it: 'Creare una categoria',
              es: 'Crear categoría',
              cs: 'Vytvořit kategorii',
              nl: 'Categorie aanmaken',
              ro: 'Creare categorie',
              pt: 'Criar categoria',
              da: 'Opret kategori',
              sv: 'Skapa kategori',
            ),
          ),
        );
      });

      await driver.step('create_category', () async {
        final createButton = find
            .text(
              localized(
                en: 'Create category',
                de: 'Kategorie erstellen',
                fr: 'Créer une catégorie',
                it: 'Creare una categoria',
                es: 'Crear categoría',
                cs: 'Vytvořit kategorii',
                nl: 'Categorie aanmaken',
                ro: 'Creare categorie',
                pt: 'Criar categoria',
                da: 'Opret kategori',
                sv: 'Skapa kategori',
              ),
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
            .text(
              localized(
                en: 'Create',
                de: 'Erstellen',
                fr: 'Créer',
                it: 'Creare',
                es: 'Crear',
                cs: 'Vytvořit',
                nl: 'Aanmaken',
                ro: 'Creați',
                pt: 'Criar',
                da: 'Opret',
                sv: 'Skapa',
              ),
            )
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
        // SettingsSwitchRow makes the whole row the tap target (InkWell +
        // Semantics) and IgnorePointer-wraps its DesignSystemToggle visual
        // (a custom widget, not Flutter's Switch) so there is no
        // independently-tappable switch to find — tap the row via its
        // title text instead, which sits inside the InkWell's hit area.
        final favoriteLabel = find.text(
          localized(
            en: 'Favorite',
            de: 'Favorit',
            fr: 'Favori',
            it: 'Preferito',
            es: 'Favorito',
            cs: 'Oblíbené',
            nl: 'Favoriet',
            ro: 'Favorit',
            pt: 'Favorito',
            da: 'Favorit',
            sv: 'Favorit',
          ),
        );
        await driver.pumpUntilFound(favoriteLabel);
        await driver.tapLikeUser(favoriteLabel.hitTestable().first);
        await driver.holdUntil(
          driver.timeline.elapsed + const Duration(seconds: 1),
        );
      });

      await driver.step('save_category', () async {
        final saveButton = find
            .text(
              localized(
                en: 'Save',
                de: 'Speichern',
                fr: 'Enregistrer',
                it: 'Salva',
                es: 'Guardar',
                cs: 'Uložit',
                nl: 'Opslaan',
                ro: 'Salvați',
                pt: 'Salvar',
                da: 'Gem',
                sv: 'Spara',
              ),
            )
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
