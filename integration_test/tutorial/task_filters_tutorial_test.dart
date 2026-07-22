/// Tutorial-video driver: "filter tasks and save your views".
///
/// Drives the real app through the scenario in
/// `tools/tutorial_videos/config/scenarios/task_filters.yaml`:
///
///  1. open the filter modal from the tasks page,
///  2. filter by the Penguin Operations category (list narrows, active
///     chip appears),
///  3. save the filter under a name.
///
/// A second category with its own task is seeded so the narrowing is
/// visible on camera.
@Tags(['tutorial-video'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/get_it.dart';

import '../../test/helpers/manual_screenshot_locale.dart';
import '../manual_screenshot_utils.dart';
import 'tutorial_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final manifest = TutorialManifest.fromEnvironment();
  final locale = manualScreenshotLocaleFromEnvironment(Platform.environment);
  const localized = manualScreenshotText;

  testWidgets(
    'drives the task-filters tutorial flow',
    (tester) async {
      tester.platformDispatcher.localeTestValue = locale;
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      final harness = await TutorialAppHarness.setUp(
        aiConfigs: const [],
        languageCode: locale.languageCode,
      );
      addTearDown(harness.dispose);

      // A second category + task so filtering visibly narrows the list.
      final otherCategory = harness.world.category.copyWith(
        id: 'tutorial-other-category',
        name: localized(
          en: 'Human Maintenance',
          de: 'Menschenpflege',
          fr: 'Maintenance humaine',
          it: 'Manutenzione umana',
          es: 'Mantenimiento humano',
          cs: 'Péče o posádku',
          nl: 'Menselijk onderhoud',
          ro: 'Întreținerea oamenilor',
          pt: 'Manutenção Humana',
          da: 'Menneskelig vedligeholdelse',
          sv: 'Mänskligt underhåll',
        ),
        favorite: false,
      );
      await harness.persistenceLogic.upsertEntityDefinition(otherCategory);
      final otherTask = await harness.persistenceLogic.createTaskEntry(
        data: TaskData(
          title: localized(
            en: 'Refill the coffee supplies',
            de: 'Kaffeevorräte auffüllen',
            fr: 'Réapprovisionner le café',
            it: 'Rifornire le scorte di caffè',
            es: 'Reponer las provisiones de café',
            cs: 'Doplnit zásoby kávy',
            nl: 'Koffievoorraad aanvullen',
            ro: 'Reaprovizionați cu cafea',
            pt: 'Reabastecer o estoque de café',
            da: 'Genopfyld kaffelagre',
            sv: 'Fylla på kaffeförrådet',
          ),
          status: TaskStatus.open(
            id: 'tutorial-other-task-status',
            createdAt: DateTime.now(),
            utcOffset: DateTime.now().timeZoneOffset.inMinutes,
          ),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          statusHistory: const [],
        ),
        entryText: const EntryText(plainText: ''),
        categoryId: otherCategory.id,
      );
      expect(otherTask, isNotNull);

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

      // Land on Tasks BEFORE the recorded timeline starts — the app's real
      // default landing tab is the Logbook (Journal), which would
      // otherwise flash on screen during the intro step's establishing
      // hold.
      harness.navService.setIndex(
        harness.navService.beamerDelegates.indexOf(
          harness.navService.tasksDelegate,
        ),
      );
      await tester.pump();

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
                  'chips=${find.byKey(const ValueKey('design-system-task-filter-apply')).evaluate().length}';
            }
            ..onTimeout = (context) => captureManualScreenshot(
              binding: binding,
              tester: tester,
              name: 'failure_$context',
            );

      final filterName = localized(
        en: 'Penguin focus',
        de: 'Pinguin-Fokus',
        fr: 'Focus pingouins',
        it: 'Focus pinguini',
        es: 'Enfoque pingüinos',
        cs: 'Zaměření na tučňáky',
        nl: 'Pinguïnfocus',
        ro: 'Focalizare pinguini',
        pt: 'Foco em pinguins',
        da: 'Pingvinfokus',
        sv: 'Pingvinfokus',
      );
      final filterIcon = find
          .byTooltip(
            localized(
              en: 'Filter tasks',
              de: 'Aufgaben filtern',
              fr: 'Filtrer les tâches',
              it: 'Filtra le attività',
              es: 'Filtrar tareas',
              cs: 'Filtrovat úkoly',
              nl: 'Filtertaken',
              ro: 'Filtrați sarcinile',
              pt: 'Filtrar tarefas',
              da: 'Filteropgaver',
              sv: 'Filtrera uppgifter',
            ),
          )
          .hitTestable();

      await driver.step('intro', () async {
        final tasksRailItem = find
            .text(
              localized(
                en: 'Tasks',
                de: 'Aufgaben',
                fr: 'Tâches',
                it: 'Compiti',
                es: 'Tareas',
                cs: 'Úkoly',
                nl: 'Taken',
                ro: 'Sarcini',
                pt: 'Tarefas',
                da: 'Opgaver',
                sv: 'Uppgifter',
              ),
            )
            .hitTestable();
        await driver.pumpUntilFound(tasksRailItem);
        await driver.holdUntil(const Duration(seconds: 2));
        await driver.tapLikeUser(tasksRailItem);
        await driver.pumpUntilFound(
          find.byKey(ValueKey(otherTask!.meta.id)),
          timeout: const Duration(seconds: 20),
        );
      });

      await driver.step('open_filters', () async {
        await driver.pumpUntilFound(filterIcon);
        await driver.tapLikeUser(filterIcon.first);
        await driver.pumpUntilFound(
          find.byKey(
            const ValueKey('design-system-task-filter-field-category'),
          ),
        );
      });

      await driver.step('pick_category', () async {
        await driver.tapLikeUser(
          find
              .byKey(
                const ValueKey('design-system-task-filter-field-category'),
              )
              .hitTestable(),
        );
        final categoryOption = find
            .byKey(
              ValueKey(
                'design-system-filter-selection-option-'
                '${harness.world.category.id}',
              ),
            )
            .hitTestable();
        // Wait on the hit-testable finder itself, not merely on the
        // element existing — the selection modal's entrance animation can
        // add the option to the tree before it is actually hit-testable,
        // and tapLikeUser's getCenter throws on an empty finder.
        await driver.pumpUntilFound(categoryOption);
        await driver.tapLikeUser(categoryOption);
        await driver.holdUntil(
          driver.timeline.elapsed + const Duration(milliseconds: 800),
        );
        await driver.tapLikeUser(
          find
              .byKey(const ValueKey('design-system-filter-selection-apply'))
              .hitTestable(),
        );
      });

      await driver.step('apply_filter', () async {
        await driver.tapLikeUser(
          find
              .byKey(const ValueKey('design-system-task-filter-apply'))
              .hitTestable(),
        );
        // The other category's task disappears; the active-filter chip with
        // the category name appears on the tasks page.
        await driver.pumpUntil(
          () => find.byKey(ValueKey(otherTask!.meta.id)).evaluate().isEmpty,
          description: 'list narrowed to the selected category',
        );
        await driver.pumpUntilFound(
          find.descendant(
            of: find.byType(TasksTabPage),
            matching: find.text(harness.world.category.name),
          ),
        );
      });

      await driver.step('save_filter', () async {
        await driver.pumpUntilFound(filterIcon);
        await driver.tapLikeUser(filterIcon.first);
        final saveButton = find
            .byKey(const ValueKey('design-system-task-filter-save'))
            .hitTestable();
        await driver.pumpUntilFound(saveButton);
        await driver.tapLikeUser(saveButton);

        final nameField = find
            .byKey(const ValueKey('design-system-filter-save-name-field'))
            .hitTestable();
        await driver.pumpUntilFound(nameField);
        await driver.tapLikeUser(nameField);
        for (var i = 1; i <= filterName.length; i++) {
          await tester.enterText(
            nameField.first,
            filterName.substring(0, i),
          );
          await tester.pump(const Duration(milliseconds: 55));
        }
        await driver.tapLikeUser(
          find
              .byKey(const ValueKey('design-system-filter-save-commit'))
              .hitTestable(),
        );
        await driver.pumpUntil(
          () async {
            final saved = await getIt<SettingsDb>().itemByKey(
              'SAVED_TASK_FILTERS',
            );
            return saved != null && saved.contains(filterName);
          },
          description: 'named filter persisted',
        );
      });

      await driver.step('outro', () async {});

      driver.timeline.write();
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
