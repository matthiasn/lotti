import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/state/survey_chart_controller.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  late TestGetItMocks mocks;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    mocks = await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  group('SurveyChartDataController', () {
    final rangeStart = DateTime(2024, 3, 10);
    final rangeEnd = DateTime(2024, 3, 15);
    const surveyType = 'panasSurveyTask';

    test('fetches survey completions from JournalDb on build', () async {
      final entities = [
        makeSurveyEntry(
          dateFrom: DateTime(2024, 3, 12),
          calculatedScores: {
            'Positive Affect Score': 35,
            'Negative Affect Score': 15,
          },
        ),
      ];

      when(
        () => mocks.journalDb.getSurveyCompletionsByType(
          type: any(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => entities);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        surveyChartDataControllerProvider(
          surveyType: surveyType,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ).future,
      );

      expect(result, hasLength(1));
      verify(
        () => mocks.journalDb.getSurveyCompletionsByType(
          type: surveyType,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
      ).called(1);
    });

    test('refreshes on surveyNotification', () async {
      final updateController = StreamController<Set<String>>.broadcast();
      when(() => mocks.updateNotifications.updateStream)
          .thenAnswer((_) => updateController.stream);

      final firstEntities = [
        makeSurveyEntry(
          dateFrom: DateTime(2024, 3, 12),
          calculatedScores: {'Positive Affect Score': 35},
        ),
      ];
      final secondEntities = [
        makeSurveyEntry(
          dateFrom: DateTime(2024, 3, 12),
          calculatedScores: {'Positive Affect Score': 40},
          id: 'updated',
        ),
      ];

      var callCount = 0;
      when(
        () => mocks.journalDb.getSurveyCompletionsByType(
          type: any(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? firstEntities : secondEntities;
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(
        surveyChartDataControllerProvider(
          surveyType: surveyType,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ).future,
      );

      // Trigger survey notification
      updateController.add({surveyNotification});

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verify(
        () => mocks.journalDb.getSurveyCompletionsByType(
          type: surveyType,
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).called(2);

      await updateController.close();
    });

    test('does not refresh on unrelated notification', () async {
      final updateController = StreamController<Set<String>>.broadcast();
      when(() => mocks.updateNotifications.updateStream)
          .thenAnswer((_) => updateController.stream);

      when(
        () => mocks.journalDb.getSurveyCompletionsByType(
          type: any(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(
        surveyChartDataControllerProvider(
          surveyType: surveyType,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ).future,
      );

      // Trigger unrelated notification
      updateController.add({'UNRELATED'});

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Should only have been called once (initial load)
      verify(
        () => mocks.journalDb.getSurveyCompletionsByType(
          type: surveyType,
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).called(1);

      await updateController.close();
    });
  });
}
