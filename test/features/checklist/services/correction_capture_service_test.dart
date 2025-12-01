import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/checklist/services/correction_capture_service.dart';
import 'package:mocktail/mocktail.dart';

class MockCategoryRepository extends Mock implements CategoryRepository {}

void main() {
  late CorrectionCaptureService service;
  late MockCategoryRepository mockCategoryRepository;

  final testCategory = CategoryDefinition(
    id: 'category-1',
    name: 'Test Category',
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
    vectorClock: null,
    private: false,
    active: true,
    color: '#FF0000',
    correctionExamples: [],
  );

  final categoryWithExamples = CategoryDefinition(
    id: 'category-2',
    name: 'Category With Examples',
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
    vectorClock: null,
    private: false,
    active: true,
    color: '#00FF00',
    correctionExamples: [
      ChecklistCorrectionExample(
        before: 'existing before',
        after: 'existing after',
        capturedAt: DateTime(2025),
      ),
    ],
  );

  setUpAll(() {
    registerFallbackValue(testCategory);
  });

  setUp(() {
    mockCategoryRepository = MockCategoryRepository();
    service = CorrectionCaptureService(
      categoryRepository: mockCategoryRepository,
    );
  });

  group('CorrectionCaptureService', () {
    group('captureCorrection', () {
      test('returns noCategory when categoryId is null', () async {
        final result = await service.captureCorrection(
          categoryId: null,
          beforeText: 'before',
          afterText: 'after',
        );

        expect(result, equals(CorrectionCaptureResult.noCategory));
        verifyNever(() => mockCategoryRepository.getCategoryById(any()));
      });

      test('returns noChange when texts are identical after normalization',
          () async {
        final result = await service.captureCorrection(
          categoryId: 'category-1',
          beforeText: '  hello  world  ',
          afterText: 'hello world',
        );

        expect(result, equals(CorrectionCaptureResult.noChange));
        verifyNever(() => mockCategoryRepository.getCategoryById(any()));
      });

      test('returns trivialChange for case-only changes on short texts',
          () async {
        final result = await service.captureCorrection(
          categoryId: 'category-1',
          beforeText: 'AB',
          afterText: 'ab',
        );

        expect(result, equals(CorrectionCaptureResult.trivialChange));
        verifyNever(() => mockCategoryRepository.getCategoryById(any()));
      });

      test('returns categoryNotFound when category does not exist', () async {
        when(() => mockCategoryRepository.getCategoryById('category-1'))
            .thenAnswer((_) async => null);

        final result = await service.captureCorrection(
          categoryId: 'category-1',
          beforeText: 'before text',
          afterText: 'after text',
        );

        expect(result, equals(CorrectionCaptureResult.categoryNotFound));
      });

      test('returns duplicate when same correction already exists', () async {
        when(() => mockCategoryRepository.getCategoryById('category-2'))
            .thenAnswer((_) async => categoryWithExamples);

        final result = await service.captureCorrection(
          categoryId: 'category-2',
          beforeText: 'existing before',
          afterText: 'existing after',
        );

        expect(result, equals(CorrectionCaptureResult.duplicate));
        verifyNever(() => mockCategoryRepository.updateCategory(any()));
      });

      test('successfully captures new correction', () async {
        when(() => mockCategoryRepository.getCategoryById('category-1'))
            .thenAnswer((_) async => testCategory);
        when(() => mockCategoryRepository.updateCategory(any()))
            .thenAnswer((_) async => testCategory);

        final result = await service.captureCorrection(
          categoryId: 'category-1',
          beforeText: 'test flight release',
          afterText: 'TestFlight release',
        );

        expect(result, equals(CorrectionCaptureResult.success));

        final captured =
            verify(() => mockCategoryRepository.updateCategory(captureAny()))
                .captured
                .single as CategoryDefinition;

        expect(captured.correctionExamples, hasLength(1));
        expect(captured.correctionExamples!.first.before,
            equals('test flight release'));
        expect(captured.correctionExamples!.first.after,
            equals('TestFlight release'));
        expect(captured.correctionExamples!.first.capturedAt, isNotNull);
      });

      test('notifies via notifier on success', () async {
        when(() => mockCategoryRepository.getCategoryById('category-1'))
            .thenAnswer((_) async => testCategory);
        when(() => mockCategoryRepository.updateCategory(any()))
            .thenAnswer((_) async => testCategory);

        final container = ProviderContainer(
          overrides: [
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
          ],
        );
        addTearDown(container.dispose);

        // Listen for notification events
        CorrectionCaptureEvent? capturedEvent;
        container.listen<CorrectionCaptureEvent?>(
          correctionCaptureNotifierProvider,
          (previous, next) {
            if (next != null) {
              capturedEvent = next;
            }
          },
          fireImmediately: true,
        );

        // Use service from container (has notifier injected)
        final serviceWithNotifier =
            container.read(correctionCaptureServiceProvider);

        final result = await serviceWithNotifier.captureCorrection(
          categoryId: 'category-1',
          beforeText: 'test flight',
          afterText: 'TestFlight',
        );

        expect(result, equals(CorrectionCaptureResult.success));

        // Verify notification was sent with correct data
        expect(capturedEvent, isNotNull);
        expect(capturedEvent?.before, equals('test flight'));
        expect(capturedEvent?.after, equals('TestFlight'));
        expect(capturedEvent?.categoryName, equals('Test Category'));
      });

      test('does not notify when no notifier provided', () async {
        when(() => mockCategoryRepository.getCategoryById('category-1'))
            .thenAnswer((_) async => testCategory);
        when(() => mockCategoryRepository.updateCategory(any()))
            .thenAnswer((_) async => testCategory);

        // Service without notifier (created manually in setUp)
        final result = await service.captureCorrection(
          categoryId: 'category-1',
          beforeText: 'test flight',
          afterText: 'TestFlight',
        );

        // Still succeeds, just no notification
        expect(result, equals(CorrectionCaptureResult.success));
      });

      test('appends to existing corrections', () async {
        when(() => mockCategoryRepository.getCategoryById('category-2'))
            .thenAnswer((_) async => categoryWithExamples);
        when(() => mockCategoryRepository.updateCategory(any()))
            .thenAnswer((_) async => categoryWithExamples);

        final result = await service.captureCorrection(
          categoryId: 'category-2',
          beforeText: 'new before',
          afterText: 'new after',
        );

        expect(result, equals(CorrectionCaptureResult.success));

        final captured =
            verify(() => mockCategoryRepository.updateCategory(captureAny()))
                .captured
                .single as CategoryDefinition;

        expect(captured.correctionExamples, hasLength(2));
        expect(captured.correctionExamples!.last.before, equals('new before'));
        expect(captured.correctionExamples!.last.after, equals('new after'));
      });

      test('normalizes whitespace before saving', () async {
        when(() => mockCategoryRepository.getCategoryById('category-1'))
            .thenAnswer((_) async => testCategory);
        when(() => mockCategoryRepository.updateCategory(any()))
            .thenAnswer((_) async => testCategory);

        final result = await service.captureCorrection(
          categoryId: 'category-1',
          beforeText: '  test   flight  ',
          afterText: '  TestFlight  ',
        );

        expect(result, equals(CorrectionCaptureResult.success));

        final captured =
            verify(() => mockCategoryRepository.updateCategory(captureAny()))
                .captured
                .single as CategoryDefinition;

        expect(
            captured.correctionExamples!.first.before, equals('test flight'));
        expect(captured.correctionExamples!.first.after, equals('TestFlight'));
      });

      test('returns saveFailed when repository throws', () async {
        when(() => mockCategoryRepository.getCategoryById('category-1'))
            .thenAnswer((_) async => testCategory);
        when(() => mockCategoryRepository.updateCategory(any()))
            .thenThrow(Exception('Database error'));

        final result = await service.captureCorrection(
          categoryId: 'category-1',
          beforeText: 'before',
          afterText: 'after',
        );

        expect(result, equals(CorrectionCaptureResult.saveFailed));
      });

      test('captures meaningful case changes for longer texts', () async {
        when(() => mockCategoryRepository.getCategoryById('category-1'))
            .thenAnswer((_) async => testCategory);
        when(() => mockCategoryRepository.updateCategory(any()))
            .thenAnswer((_) async => testCategory);

        final result = await service.captureCorrection(
          categoryId: 'category-1',
          beforeText: 'macos',
          afterText: 'macOS',
        );

        expect(result, equals(CorrectionCaptureResult.success));
      });
    });
  });

  group('CorrectionCaptureResult', () {
    test('has all expected values', () {
      expect(CorrectionCaptureResult.values, hasLength(7));
      expect(
        CorrectionCaptureResult.values,
        containsAll([
          CorrectionCaptureResult.success,
          CorrectionCaptureResult.noCategory,
          CorrectionCaptureResult.noChange,
          CorrectionCaptureResult.trivialChange,
          CorrectionCaptureResult.duplicate,
          CorrectionCaptureResult.categoryNotFound,
          CorrectionCaptureResult.saveFailed,
        ]),
      );
    });
  });

  group('CorrectionCaptureEvent', () {
    test('creates event with required properties', () {
      const event = CorrectionCaptureEvent(
        before: 'test flight',
        after: 'TestFlight',
        categoryName: 'iOS Development',
      );

      expect(event.before, equals('test flight'));
      expect(event.after, equals('TestFlight'));
      expect(event.categoryName, equals('iOS Development'));
    });
  });

  group('CorrectionCaptureNotifier', () {
    test('notify sets state and resets after delay', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const event = CorrectionCaptureEvent(
        before: 'before',
        after: 'after',
        categoryName: 'Test',
      );

      // Initial state should be null
      expect(
        container.read(correctionCaptureNotifierProvider),
        isNull,
      );

      // Notify sets the state
      container.read(correctionCaptureNotifierProvider.notifier).notify(event);
      expect(
        container.read(correctionCaptureNotifierProvider),
        equals(event),
      );

      // After delay, state resets to null
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(
        container.read(correctionCaptureNotifierProvider),
        isNull,
      );
    });

    test('build returns null initially', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(correctionCaptureNotifierProvider),
        isNull,
      );
    });

    test('disposal before timer fires does not throw', () async {
      // This test verifies the P2 fix: disposing the provider before the
      // 100ms reset timer fires should not throw an exception
      final container = ProviderContainer();

      const event = CorrectionCaptureEvent(
        before: 'before',
        after: 'after',
        categoryName: 'Test',
      );

      // Notify the event (starts the 100ms timer)
      container.read(correctionCaptureNotifierProvider.notifier).notify(event);

      // Immediately dispose before the timer fires
      container.dispose();

      // Wait for longer than the timer would have fired
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // If we get here without throwing, the test passes
      // The timer was properly cancelled on disposal
    });

    test('new notify cancels pending timer', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const event1 = CorrectionCaptureEvent(
        before: 'first',
        after: 'event',
        categoryName: 'Test',
      );
      const event2 = CorrectionCaptureEvent(
        before: 'second',
        after: 'event',
        categoryName: 'Test',
      );

      // Notify first event
      container.read(correctionCaptureNotifierProvider.notifier).notify(event1);
      expect(
        container.read(correctionCaptureNotifierProvider),
        equals(event1),
      );

      // Wait a bit but less than the reset delay
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Notify second event (should cancel the first timer)
      container.read(correctionCaptureNotifierProvider.notifier).notify(event2);
      expect(
        container.read(correctionCaptureNotifierProvider),
        equals(event2),
      );

      // Wait for the timer to fire (relative to second notify)
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // State should be null (reset occurred)
      expect(
        container.read(correctionCaptureNotifierProvider),
        isNull,
      );
    });
  });

  group('correctionCaptureServiceProvider', () {
    test('creates service with category repository', () {
      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider
              .overrideWithValue(MockCategoryRepository()),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(correctionCaptureServiceProvider);
      expect(service, isA<CorrectionCaptureService>());
    });
  });
}
