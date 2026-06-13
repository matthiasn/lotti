import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'entity_definitions_test_helpers.dart';

void main() {
  group('Entity definitions tests', () {
    group('ChecklistCorrectionExample', () {
      test('can be serialized and deserialized with capturedAt', () {
        final example = ChecklistCorrectionExample(
          before: 'test flight',
          after: 'TestFlight',
          capturedAt: DateTime(2025, 1, 15, 10, 30),
        );

        final json = jsonEncode(example.toJson());
        final fromJson = ChecklistCorrectionExample.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(fromJson.before, equals('test flight'));
        expect(fromJson.after, equals('TestFlight'));
        expect(fromJson.capturedAt, equals(DateTime(2025, 1, 15, 10, 30)));
      });

      test('can be serialized and deserialized without capturedAt', () {
        const example = ChecklistCorrectionExample(
          before: 'mac os',
          after: 'macOS',
        );

        final json = jsonEncode(example.toJson());
        final fromJson = ChecklistCorrectionExample.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(fromJson.before, equals('mac os'));
        expect(fromJson.after, equals('macOS'));
        expect(fromJson.capturedAt, isNull);
      });

      test('supports equality', () {
        final example1 = ChecklistCorrectionExample(
          before: 'test',
          after: 'Test',
          capturedAt: DateTime(2025),
        );
        final example2 = ChecklistCorrectionExample(
          before: 'test',
          after: 'Test',
          capturedAt: DateTime(2025),
        );

        expect(example1, equals(example2));
      });

      glados.Glados(
        glados.any.generatedChecklistCorrectionExample,
        glados.ExploreConfig(numRuns: 140),
      ).test('round-trips generated correction examples through JSON', (
        scenario,
      ) {
        final example = scenario.example;

        final fromJson = ChecklistCorrectionExample.fromJson(
          jsonDecode(jsonEncode(example.toJson())) as Map<String, dynamic>,
        );

        expect(fromJson, equals(example), reason: '$scenario');
        expect(fromJson.capturedAt, example.capturedAt, reason: '$scenario');
      }, tags: 'glados');
    });

    test('Recursive autocomplete can be serialized and deserialized', () {
      const sleepAutoComplete = AutoCompleteRuleOr(
        rules: [
          AutoCompleteRule.and(
            rules: [
              AutoCompleteRuleHealth(
                dataType: 'HealthDataType.SLEEP_ASLEEP_CORE',
                minimum: 360,
              ),
              AutoCompleteRule.measurable(
                dataTypeId: 'dataTypeId',
                minimum: 2000,
              ),
            ],
          ),
          AutoCompleteRuleHealth(
            dataType: 'HealthDataType.SLEEP_ASLEEP_REM',
            minimum: 60,
          ),
        ],
      );

      final json = jsonEncode(sleepAutoComplete);
      final fromJson = AutoCompleteRule.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );

      expect(fromJson, sleepAutoComplete);
    });

    glados.Glados(
      glados.any.generatedAutoCompleteRule,
      // ignore: avoid_redundant_argument_values
      glados.ExploreConfig(numRuns: 100),
    ).test('round-trips generated autocomplete rule trees through JSON', (
      scenario,
    ) {
      final rule = scenario.rule;

      final fromJson = AutoCompleteRule.fromJson(
        jsonDecode(jsonEncode(rule.toJson())) as Map<String, dynamic>,
      );

      expect(fromJson, equals(rule), reason: '$scenario');
    }, tags: 'glados');
  });

  // -------------------------------------------------------------------------
  // DashboardItem — all 5 variants
  // -------------------------------------------------------------------------
  group('DashboardItem JSON round-trips — static examples', () {
    DashboardItem roundTrip(DashboardItem item) => DashboardItem.fromJson(
      jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>,
    );

    test('DashboardItem.measurement round-trips', () {
      const item = DashboardItem.measurement(id: 'dt-1');
      final decoded = roundTrip(item);
      expect(decoded, item, reason: 'measurement item round-trip');
      expect((decoded as DashboardMeasurementItem).id, 'dt-1');
    });

    test('DashboardItem.measurement with aggregationType round-trips', () {
      const item = DashboardItem.measurement(
        id: 'dt-2',
        aggregationType: AggregationType.dailySum,
      );
      final decoded = roundTrip(item);
      expect(decoded, item);
      expect(
        (decoded as DashboardMeasurementItem).aggregationType,
        AggregationType.dailySum,
      );
    });

    test('DashboardItem.healthChart round-trips', () {
      const item = DashboardItem.healthChart(
        color: '#FF0000',
        healthType: 'HealthDataType.STEPS',
      );
      final decoded = roundTrip(item);
      expect(decoded, item, reason: 'healthChart item round-trip');
      expect((decoded as DashboardHealthItem).color, '#FF0000');
    });

    test('DashboardItem.workoutChart round-trips', () {
      const item = DashboardItem.workoutChart(
        workoutType: 'HKWorkoutActivityTypeRunning',
        displayName: 'Running',
        color: '#00FF00',
        valueType: WorkoutValueType.distance,
      );
      final decoded = roundTrip(item);
      expect(decoded, item, reason: 'workoutChart item round-trip');
      expect(
        (decoded as DashboardWorkoutItem).valueType,
        WorkoutValueType.distance,
      );
    });

    test('DashboardItem.habitChart round-trips', () {
      const item = DashboardItem.habitChart(habitId: 'habit-abc');
      final decoded = roundTrip(item);
      expect(decoded, item, reason: 'habitChart item round-trip');
      expect((decoded as DashboardHabitItem).habitId, 'habit-abc');
    });

    test('DashboardItem.surveyChart round-trips', () {
      const item = DashboardItem.surveyChart(
        colorsByScoreKey: {'stress': '#FF6600', 'energy': '#00CCFF'},
        surveyType: 'PHQ9',
        surveyName: 'PHQ-9 Depression',
      );
      final decoded = roundTrip(item);
      expect(decoded, item, reason: 'surveyChart item round-trip');
      expect(
        (decoded as DashboardSurveyItem).colorsByScoreKey,
        {'stress': '#FF6600', 'energy': '#00CCFF'},
      );
    });
  });

  // -------------------------------------------------------------------------
  // EntityDefinition — all 5 variants
  // -------------------------------------------------------------------------
}
