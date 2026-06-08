import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import '../test_data/test_data.dart';
import 'test_utils.dart';

void main() {
  setUpAll(registerJournalDbTestFallbacks);

  JournalDb? db;
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockLoggingService = MockDomainLogger();
  late Directory testDirectory;

  group('JournalDb definitions - ', () {
    // The expensive ~40-step migration ladder runs once for the whole file;
    // each test re-uses the instance and starts clean via clearAllTables.
    setUpAll(() async {
      db = JournalDb(inMemoryDatabase: true);
    });

    setUp(() async {
      testDirectory = setupTestDirectory();
      reset(mockLoggingService);
      registerJournalDbTestServices(
        updateNotifications: mockUpdateNotifications,
        loggingService: mockLoggingService,
        documentsDirectory: testDirectory,
      );
      await clearAllTables(db!);
      await initConfigFlags(db!, inMemoryDatabase: true);
    });

    tearDown(() async {
      unregisterJournalDbTestServices();
      if (testDirectory.existsSync()) {
        testDirectory.deleteSync(recursive: true);
      }
    });

    tearDownAll(() async {
      await db?.close();
      await getIt.reset();
    });

    group('Label definition queries -', () {
      test('getAllLabelDefinitions and getLabelDefinitionById', () async {
        await db!.upsertLabelDefinition(
          LabelDefinition(
            id: 'label-1',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            name: 'Important',
            color: '#FF0000',
            vectorClock: null,
          ),
        );
        await db!.upsertLabelDefinition(
          LabelDefinition(
            id: 'label-2',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            name: 'Urgent',
            color: '#00FF00',
            vectorClock: null,
          ),
        );

        final all = await db!.getAllLabelDefinitions();
        expect(all.map((l) => l.id), containsAll(['label-1', 'label-2']));

        final single = await db!.getLabelDefinitionById('label-1');
        expect(single, isNotNull);
        expect(single!.name, 'Important');

        expect(await db!.getLabelDefinitionById('nonexistent'), isNull);
      });
    });

    group('Upsert helpers -', () {
      test('upsertMeasurableDataType inserts and updates entity', () async {
        await db!.upsertMeasurableDataType(measurableWater);
        var row = await (db!.select(
          db!.measurableTypes,
        )..where((tbl) => tbl.id.equals(measurableWater.id))).getSingle();
        expect(
          measurableDataType(row).displayName,
          measurableWater.displayName,
        );

        final updated = measurableWater.copyWith(displayName: 'Water+');
        await db!.upsertMeasurableDataType(updated);
        row = await (db!.select(
          db!.measurableTypes,
        )..where((tbl) => tbl.id.equals(measurableWater.id))).getSingle();
        expect(measurableDataType(row).displayName, 'Water+');
      });

      test('upsertHabitDefinition upserts habit', () async {
        await db!.upsertHabitDefinition(habitFlossing);
        var row = await (db!.select(
          db!.habitDefinitions,
        )..where((tbl) => tbl.id.equals(habitFlossing.id))).getSingle();
        expect(
          HabitDefinition.fromJson(
            jsonDecode(row.serialized) as Map<String, dynamic>,
          ).name,
          habitFlossing.name,
        );

        final updated = habitFlossing.copyWith(name: 'Floss Nightly');
        await db!.upsertHabitDefinition(updated);
        row = await (db!.select(
          db!.habitDefinitions,
        )..where((tbl) => tbl.id.equals(habitFlossing.id))).getSingle();
        expect(
          HabitDefinition.fromJson(
            jsonDecode(row.serialized) as Map<String, dynamic>,
          ).name,
          'Floss Nightly',
        );
      });

      test('upsertDashboardDefinition upserts dashboard', () async {
        final dashboard = testDashboardConfig.copyWith(
          id: 'dashboard-upsert',
          name: 'Initial Dashboard',
          createdAt: DateTime(2024, 12),
          updatedAt: DateTime(2024, 12),
        );
        await db!.upsertDashboardDefinition(dashboard);
        var row = await (db!.select(
          db!.dashboardDefinitions,
        )..where((tbl) => tbl.id.equals('dashboard-upsert'))).getSingle();
        expect(
          DashboardDefinition.fromJson(
            jsonDecode(row.serialized) as Map<String, dynamic>,
          ).name,
          'Initial Dashboard',
        );

        final updated = dashboard.copyWith(name: 'Updated Dashboard');
        await db!.upsertDashboardDefinition(updated);
        row = await (db!.select(
          db!.dashboardDefinitions,
        )..where((tbl) => tbl.id.equals('dashboard-upsert'))).getSingle();
        expect(
          DashboardDefinition.fromJson(
            jsonDecode(row.serialized) as Map<String, dynamic>,
          ).name,
          'Updated Dashboard',
        );
      });

      test('upsertCategoryDefinition upserts category', () async {
        await db!.upsertCategoryDefinition(categoryMindfulness);
        var row = await (db!.select(
          db!.categoryDefinitions,
        )..where((tbl) => tbl.id.equals(categoryMindfulness.id))).getSingle();
        expect(
          CategoryDefinition.fromJson(
            jsonDecode(row.serialized) as Map<String, dynamic>,
          ).name,
          categoryMindfulness.name,
        );

        final updated = categoryMindfulness.copyWith(name: 'Mindfulness+');
        await db!.upsertCategoryDefinition(updated);
        row = await (db!.select(
          db!.categoryDefinitions,
        )..where((tbl) => tbl.id.equals(categoryMindfulness.id))).getSingle();
        expect(
          CategoryDefinition.fromJson(
            jsonDecode(row.serialized) as Map<String, dynamic>,
          ).name,
          'Mindfulness+',
        );
      });

      test('upsertEntityDefinition delegates based on entity type', () async {
        final measurable = measurableWater.copyWith(
          displayName: 'Entity Water',
        );
        await db!.upsertEntityDefinition(
          EntityDefinition.measurableDataType(
            id: measurable.id,
            createdAt: measurable.createdAt,
            updatedAt: measurable.updatedAt,
            displayName: measurable.displayName,
            description: measurable.description,
            unitName: measurable.unitName,
            version: measurable.version,
            vectorClock: measurable.vectorClock,
            aggregationType: measurable.aggregationType,
            private: measurable.private ?? false,
            favorite: measurable.favorite ?? false,
            deletedAt: measurable.deletedAt,
            categoryId: measurable.categoryId,
          ),
        );
        final measurableRow = await (db!.select(
          db!.measurableTypes,
        )..where((tbl) => tbl.id.equals(measurable.id))).getSingle();
        expect(measurableDataType(measurableRow).displayName, 'Entity Water');

        final habit = habitFlossing.copyWith(name: 'Entity Habit');
        await db!.upsertEntityDefinition(
          EntityDefinition.habit(
            id: habit.id,
            createdAt: habit.createdAt,
            updatedAt: habit.updatedAt,
            name: habit.name,
            description: habit.description,
            habitSchedule: habit.habitSchedule,
            vectorClock: habit.vectorClock,
            active: habit.active,
            private: habit.private,
            autoCompleteRule: habit.autoCompleteRule,
            version: habit.version,
            activeFrom: habit.activeFrom,
            activeUntil: habit.activeUntil,
            deletedAt: habit.deletedAt,
            // ignore: deprecated_member_use_from_same_package
            defaultStoryId: habit.defaultStoryId,
            categoryId: habit.categoryId,
            dashboardId: habit.dashboardId,
            priority: habit.priority,
          ),
        );
        final habitRow = await (db!.select(
          db!.habitDefinitions,
        )..where((tbl) => tbl.id.equals(habit.id))).getSingle();
        expect(
          HabitDefinition.fromJson(
            jsonDecode(habitRow.serialized) as Map<String, dynamic>,
          ).name,
          'Entity Habit',
        );
      });
    });

    group('getAllCategories / getCategoryById -', () {
      test('getAllCategories returns inserted categories', () async {
        await db!.upsertCategoryDefinition(categoryMindfulness);
        final all = await db!.getAllCategories();
        expect(all.map((c) => c.id), contains(categoryMindfulness.id));
      });

      test('getCategoryById returns the category by id', () async {
        await db!.upsertCategoryDefinition(categoryMindfulness);
        final cat = await db!.getCategoryById(categoryMindfulness.id);
        expect(cat, isNotNull);
        expect(cat!.name, categoryMindfulness.name);
      });

      test('getCategoryById returns null for unknown id', () async {
        final cat = await db!.getCategoryById('no-such-category');
        expect(cat, isNull);
      });
    });

    group('getAllHabitDefinitions / getHabitById -', () {
      test('getAllHabitDefinitions returns inserted habits', () async {
        await db!.upsertHabitDefinition(habitFlossing);
        final all = await db!.getAllHabitDefinitions();
        expect(all.map((h) => h.id), contains(habitFlossing.id));
      });

      test('getHabitById returns the habit by id', () async {
        await db!.upsertHabitDefinition(habitFlossing);
        final habit = await db!.getHabitById(habitFlossing.id);
        expect(habit, isNotNull);
        expect(habit!.name, habitFlossing.name);
      });

      test('getHabitById returns null for unknown id', () async {
        final habit = await db!.getHabitById('no-such-habit');
        expect(habit, isNull);
      });
    });

    group('getAllDashboards / getDashboardById -', () {
      final testDashboard = testDashboardConfig.copyWith(
        id: 'db-test-dashboard-1',
      );

      test('getAllDashboards returns inserted dashboards', () async {
        await db!.upsertDashboardDefinition(testDashboard);
        final all = await db!.getAllDashboards();
        expect(all.map((x) => x.id), contains(testDashboard.id));
      });

      test('getDashboardById returns the dashboard by id', () async {
        await db!.upsertDashboardDefinition(testDashboard);
        final result = await db!.getDashboardById(testDashboard.id);
        expect(result, isNotNull);
        expect(result!.id, testDashboard.id);
      });

      test('getDashboardById returns null for unknown id', () async {
        final result = await db!.getDashboardById('no-such-dashboard');
        expect(result, isNull);
      });
    });

    group('getLabeledCount -', () {
      test('counts labeled associations', () async {
        await db!.upsertLabelDefinition(
          LabelDefinition(
            id: 'lbl-count-1',
            createdAt: DateTime(2024, 11, 4),
            updatedAt: DateTime(2024, 11, 4),
            name: 'CountLabel',
            color: '#112233',
            vectorClock: null,
          ),
        );
        final entry = buildJournalEntry(
          id: 'lbl-count-entry-1',
          timestamp: DateTime(2024, 11, 4),
          text: 'Labeled entry',
        );
        await db!.upsertJournalDbEntity(toDbEntity(entry));
        await db!.insertLabel('lbl-count-entry-1', 'lbl-count-1');

        final count = await db!.getLabeledCount();
        expect(count, 1);
      });
    });

    group('getLabelUsageCounts / getLabelUsageCountsSnapshot -', () {
      test('returns usage counts per label', () async {
        await db!.upsertLabelDefinition(
          LabelDefinition(
            id: 'lbl-usage-a',
            createdAt: DateTime(2024, 11, 5),
            updatedAt: DateTime(2024, 11, 5),
            name: 'UsageA',
            color: '#aabbcc',
            vectorClock: null,
          ),
        );
        final e1 = buildJournalEntry(
          id: 'lbl-usage-e1',
          timestamp: DateTime(2024, 11, 5),
          text: 'Entry1',
        );
        final e2 = buildJournalEntry(
          id: 'lbl-usage-e2',
          timestamp: DateTime(2024, 11, 5, 1),
          text: 'Entry2',
        );
        await db!.upsertJournalDbEntity(toDbEntity(e1));
        await db!.upsertJournalDbEntity(toDbEntity(e2));
        await db!.insertLabel('lbl-usage-e1', 'lbl-usage-a');
        await db!.insertLabel('lbl-usage-e2', 'lbl-usage-a');

        final counts = await db!.getLabelUsageCounts();
        expect(counts['lbl-usage-a'], 2);

        final snapshot = await db!.getLabelUsageCountsSnapshot();
        expect(snapshot['lbl-usage-a'], 2);
      });

      test('returns empty map when no labels are applied', () async {
        final counts = await db!.getLabelUsageCounts();
        expect(counts, isEmpty);
      });

      test('excludes labels on soft-deleted entries', () async {
        await db!.upsertLabelDefinition(
          LabelDefinition(
            id: 'lbl-usage-del',
            createdAt: DateTime(2024, 11, 6),
            updatedAt: DateTime(2024, 11, 6),
            name: 'UsageDeleted',
            color: '#aabbcc',
            vectorClock: null,
          ),
        );
        final live = buildJournalEntry(
          id: 'lbl-usage-live',
          timestamp: DateTime(2024, 11, 6),
          text: 'Live entry',
        );
        final deleted = buildJournalEntry(
          id: 'lbl-usage-deleted',
          timestamp: DateTime(2024, 11, 6, 1),
          text: 'Deleted entry',
        );
        await db!.upsertJournalDbEntity(toDbEntity(live));
        await db!.upsertJournalDbEntity(
          toDbEntity(
            deleted.copyWith(
              meta: deleted.meta.copyWith(
                deletedAt: DateTime(2024, 11, 6, 2),
              ),
            ),
          ),
        );
        await db!.insertLabel('lbl-usage-live', 'lbl-usage-del');
        await db!.insertLabel('lbl-usage-deleted', 'lbl-usage-del');

        final counts = await db!.getLabelUsageCounts();
        expect(counts['lbl-usage-del'], 1);
      });

      test(
        'counts private entries only while the private flag is on',
        () async {
          await db!.upsertLabelDefinition(
            LabelDefinition(
              id: 'lbl-usage-priv',
              createdAt: DateTime(2024, 11, 7),
              updatedAt: DateTime(2024, 11, 7),
              name: 'UsagePrivate',
              color: '#aabbcc',
              vectorClock: null,
            ),
          );
          final public = buildJournalEntry(
            id: 'lbl-usage-public',
            timestamp: DateTime(2024, 11, 7),
            text: 'Public entry',
          );
          final privateEntry = buildJournalEntry(
            id: 'lbl-usage-private',
            timestamp: DateTime(2024, 11, 7, 1),
            text: 'Private entry',
            privateFlag: true,
          );
          await db!.upsertJournalDbEntity(toDbEntity(public));
          await db!.upsertJournalDbEntity(toDbEntity(privateEntry));
          await db!.insertLabel('lbl-usage-public', 'lbl-usage-priv');
          await db!.insertLabel('lbl-usage-private', 'lbl-usage-priv');

          // initConfigFlags seeds the private flag as enabled, so both
          // entries count.
          expect((await db!.getLabelUsageCounts())['lbl-usage-priv'], 2);

          // With the flag off, the private entry's label no longer counts.
          await db!.toggleConfigFlag(privateFlag);
          expect((await db!.getLabelUsageCounts())['lbl-usage-priv'], 1);
        },
      );
    });

    group('Label reconciliation -', () {
      test('addLabeled mirrors metadata labelIds changes', () async {
        // Ensure label definitions exist to satisfy the labeled.label_id FK
        await db!.upsertLabelDefinition(
          LabelDefinition(
            id: 'alpha',
            createdAt: DateTime(2024, 3, 15, 10),
            updatedAt: DateTime(2024, 3, 15, 10),
            name: 'alpha',
            color: '#AAAAAA',
            vectorClock: null,
          ),
        );
        await db!.upsertLabelDefinition(
          LabelDefinition(
            id: 'beta',
            createdAt: DateTime(2024, 3, 15, 10),
            updatedAt: DateTime(2024, 3, 15, 10),
            name: 'beta',
            color: '#BBBBBB',
            vectorClock: null,
          ),
        );
        await db!.upsertLabelDefinition(
          LabelDefinition(
            id: 'gamma',
            createdAt: DateTime(2024, 3, 15, 10),
            updatedAt: DateTime(2024, 3, 15, 10),
            name: 'gamma',
            color: '#CCCCCC',
            vectorClock: null,
          ),
        );
        final entry = createJournalEntry(
          'with labels',
          labelIds: const ['alpha', 'beta'],
        );

        await db!.updateJournalEntity(entry);

        final initial = await db!.labeledForJournal(entry.meta.id).get();
        expect(initial, unorderedEquals(['alpha', 'beta']));

        final updated = entry.copyWith(
          meta: entry.meta.copyWith(
            labelIds: const ['beta', 'gamma'],
            updatedAt: DateTime(2024, 3, 15, 10, 1),
          ),
        );

        await db!.updateJournalEntity(updated);

        final afterUpdate = await db!.labeledForJournal(entry.meta.id).get();
        expect(afterUpdate, unorderedEquals(['beta', 'gamma']));

        final cleared = updated.copyWith(
          meta: updated.meta.copyWith(
            labelIds: null,
            updatedAt: DateTime(2024, 3, 15, 10, 2),
          ),
        );

        await db!.updateJournalEntity(cleared);

        final afterClear = await db!.labeledForJournal(entry.meta.id).get();
        expect(afterClear, isEmpty);
      });

      test('addLabeled is idempotent when metadata is unchanged', () async {
        // Ensure label definition exists to satisfy FK
        await db!.upsertLabelDefinition(
          LabelDefinition(
            id: 'keep',
            createdAt: DateTime(2024, 3, 15, 10),
            updatedAt: DateTime(2024, 3, 15, 10),
            name: 'keep',
            color: '#DDDDDD',
            vectorClock: null,
          ),
        );
        final entry = createJournalEntry(
          'idempotent labels',
          labelIds: const ['keep'],
        );

        await db!.updateJournalEntity(entry);
        await db!.updateJournalEntity(entry);

        final rows = await db!.labeledForJournal(entry.meta.id).get();
        expect(rows, unorderedEquals(['keep']));
      });
    });

    group('insertLabel error handling -', () {
      test(
        'missing label definition (FK violation) is tolerated and logged',
        () async {
          final base = DateTime(2024, 12, 2, 9);
          final entry = buildJournalEntry(
            id: 'fk-entry',
            timestamp: base,
            text: 'Entry without label definition',
          );
          await db!.upsertJournalDbEntity(toDbEntity(entry));

          DevLogger.clear();
          // The label definition has not arrived via sync yet — the FK
          // failure must be swallowed so out-of-order sync stays tolerant.
          await db!.insertLabel('fk-entry', 'label-not-synced-yet');

          expect(
            DevLogger.capturedLogs.any(
              (message) => message.contains('insertLabel failed'),
            ),
            isTrue,
          );
          final rows = await db!
              .customSelect('SELECT COUNT(*) AS c FROM labeled')
              .getSingle();
          expect(rows.read<int>('c'), 0);
        },
      );

      test('non-constraint failures propagate to the caller', () async {
        // A closed database is not a constraint violation — the error must
        // reach the caller so addLabeled's transaction rolls back. Use a
        // throwaway DB so closing it does not affect the shared instance, and
        // force its lazy connection open (run a query) before closing so the
        // closed-DB error path is actually exercised.
        final closedDb = JournalDb(inMemoryDatabase: true);
        await closedDb.listConfigFlags().get();
        await closedDb.close();
        await expectLater(
          closedDb.insertLabel('any-journal', 'any-label'),
          throwsA(anything),
        );
      });

      test(
        'duplicate (journal_id, label_id) is swallowed and logged',
        () async {
          final base = DateTime(2024, 10, 20);
          final task = buildTaskEntry(
            id: 'dup-label-task',
            timestamp: base,
            status: TaskStatus.open(
              id: 'dlt-status',
              createdAt: base,
              utcOffset: 0,
            ),
            categoryId: 'dlt-cat',
          );
          await db!.upsertJournalDbEntity(toDbEntity(task));
          await db!.upsertLabelDefinition(
            LabelDefinition(
              id: 'dup-label',
              createdAt: base,
              updatedAt: base,
              name: 'DupLabel',
              color: '#101010',
              vectorClock: null,
            ),
          );

          await db!.insertLabel('dup-label-task', 'dup-label');
          DevLogger.clear();
          // Second insert violates UNIQUE(journal_id, label_id) -> caught.
          await db!.insertLabel('dup-label-task', 'dup-label');

          // The error path logged the failure via DevLogger.
          expect(
            DevLogger.capturedLogs.any(
              (message) => message.contains('insertLabel failed'),
            ),
            isTrue,
          );

          // Only one labeled row persists for the pair.
          final rows = await db!
              .customSelect(
                'SELECT COUNT(*) AS c FROM labeled WHERE journal_id = ? '
                'AND label_id = ?',
                variables: [
                  drift.Variable.withString('dup-label-task'),
                  drift.Variable.withString('dup-label'),
                ],
              )
              .getSingle();
          expect(rows.read<int>('c'), 1);
        },
      );
    });

    group('Measurable data type queries -', () {
      test(
        'getAllMeasurableDataTypes returns active types sorted by '
        'displayName and excludes deleted ones',
        () async {
          // Insert out of alphabetical order to prove the mapper sorts.
          await db!.upsertMeasurableDataType(measurableWater); // 'Water'
          await db!.upsertMeasurableDataType(
            measurableChocolate,
          ); // 'Chocolate'
          await db!.upsertMeasurableDataType(
            measurableCoverage.copyWith(
              deletedAt: DateTime(2024, 3, 15),
            ),
          );

          final types = await db!.getAllMeasurableDataTypes();

          expect(
            types.map((t) => t.displayName).toList(),
            ['Chocolate', 'Water'],
          );
        },
      );

      test(
        'getAllMeasurableDataTypes hides private types when the private '
        'flag is off',
        () async {
          await db!.upsertMeasurableDataType(measurableChocolate);
          await db!.upsertMeasurableDataType(
            measurableWater.copyWith(private: true),
          );

          await db!.upsertConfigFlag(
            const ConfigFlag(
              name: privateFlag,
              description: 'Show private entries?',
              status: false,
            ),
          );

          final types = await db!.getAllMeasurableDataTypes();
          expect(
            types.map((t) => t.displayName).toList(),
            ['Chocolate'],
          );
        },
      );

      test(
        'getMeasurableDataTypeById returns the stored type and null for '
        'unknown ids',
        () async {
          await db!.upsertMeasurableDataType(measurableWater);

          final found = await db!.getMeasurableDataTypeById(
            measurableWater.id,
          );
          expect(found, isNotNull);
          expect(found!.displayName, 'Water');
          expect(found.unitName, 'ml');

          expect(
            await db!.getMeasurableDataTypeById('does-not-exist'),
            isNull,
          );
        },
      );
    });
  });
}
