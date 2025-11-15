import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/surveys/tools/calculate.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:research_package/model.dart';

// Mocks
class MockJournalDb extends Mock implements JournalDb {}

class MockFts5Db extends Mock implements Fts5Db {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockVectorClockService extends Mock implements VectorClockService {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockTagsService extends Mock implements TagsService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockTimeService extends Mock implements TimeService {}

class MockLoggingService extends Mock implements LoggingService {}

class MockRPTaskResult extends Mock implements RPTaskResult {}

class MockRPStepResult extends Mock implements RPStepResult {}

class MockRPImageChoice extends Mock implements RPImageChoice {}

class MockRPChoice extends Mock implements RPChoice {}

class FakeSurveyData extends Fake implements SurveyData {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPersistenceLogic mockPersistenceLogic;

  setUpAll(() {
    getIt.pushNewScope();

    // Register fallback values for mocktail
    registerFallbackValue(FakeSurveyData());

    mockPersistenceLogic = MockPersistenceLogic();

    getIt
      ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true))
      ..registerSingleton<JournalDb>(MockJournalDb())
      ..registerSingleton<Fts5Db>(MockFts5Db())
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<VectorClockService>(MockVectorClockService())
      ..registerSingleton<UpdateNotifications>(MockUpdateNotifications())
      ..registerSingleton<TagsService>(MockTagsService())
      ..registerSingleton<NotificationService>(MockNotificationService())
      ..registerSingleton<TimeService>(MockTimeService())
      ..registerSingleton<LoggingService>(MockLoggingService());
  });

  tearDownAll(() async {
    await getIt.resetScope();
    await getIt.popScope();
  });

  group('calculateScores', () {
    test('calculates score with RPImageChoice values', () {
      // Test the specific code path: choice is RPImageChoice
      final mockTaskResult = MockRPTaskResult();
      final mockStepResult = MockRPStepResult();
      final mockImageChoice = MockRPImageChoice();

      // Setup: ImageChoice with value 5
      when(() => mockImageChoice.value).thenReturn(5);
      when(() => mockStepResult.results)
          .thenReturn({'answer': mockImageChoice});
      when(() => mockTaskResult.results).thenReturn({
        'question1': mockStepResult,
      });

      final scoreDefinitions = {
        'total': {'question1'},
      };

      final scores = calculateScores(
        scoreDefinitions: scoreDefinitions,
        taskResult: mockTaskResult,
      );

      expect(scores['total'], equals(5));
    });

    test('calculates score with multiple RPImageChoice values', () {
      final mockTaskResult = MockRPTaskResult();
      final mockStepResult1 = MockRPStepResult();
      final mockStepResult2 = MockRPStepResult();
      final mockImageChoice1 = MockRPImageChoice();
      final mockImageChoice2 = MockRPImageChoice();

      when(() => mockImageChoice1.value).thenReturn(3);
      when(() => mockImageChoice2.value).thenReturn(7);
      when(() => mockStepResult1.results)
          .thenReturn({'answer': mockImageChoice1});
      when(() => mockStepResult2.results)
          .thenReturn({'answer': mockImageChoice2});
      when(() => mockTaskResult.results).thenReturn({
        'question1': mockStepResult1,
        'question2': mockStepResult2,
      });

      final scoreDefinitions = {
        'total': {'question1', 'question2'},
      };

      final scores = calculateScores(
        scoreDefinitions: scoreDefinitions,
        taskResult: mockTaskResult,
      );

      expect(scores['total'], equals(10));
    });

    test('calculates score with List<RPChoice> values', () {
      // Test the specific code path: choice is List<RPChoice>
      final mockTaskResult = MockRPTaskResult();
      final mockStepResult = MockRPStepResult();
      final mockRPChoice = MockRPChoice();

      when(() => mockRPChoice.value).thenReturn(8);
      when(() => mockStepResult.results).thenReturn({
        'answer': [mockRPChoice],
      });
      when(() => mockTaskResult.results).thenReturn({
        'question1': mockStepResult,
      });

      final scoreDefinitions = {
        'total': {'question1'},
      };

      final scores = calculateScores(
        scoreDefinitions: scoreDefinitions,
        taskResult: mockTaskResult,
      );

      expect(scores['total'], equals(8));
    });

    test('calculates score with empty List<RPChoice>', () {
      // Test edge case: empty list should return 0
      final mockTaskResult = MockRPTaskResult();
      final mockStepResult = MockRPStepResult();

      when(() => mockStepResult.results).thenReturn({
        'answer': <RPChoice>[],
      });
      when(() => mockTaskResult.results).thenReturn({
        'question1': mockStepResult,
      });

      final scoreDefinitions = {
        'total': {'question1'},
      };

      final scores = calculateScores(
        scoreDefinitions: scoreDefinitions,
        taskResult: mockTaskResult,
      );

      expect(scores['total'], equals(0));
    });

    test('calculates score with List<RPChoice> containing multiple values', () {
      final mockTaskResult = MockRPTaskResult();
      final mockStepResult = MockRPStepResult();
      final mockRPChoice1 = MockRPChoice();
      final mockRPChoice2 = MockRPChoice();

      // Only first choice value should be used
      when(() => mockRPChoice1.value).thenReturn(4);
      when(() => mockRPChoice2.value).thenReturn(6);
      when(() => mockStepResult.results).thenReturn({
        'answer': [mockRPChoice1, mockRPChoice2],
      });
      when(() => mockTaskResult.results).thenReturn({
        'question1': mockStepResult,
      });

      final scoreDefinitions = {
        'total': {'question1'},
      };

      final scores = calculateScores(
        scoreDefinitions: scoreDefinitions,
        taskResult: mockTaskResult,
      );

      // Should use firstOrNull, so only first value
      expect(scores['total'], equals(4));
    });

    test('handles missing question key gracefully', () {
      final mockTaskResult = MockRPTaskResult();

      // Missing 'question1' key entirely
      when(() => mockTaskResult.results).thenReturn(<String, RPResult>{});

      final scoreDefinitions = {
        'total': {'question1'},
      };

      final scores = calculateScores(
        scoreDefinitions: scoreDefinitions,
        taskResult: mockTaskResult,
      );

      expect(scores['total'], equals(0));
    });

    test('handles null answer in step result', () {
      final mockTaskResult = MockRPTaskResult();
      final mockStepResult = MockRPStepResult();

      when(() => mockStepResult.results).thenReturn({'answer': null});
      when(() => mockTaskResult.results).thenReturn({
        'question1': mockStepResult,
      });

      final scoreDefinitions = {
        'total': {'question1'},
      };

      final scores = calculateScores(
        scoreDefinitions: scoreDefinitions,
        taskResult: mockTaskResult,
      );

      expect(scores['total'], equals(0));
    });

    test('handles unexpected answer type', () {
      // Test the default case: neither RPImageChoice nor List<RPChoice>
      final mockTaskResult = MockRPTaskResult();
      final mockStepResult = MockRPStepResult();

      when(() => mockStepResult.results).thenReturn({
        'answer': 'unexpected string value',
      });
      when(() => mockTaskResult.results).thenReturn({
        'question1': mockStepResult,
      });

      final scoreDefinitions = {
        'total': {'question1'},
      };

      final scores = calculateScores(
        scoreDefinitions: scoreDefinitions,
        taskResult: mockTaskResult,
      );

      expect(scores['total'], equals(0));
    });

    test('calculates multiple scores for different score definitions', () {
      final mockTaskResult = MockRPTaskResult();
      final mockStepResult1 = MockRPStepResult();
      final mockStepResult2 = MockRPStepResult();
      final mockStepResult3 = MockRPStepResult();
      final mockImageChoice1 = MockRPImageChoice();
      final mockImageChoice2 = MockRPImageChoice();
      final mockImageChoice3 = MockRPImageChoice();

      when(() => mockImageChoice1.value).thenReturn(2);
      when(() => mockImageChoice2.value).thenReturn(3);
      when(() => mockImageChoice3.value).thenReturn(5);

      when(() => mockStepResult1.results)
          .thenReturn({'answer': mockImageChoice1});
      when(() => mockStepResult2.results)
          .thenReturn({'answer': mockImageChoice2});
      when(() => mockStepResult3.results)
          .thenReturn({'answer': mockImageChoice3});

      when(() => mockTaskResult.results).thenReturn({
        'q1': mockStepResult1,
        'q2': mockStepResult2,
        'q3': mockStepResult3,
      });

      final scoreDefinitions = {
        'score1': {'q1', 'q2'},
        'score2': {'q2', 'q3'},
        'total': {'q1', 'q2', 'q3'},
      };

      final scores = calculateScores(
        scoreDefinitions: scoreDefinitions,
        taskResult: mockTaskResult,
      );

      expect(scores['score1'], equals(5)); // 2 + 3
      expect(scores['score2'], equals(8)); // 3 + 5
      expect(scores['total'], equals(10)); // 2 + 3 + 5
    });

    test('handles missing question in results', () {
      final mockTaskResult = MockRPTaskResult();
      final mockStepResult = MockRPStepResult();
      final mockImageChoice = MockRPImageChoice();

      when(() => mockImageChoice.value).thenReturn(5);
      when(() => mockStepResult.results)
          .thenReturn({'answer': mockImageChoice});
      when(() => mockTaskResult.results).thenReturn({
        'question1': mockStepResult,
      });

      final scoreDefinitions = {
        'total': {'question1', 'missing_question'},
      };

      final scores = calculateScores(
        scoreDefinitions: scoreDefinitions,
        taskResult: mockTaskResult,
      );

      // Should only count question1
      expect(scores['total'], equals(5));
    });
  });

  group('createResultCallback', () {
    testWidgets('creates callback that persists survey data', (tester) async {
      final mockTaskResult = MockRPTaskResult();
      final mockStepResult = MockRPStepResult();
      final mockImageChoice = MockRPImageChoice();

      when(() => mockImageChoice.value).thenReturn(10);
      when(() => mockStepResult.results)
          .thenReturn({'answer': mockImageChoice});
      when(() => mockTaskResult.results).thenReturn({
        'question1': mockStepResult,
      });

      when(
        () => mockPersistenceLogic.createSurveyEntry(
          data: any<SurveyData>(named: 'data'),
          linkedId: any<String?>(named: 'linkedId'),
        ),
      ).thenAnswer((_) async => false);

      final scoreDefinitions = {
        'total': {'question1'},
      };

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            final callback = createResultCallback(
              scoreDefinitions: scoreDefinitions,
              context: context,
              linkedId: 'test-linked-id',
            );

            callback(mockTaskResult);

            return const SizedBox();
          },
        ),
      );

      await tester.pumpAndSettle();

      verify(
        () => mockPersistenceLogic.createSurveyEntry(
          data: any<SurveyData>(named: 'data'),
          linkedId: 'test-linked-id',
        ),
      ).called(1);
    });

    testWidgets('creates callback without linkedId', (tester) async {
      final mockTaskResult = MockRPTaskResult();
      final mockStepResult = MockRPStepResult();
      final mockRPChoice = MockRPChoice();

      when(() => mockRPChoice.value).thenReturn(7);
      when(() => mockStepResult.results).thenReturn({
        'answer': [mockRPChoice],
      });
      when(() => mockTaskResult.results).thenReturn({
        'question1': mockStepResult,
      });

      when(
        () => mockPersistenceLogic.createSurveyEntry(
          data: any<SurveyData>(named: 'data'),
          linkedId: any<String?>(named: 'linkedId'),
        ),
      ).thenAnswer((_) async => false);

      final scoreDefinitions = {
        'total': {'question1'},
      };

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            final callback = createResultCallback(
              scoreDefinitions: scoreDefinitions,
              context: context,
            );

            callback(mockTaskResult);

            return const SizedBox();
          },
        ),
      );

      await tester.pumpAndSettle();

      verify(
        () => mockPersistenceLogic.createSurveyEntry(
          data: any<SurveyData>(named: 'data'),
          linkedId: any<String?>(named: 'linkedId'),
        ),
      ).called(1);
    });
  });
}
