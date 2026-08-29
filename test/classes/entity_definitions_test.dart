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
  // Habit ↔ signal association fields (B1 of the habits rework)
  // -------------------------------------------------------------------------
  group('AutoCompleteRule.workout valueType', () {
    test('round-trips a thresholded workout rule', () {
      const rule = AutoCompleteRule.workout(
        dataType: 'HKWorkoutActivityTypeRunning',
        minimum: 5,
        valueType: WorkoutValueType.distance,
      );
      final decoded = AutoCompleteRule.fromJson(
        jsonDecode(jsonEncode(rule.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, rule);
      expect(
        (decoded as AutoCompleteRuleWorkout).valueType,
        WorkoutValueType.distance,
      );
    });

    test('a payload without valueType decodes as "any workout"', () {
      final decoded = AutoCompleteRule.fromJson({
        'dataType': 'HKWorkoutActivityTypeRunning',
        'runtimeType': 'workout',
      });
      expect(
        decoded,
        const AutoCompleteRule.workout(
          dataType: 'HKWorkoutActivityTypeRunning',
        ),
      );
    });

    test(
      'an unknown valueType from a newer peer decodes as null, not a throw',
      () {
        final decoded = AutoCompleteRule.fromJson({
          'dataType': 'HKWorkoutActivityTypeRunning',
          'valueType': 'elevation',
          'runtimeType': 'workout',
        });
        expect((decoded as AutoCompleteRuleWorkout).valueType, isNull);
      },
    );
  });

  group('HabitDefinition.autoCompleteNotify', () {
    Map<String, dynamic> habitJson({bool? notify}) => {
      'id': 'habit-1',
      'createdAt': '2026-01-01T00:00:00.000',
      'updatedAt': '2026-01-01T00:00:00.000',
      'name': 'Walk',
      'description': '',
      'habitSchedule': {'requiredCompletions': 1, 'runtimeType': 'daily'},
      'vectorClock': null,
      'active': true,
      'private': false,
      'autoCompleteNotify': ?notify,
      'runtimeType': 'habit',
    };

    test('a dashboardId from an older peer is ignored, not fatal', () {
      // The field was removed with the habit editor; rows synced from a peer
      // that still writes it must decode.
      final habit =
          EntityDefinition.fromJson({...habitJson(), 'dashboardId': 'dash-1'})
              as HabitDefinition;
      expect(habit.id, 'habit-1');
    });

    test('defaults to true for habits written before the field existed', () {
      final habit = EntityDefinition.fromJson(habitJson()) as HabitDefinition;
      expect(habit.autoCompleteNotify, isTrue);
    });

    test('a stored false survives the round trip', () {
      final habit =
          EntityDefinition.fromJson(habitJson(notify: false))
              as HabitDefinition;
      expect(habit.autoCompleteNotify, isFalse);
      final again =
          EntityDefinition.fromJson(
                jsonDecode(jsonEncode(habit.toJson())) as Map<String, dynamic>,
              )
              as HabitDefinition;
      expect(again.autoCompleteNotify, isFalse);
    });
  });

  group('HabitCompletionData source', () {
    final base = {
      'dateFrom': '2026-03-15T08:12:00.000',
      'dateTo': '2026-03-15T08:12:00.000',
      'habitId': 'habit-1',
      'completionType': 'success',
    };

    test(
      'an entry written before the field existed is a manual completion',
      () {
        final data = HabitCompletionData.fromJson(base);
        expect(data.source, HabitCompletionSource.manual);
        expect(data.autoCompleteReason, isNull);
      },
    );

    test('an auto completion keeps its source and reason across JSON', () {
      final data = HabitCompletionData(
        dateFrom: DateTime(2026, 3, 15, 8, 12),
        dateTo: DateTime(2026, 3, 15, 8, 12),
        habitId: 'habit-1',
        completionType: HabitCompletionType.success,
        source: HabitCompletionSource.auto,
        autoCompleteReason: 'Steps · 7,412 steps',
      );
      final decoded = HabitCompletionData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, data);
      expect(decoded.source, HabitCompletionSource.auto);
      expect(decoded.autoCompleteReason, 'Steps · 7,412 steps');
    });

    test('an unknown source from a newer peer falls back to manual', () {
      final data = HabitCompletionData.fromJson({...base, 'source': 'agent'});
      expect(data.source, HabitCompletionSource.manual);
    });
  });

  // -------------------------------------------------------------------------
  // CategoryAutomation — the two independent automation preferences
  // -------------------------------------------------------------------------
  group('CategoryAutomation', () {
    CategoryDefinition makeCategory({
      bool? automaticInferenceEnabled,
      bool? automaticAgentWakesEnabled,
    }) {
      return CategoryDefinition(
        id: 'cat-1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        name: 'Lotti',
        vectorClock: null,
        private: false,
        active: true,
        automaticInferenceEnabled: automaticInferenceEnabled,
        automaticAgentWakesEnabled: automaticAgentWakesEnabled,
      );
    }

    // Both preferences are opt-in, so an unset value is off. For agent wakes
    // that matches the value `createTaskAgent` hardcoded before the category
    // could express one, so upgrading changes nothing.
    for (final (label, value, wakes, inference) in [
      ('unset', null, false, false),
      ('explicitly off', false, false, false),
      ('explicitly on', true, true, true),
    ]) {
      test('$label resolves to the expected effective values', () {
        expect(
          makeCategory(
            automaticAgentWakesEnabled: value,
          ).automaticAgentWakesEnabledEffective,
          wakes,
        );
        expect(
          makeCategory(
            automaticInferenceEnabled: value,
          ).automaticInferenceEnabledEffective,
          inference,
        );
      });
    }

    test('the two preferences are independent', () {
      final wakesOnly = makeCategory(automaticAgentWakesEnabled: true);
      expect(wakesOnly.automaticAgentWakesEnabledEffective, isTrue);
      expect(wakesOnly.automaticInferenceEnabledEffective, isFalse);

      final inferenceOnly = makeCategory(automaticInferenceEnabled: true);
      expect(inferenceOnly.automaticAgentWakesEnabledEffective, isFalse);
      expect(inferenceOnly.automaticInferenceEnabledEffective, isTrue);
    });

    test('round-trips through JSON', () {
      final decoded =
          EntityDefinition.fromJson(
                jsonDecode(
                      jsonEncode(
                        makeCategory(automaticAgentWakesEnabled: true).toJson(),
                      ),
                    )
                    as Map<String, dynamic>,
              )
              as CategoryDefinition;

      expect(decoded.automaticAgentWakesEnabled, isTrue);
    });

    // Categories synced from a client that predates the field arrive without
    // the key at all; they must decode rather than throw.
    test('decodes a payload written before the field existed', () {
      final json =
          jsonDecode(jsonEncode(makeCategory().toJson()))
                as Map<String, dynamic>
            ..remove('automaticAgentWakesEnabled');

      final decoded = EntityDefinition.fromJson(json) as CategoryDefinition;

      expect(decoded.automaticAgentWakesEnabled, isNull);
      expect(decoded.automaticAgentWakesEnabledEffective, isFalse);
    });
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

  group('MeasurableChoice', () {
    test('round-trips id, title and archived through JSON', () {
      const choice = MeasurableChoice(
        id: 'choice-1',
        title: 'Clear',
        archived: true,
      );
      final decoded = MeasurableChoice.fromJson(
        jsonDecode(jsonEncode(choice.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, choice);
    });

    test('archived is absent from JSON when unset and reads back null', () {
      const choice = MeasurableChoice(id: 'choice-1', title: 'Clear');
      final json = choice.toJson();
      expect(json, isNot(contains('archived')));
      expect(MeasurableChoice.fromJson(json).archived, isNull);
    });
  });

  group('MeasurableDataType value kind', () {
    MeasurableDataType measurable({
      MeasurableValueKind? valueKind,
      List<MeasurableChoice>? choices,
    }) => MeasurableDataType(
      id: 'hydration',
      displayName: 'Hydration',
      description: '',
      unitName: '',
      version: 1,
      createdAt: DateTime(2026, 8, 28),
      updatedAt: DateTime(2026, 8, 28),
      vectorClock: null,
      valueKind: valueKind,
      choices: choices,
    );

    const clear = MeasurableChoice(id: 'c-clear', title: 'Clear');
    const pale = MeasurableChoice(id: 'c-pale', title: 'Pale');
    const dark = MeasurableChoice(id: 'c-dark', title: 'Dark', archived: true);
    const brown = MeasurableChoice(
      id: 'c-brown',
      title: 'Brown',
      archived: false,
    );

    test('a definition without valueKind is a number measurable', () {
      // Every measurable persisted before the choice kind existed has no
      // valueKind key at all; that must keep reading as the numeric kind.
      final legacyJson = measurable().toJson()
        ..remove('valueKind')
        ..remove('choices');
      final decoded = EntityDefinition.fromJson(legacyJson);
      expect(decoded, isA<MeasurableDataType>());
      final dataType = decoded as MeasurableDataType;
      expect(dataType.valueKind, isNull);
      expect(dataType.isChoice, isFalse);
      expect(dataType.activeChoices, isEmpty);
      expect(dataType.archivedChoices, isEmpty);
      expect(dataType.choiceById('c-clear'), isNull);
    });

    test('a valueKind this build does not know reads as number', () {
      final json = measurable().toJson()..['valueKind'] = 'colourWheel';
      final decoded = EntityDefinition.fromJson(json) as MeasurableDataType;
      expect(decoded.valueKind, MeasurableValueKind.number);
      expect(decoded.isChoice, isFalse);
    });

    test('valueKind and choices survive a JSON round trip in order', () {
      final original = measurable(
        valueKind: MeasurableValueKind.choice,
        choices: const [clear, dark, pale],
      );
      final decoded =
          EntityDefinition.fromJson(
                jsonDecode(jsonEncode(original.toJson()))
                    as Map<String, dynamic>,
              )
              as MeasurableDataType;
      expect(decoded.valueKind, MeasurableValueKind.choice);
      expect(decoded.choices, const [clear, dark, pale]);
      expect(decoded, original);
    });

    test('isChoice is true only for the choice kind', () {
      expect(
        measurable(valueKind: MeasurableValueKind.choice).isChoice,
        isTrue,
      );
      expect(
        measurable(valueKind: MeasurableValueKind.number).isChoice,
        isFalse,
      );
    });

    test('activeChoices keeps order and drops only archived == true', () {
      final dataType = measurable(
        valueKind: MeasurableValueKind.choice,
        choices: const [pale, dark, clear, brown],
      );
      expect(dataType.activeChoices, const [pale, clear, brown]);
      expect(dataType.archivedChoices, const [dark]);
    });

    test('choiceById resolves archived choices too, and null for a miss', () {
      final dataType = measurable(
        valueKind: MeasurableValueKind.choice,
        choices: const [clear, dark],
      );
      expect(dataType.choiceById('c-dark'), dark);
      expect(dataType.choiceById('c-clear'), clear);
      expect(dataType.choiceById('c-missing'), isNull);
      expect(dataType.choiceById(null), isNull);
    });
  });

  group('MeasurementData choiceId', () {
    test('is absent for a numeric measurement and reads back null', () {
      final data = MeasurementData(
        dateFrom: DateTime(2026, 8, 28, 9),
        dateTo: DateTime(2026, 8, 28, 9),
        value: 750,
        dataTypeId: 'water',
      );
      final json = data.toJson();
      expect(json, isNot(contains('choiceId')));
      expect(MeasurementData.fromJson(json).choiceId, isNull);
    });

    test('round-trips alongside the occurrence value', () {
      final data = MeasurementData(
        dateFrom: DateTime(2026, 8, 28, 9),
        dateTo: DateTime(2026, 8, 28, 9),
        value: 1,
        dataTypeId: 'hydration',
        choiceId: 'c-clear',
      );
      final decoded = MeasurementData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.choiceId, 'c-clear');
      expect(decoded.value, 1);
      expect(decoded, data);
    });
  });
}
