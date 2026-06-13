import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'entity_definitions_test_helpers.dart';

void main() {
  group('EntityDefinition JSON round-trips — static examples', () {
    final date = DateTime(2024, 1, 15, 9);
    const vc = VectorClock({'node-1': 5});

    EntityDefinition roundTrip(EntityDefinition def) =>
        EntityDefinition.fromJson(
          jsonDecode(jsonEncode(def.toJson())) as Map<String, dynamic>,
        );

    test('MeasurableDataType round-trips', () {
      final def = EntityDefinition.measurableDataType(
        id: 'mdt-1',
        createdAt: date,
        updatedAt: date,
        displayName: 'Weight',
        description: 'Body weight in kg',
        unitName: 'kg',
        version: 1,
        vectorClock: vc,
        aggregationType: AggregationType.dailyAvg,
        private: false,
        favorite: true,
        categoryId: 'cat-health',
      );
      final decoded = roundTrip(def);
      expect(decoded, def, reason: 'MeasurableDataType round-trip');
      final typed = decoded as MeasurableDataType;
      expect(typed.displayName, 'Weight');
      expect(typed.unitName, 'kg');
      expect(typed.aggregationType, AggregationType.dailyAvg);
      expect(typed.vectorClock?.vclock, {'node-1': 5});
    });

    test('MeasurableDataType with null vectorClock round-trips', () {
      final def = EntityDefinition.measurableDataType(
        id: 'mdt-2',
        createdAt: date,
        updatedAt: date,
        displayName: 'Steps',
        description: 'Step count',
        unitName: 'steps',
        version: 2,
        vectorClock: null,
      );
      final decoded = roundTrip(def);
      expect(decoded, def);
      expect((decoded as MeasurableDataType).vectorClock, isNull);
    });

    test('CategoryDefinition round-trips', () {
      final def = EntityDefinition.categoryDefinition(
        id: 'cat-1',
        createdAt: date,
        updatedAt: date,
        name: 'Health',
        vectorClock: vc,
        private: false,
        active: true,
        favorite: true,
        isAvailableForDayPlan: true,
        color: '#336699',
        defaultLanguageCode: 'en',
        speechDictionary: ['kg', 'steps', 'HR'],
      );
      final decoded = roundTrip(def);
      expect(decoded, def, reason: 'CategoryDefinition round-trip');
      final typed = decoded as CategoryDefinition;
      expect(typed.name, 'Health');
      expect(typed.speechDictionary, ['kg', 'steps', 'HR']);
      expect(typed.isAvailableForDayPlan, isTrue);
    });

    test(
      'CategoryDefinition without isAvailableForDayPlan key decodes to null',
      () {
        // JSON written by an app version that predates the day-plan flag.
        final def = EntityDefinition.categoryDefinition(
          id: 'cat-legacy',
          createdAt: date,
          updatedAt: date,
          name: 'Legacy',
          vectorClock: null,
          private: false,
          active: true,
        );
        final json = def.toJson()..remove('isAvailableForDayPlan');
        final decoded = EntityDefinition.fromJson(json) as CategoryDefinition;
        expect(decoded.isAvailableForDayPlan, isNull);
      },
    );

    test('LabelDefinition round-trips', () {
      final def = EntityDefinition.labelDefinition(
        id: 'lbl-1',
        createdAt: date,
        updatedAt: date,
        name: 'Urgent',
        color: '#FF0000',
        vectorClock: vc,
        description: 'High priority label',
        sortOrder: 1,
        applicableCategoryIds: ['cat-1', 'cat-2'],
      );
      final decoded = roundTrip(def);
      expect(decoded, def, reason: 'LabelDefinition round-trip');
      final typed = decoded as LabelDefinition;
      expect(typed.name, 'Urgent');
      expect(typed.sortOrder, 1);
      expect(typed.applicableCategoryIds, ['cat-1', 'cat-2']);
    });

    test('HabitDefinition round-trips with daily schedule', () {
      final def = EntityDefinition.habit(
        id: 'habit-1',
        createdAt: date,
        updatedAt: date,
        name: 'Exercise',
        description: 'Daily workout',
        habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
        vectorClock: vc,
        active: true,
        private: false,
        categoryId: 'cat-health',
      );
      final decoded = roundTrip(def);
      expect(decoded, def, reason: 'HabitDefinition round-trip');
      final typed = decoded as HabitDefinition;
      expect(typed.name, 'Exercise');
      final schedule = typed.habitSchedule as DailyHabitSchedule;
      expect(schedule.requiredCompletions, 1);
    });

    test('HabitDefinition with autoCompleteRule round-trips', () {
      final def = EntityDefinition.habit(
        id: 'habit-2',
        createdAt: date,
        updatedAt: date,
        name: 'Sleep',
        description: 'Sleep tracking',
        habitSchedule: const HabitSchedule.weekly(requiredCompletions: 5),
        vectorClock: null,
        active: true,
        private: false,
        autoCompleteRule: const AutoCompleteRule.health(
          dataType: 'HealthDataType.SLEEP_ASLEEP',
          minimum: 420,
        ),
      );
      final decoded = roundTrip(def);
      expect(
        decoded,
        def,
        reason: 'HabitDefinition with autoComplete round-trip',
      );
      final typed = decoded as HabitDefinition;
      expect(typed.autoCompleteRule, isNotNull);
    });

    test('DashboardDefinition with @Default(30) days round-trips', () {
      final def = EntityDefinition.dashboard(
        id: 'dash-1',
        createdAt: date,
        updatedAt: date,
        lastReviewed: date,
        name: 'Health Dashboard',
        description: 'Overview',
        items: const [
          DashboardItem.measurement(id: 'dt-1'),
          DashboardItem.habitChart(habitId: 'habit-1'),
        ],
        version: '1.0',
        vectorClock: vc,
        active: true,
        private: false,
      );
      final decoded = roundTrip(def);
      expect(decoded, def, reason: 'DashboardDefinition round-trip');
      final typed = decoded as DashboardDefinition;
      expect(typed.days, 30, reason: '@Default(30) preserved');
      expect(typed.items.length, 2);
      expect(typed.items[0], const DashboardItem.measurement(id: 'dt-1'));
    });

    test('DashboardDefinition with custom days survives round-trip', () {
      final def = EntityDefinition.dashboard(
        id: 'dash-2',
        createdAt: date,
        updatedAt: date,
        lastReviewed: date,
        name: 'Weekly',
        description: 'Weekly view',
        items: const [],
        version: '2.0',
        vectorClock: null,
        active: false,
        private: true,
        days: 7,
        reviewAt: DateTime(2024, 6, 30),
        categoryId: 'cat-productivity',
      );
      final decoded = roundTrip(def);
      expect(decoded, def, reason: 'DashboardDefinition days=7 round-trip');
      expect((decoded as DashboardDefinition).days, 7);
    });
  });

  // -------------------------------------------------------------------------
  // DashboardItem and EntityDefinition Glados round-trips
  // -------------------------------------------------------------------------
  group('DashboardItem Glados round-trips', () {
    glados.Glados(
      glados.any.generatedDashboardItem,
      glados.ExploreConfig(numRuns: 120),
    ).test('DashboardItem round-trips through JSON', (scenario) {
      final item = scenario.item;
      final decoded = DashboardItem.fromJson(
        jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, item, reason: '$scenario');
    }, tags: 'glados');
  });

  group('EntityDefinition Glados round-trips', () {
    glados.Glados(
      glados.any.generatedEntityDefinition,
      glados.ExploreConfig(),
    ).test('EntityDefinition round-trips through JSON', (scenario) {
      final def = scenario.definition;
      final decoded = EntityDefinition.fromJson(
        jsonDecode(jsonEncode(def.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, def, reason: '$scenario');
    }, tags: 'glados');
  });
}
