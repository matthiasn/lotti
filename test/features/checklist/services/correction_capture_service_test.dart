import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/checklist/services/correction_capture_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

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

      test(
        'returns noChange when texts are identical after normalization',
        () async {
          final result = await service.captureCorrection(
            categoryId: 'category-1',
            beforeText: '  hello  world  ',
            afterText: 'hello world',
          );

          expect(result, equals(CorrectionCaptureResult.noChange));
          verifyNever(() => mockCategoryRepository.getCategoryById(any()));
        },
      );

      test(
        'returns trivialChange for case-only changes on short texts',
        () async {
          final result = await service.captureCorrection(
            categoryId: 'category-1',
            beforeText: 'AB',
            afterText: 'ab',
          );

          expect(result, equals(CorrectionCaptureResult.trivialChange));
          verifyNever(() => mockCategoryRepository.getCategoryById(any()));
        },
      );

      test('returns categoryNotFound when category does not exist', () async {
        when(
          () => mockCategoryRepository.getCategoryById('category-1'),
        ).thenAnswer((_) async => null);

        final result = await service.captureCorrection(
          categoryId: 'category-1',
          beforeText: 'before text',
          afterText: 'after text',
        );

        expect(result, equals(CorrectionCaptureResult.categoryNotFound));
      });

      test('returns duplicate when same correction already exists', () async {
        when(
          () => mockCategoryRepository.getCategoryById('category-2'),
        ).thenAnswer((_) async => categoryWithExamples);

        final result = await service.captureCorrection(
          categoryId: 'category-2',
          beforeText: 'existing before',
          afterText: 'existing after',
        );

        expect(result, equals(CorrectionCaptureResult.duplicate));
        verifyNever(() => mockCategoryRepository.updateCategory(any()));
      });

      test(
        'returns pending for valid new correction (no immediate save)',
        () async {
          when(
            () => mockCategoryRepository.getCategoryById('category-1'),
          ).thenAnswer((_) async => testCategory);

          final result = await service.captureCorrection(
            categoryId: 'category-1',
            beforeText: 'test flight release',
            afterText: 'TestFlight release',
          );

          expect(result, equals(CorrectionCaptureResult.pending));

          // Verify no immediate save
          verifyNever(() => mockCategoryRepository.updateCategory(any()));
        },
      );

      test('sets pending correction on notifier', () async {
        when(
          () => mockCategoryRepository.getCategoryById('category-1'),
        ).thenAnswer((_) async => testCategory);

        final container = ProviderContainer(
          overrides: [
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
          ],
        );
        addTearDown(container.dispose);

        // Listen for pending correction events
        PendingCorrection? capturedPending;
        container.listen<PendingCorrection?>(
          correctionCaptureProvider,
          (previous, next) {
            if (next != null) {
              capturedPending = next;
            }
          },
          fireImmediately: true,
        );

        // Use service from container (has notifier injected)
        final serviceWithNotifier = container.read(
          correctionCaptureServiceProvider,
        );

        final result = await serviceWithNotifier.captureCorrection(
          categoryId: 'category-1',
          beforeText: 'test flight',
          afterText: 'TestFlight',
        );

        expect(result, equals(CorrectionCaptureResult.pending));

        // Verify pending correction was set with correct data
        expect(capturedPending, isNotNull);
        expect(capturedPending?.before, equals('test flight'));
        expect(capturedPending?.after, equals('TestFlight'));
        expect(capturedPending?.categoryName, equals('Test Category'));
        expect(capturedPending?.categoryId, equals('category-1'));
      });

      test('does not set pending when no notifier provided', () async {
        when(
          () => mockCategoryRepository.getCategoryById('category-1'),
        ).thenAnswer((_) async => testCategory);

        // Service without notifier (created manually in setUp)
        final result = await service.captureCorrection(
          categoryId: 'category-1',
          beforeText: 'test flight',
          afterText: 'TestFlight',
        );

        // Still returns pending, just no notifier to call
        expect(result, equals(CorrectionCaptureResult.pending));
      });

      test('sets pending and does not immediately save', () async {
        when(
          () => mockCategoryRepository.getCategoryById('category-1'),
        ).thenAnswer((_) async => testCategory);

        final container = ProviderContainer(
          overrides: [
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
          ],
        );
        addTearDown(container.dispose);

        final serviceWithNotifier = container.read(
          correctionCaptureServiceProvider,
        );

        // Call captureCorrection
        await serviceWithNotifier.captureCorrection(
          categoryId: 'category-1',
          beforeText: 'test flight',
          afterText: 'TestFlight',
        );

        // Verify getCategoryById was called for validation
        verify(
          () => mockCategoryRepository.getCategoryById('category-1'),
        ).called(1);

        // Verify NO immediate save
        verifyNever(() => mockCategoryRepository.updateCategory(any()));

        // Verify pending state was set
        final pending = container.read(correctionCaptureProvider);
        expect(pending, isNotNull);
        expect(pending!.before, equals('test flight'));
        expect(pending.after, equals('TestFlight'));
        expect(pending.categoryName, equals('Test Category'));
      });

      test('normalizes whitespace when setting pending', () async {
        when(
          () => mockCategoryRepository.getCategoryById('category-1'),
        ).thenAnswer((_) async => testCategory);

        final container = ProviderContainer(
          overrides: [
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
          ],
        );
        addTearDown(container.dispose);

        // Listen for pending correction events
        PendingCorrection? capturedPending;
        container.listen<PendingCorrection?>(
          correctionCaptureProvider,
          (previous, next) {
            if (next != null) {
              capturedPending = next;
            }
          },
          fireImmediately: true,
        );

        final serviceWithNotifier = container.read(
          correctionCaptureServiceProvider,
        );

        await serviceWithNotifier.captureCorrection(
          categoryId: 'category-1',
          beforeText: '  test   flight  ',
          afterText: '  TestFlight  ',
        );

        expect(capturedPending?.before, equals('test flight'));
        expect(capturedPending?.after, equals('TestFlight'));
      });

      test('captures meaningful case changes for longer texts', () async {
        when(
          () => mockCategoryRepository.getCategoryById('category-1'),
        ).thenAnswer((_) async => testCategory);

        final result = await service.captureCorrection(
          categoryId: 'category-1',
          beforeText: 'macos',
          afterText: 'macOS',
        );

        expect(result, equals(CorrectionCaptureResult.pending));
      });
    });
  });

  group('CorrectionCaptureResult', () {
    test('has all expected values', () {
      expect(CorrectionCaptureResult.values, hasLength(6));
      expect(
        CorrectionCaptureResult.values,
        containsAll([
          CorrectionCaptureResult.pending,
          CorrectionCaptureResult.noCategory,
          CorrectionCaptureResult.noChange,
          CorrectionCaptureResult.trivialChange,
          CorrectionCaptureResult.duplicate,
          CorrectionCaptureResult.categoryNotFound,
        ]),
      );
    });
  });

  group('PendingCorrection', () {
    test('creates with required properties', () {
      final createdAt = DateTime(2025, 1, 15, 10);
      final pending = PendingCorrection(
        before: 'test flight',
        after: 'TestFlight',
        categoryId: 'cat-1',
        categoryName: 'iOS Development',
        createdAt: createdAt,
      );

      expect(pending.before, equals('test flight'));
      expect(pending.after, equals('TestFlight'));
      expect(pending.categoryId, equals('cat-1'));
      expect(pending.categoryName, equals('iOS Development'));
      expect(pending.createdAt, equals(createdAt));
    });

    test('remainingTime returns the exact remaining duration', () {
      // Pin the wall clock 2 s after creation so the 5 s save delay leaves
      // exactly 3 s — deterministic, no real-clock variance
      // (fake-time policy).
      final createdAt = DateTime(2025, 1, 1, 12);
      final pending = PendingCorrection(
        before: 'before',
        after: 'after',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: createdAt,
      );

      final remaining = withClock(
        Clock.fixed(DateTime(2025, 1, 1, 12, 0, 2)),
        () => pending.remainingTime,
      );
      expect(remaining, equals(const Duration(seconds: 3)));
    });

    test('remainingTime returns zero when expired', () {
      // Pin the wall clock 10 s after creation — past the 5 s save delay.
      final createdAt = DateTime(2025, 1, 1, 12);
      final pending = PendingCorrection(
        before: 'before',
        after: 'after',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: createdAt,
      );

      final remaining = withClock(
        Clock.fixed(DateTime(2025, 1, 1, 12, 0, 10)),
        () => pending.remainingTime,
      );
      expect(remaining, equals(Duration.zero));
    });
  });

  group('CorrectionCaptureNotifier', () {
    test('build returns null initially', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(correctionCaptureProvider),
        isNull,
      );
    });

    test('setPending sets state correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final pending = PendingCorrection(
        before: 'before',
        after: 'after',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: DateTime(2024, 3, 15, 10, 30),
      );

      // Set pending with save callback
      container
          .read(correctionCaptureProvider.notifier)
          .setPending(
            pending: pending,
            onSave: () async {},
          );

      // State should be set
      expect(
        container.read(correctionCaptureProvider),
        equals(pending),
      );
    });

    test('cancel clears state immediately', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final pending = PendingCorrection(
        before: 'before',
        after: 'after',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: DateTime(2024, 3, 15, 10, 31),
      );

      // Set pending with save callback
      container
          .read(correctionCaptureProvider.notifier)
          .setPending(
            pending: pending,
            onSave: () async {},
          );

      // State should be set
      expect(
        container.read(correctionCaptureProvider),
        equals(pending),
      );

      // Cancel the pending correction immediately
      final wasCancelled = container
          .read(correctionCaptureProvider.notifier)
          .cancel();

      expect(wasCancelled, isTrue);

      // State should be cleared immediately
      expect(
        container.read(correctionCaptureProvider),
        isNull,
      );
    });

    test('cancel returns false when no pending correction', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final wasCancelled = container
          .read(correctionCaptureProvider.notifier)
          .cancel();

      expect(wasCancelled, isFalse);
    });

    test('new setPending replaces previous pending', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final pending1 = PendingCorrection(
        before: 'first',
        after: 'event',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: DateTime(2024, 3, 15, 10, 32),
      );

      // Set first pending
      container
          .read(correctionCaptureProvider.notifier)
          .setPending(
            pending: pending1,
            onSave: () async {},
          );

      expect(
        container.read(correctionCaptureProvider),
        equals(pending1),
      );

      final pending2 = PendingCorrection(
        before: 'second',
        after: 'event',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: DateTime(2024, 3, 15, 10, 33),
      );

      // Set second pending (should replace first)
      container
          .read(correctionCaptureProvider.notifier)
          .setPending(
            pending: pending2,
            onSave: () async {},
          );

      // State should now be pending2
      expect(
        container.read(correctionCaptureProvider),
        equals(pending2),
      );

      // Verify pending1 is no longer the state
      expect(
        container.read(correctionCaptureProvider),
        isNot(equals(pending1)),
      );
    });

    test('disposal before timer fires does not throw', () {
      fakeAsync((async) {
        final container = ProviderContainer();

        final pending = PendingCorrection(
          before: 'before',
          after: 'after',
          categoryId: 'cat-1',
          categoryName: 'Test',
          createdAt: DateTime(2024, 3, 15),
        );

        // Set pending (starts the save timer)
        container
            .read(correctionCaptureProvider.notifier)
            .setPending(
              pending: pending,
              onSave: () async {},
            );

        // Immediately dispose before the timer fires
        container.dispose();

        // Elapse past the save delay — if the timer wasn't cancelled,
        // the callback would fire on a disposed container and throw.
        async.elapse(kCorrectionSaveDelay + const Duration(milliseconds: 100));

        // If we get here without throwing, the test passes
        // The timer was properly cancelled on disposal
      });
    });

    test('setPending starts timer and cancel prevents onSave', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var saveCalled = false;

      final pending = PendingCorrection(
        before: 'before',
        after: 'after',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: DateTime(2024, 3, 15, 10, 35),
      );

      container
          .read(correctionCaptureProvider.notifier)
          .setPending(
            pending: pending,
            onSave: () async {
              saveCalled = true;
            },
          );

      // State should be set
      expect(container.read(correctionCaptureProvider), equals(pending));

      // Cancel immediately
      container.read(correctionCaptureProvider.notifier).cancel();

      // State should be null
      expect(container.read(correctionCaptureProvider), isNull);

      // Save should NOT have been called (cancelled before timer)
      expect(saveCalled, isFalse);
    });

    test('multiple setPending calls cancel previous timer', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var firstSaveCalled = false;
      var secondSaveCalled = false;

      final pending1 = PendingCorrection(
        before: 'first',
        after: 'after1',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: DateTime(2024, 3, 15, 10, 36),
      );

      container
          .read(correctionCaptureProvider.notifier)
          .setPending(
            pending: pending1,
            onSave: () async {
              firstSaveCalled = true;
            },
          );

      final pending2 = PendingCorrection(
        before: 'second',
        after: 'after2',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: DateTime(2024, 3, 15, 10, 37),
      );

      // Setting a new pending should replace the first one
      container
          .read(correctionCaptureProvider.notifier)
          .setPending(
            pending: pending2,
            onSave: () async {
              secondSaveCalled = true;
            },
          );

      // State should be the second pending
      expect(
        container.read(correctionCaptureProvider),
        equals(pending2),
      );

      // Neither save should be called yet (both are pending)
      expect(firstSaveCalled, isFalse);
      expect(secondSaveCalled, isFalse);
    });
  });

  group('correctionCaptureServiceProvider', () {
    test('wires the overridden category repository into the service', () async {
      final repo = MockCategoryRepository();
      when(() => repo.getCategoryById('missing')).thenAnswer((_) async => null);

      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(correctionCaptureServiceProvider);

      // The capture call must route through the injected repository — the
      // null lookup result surfaces as categoryNotFound.
      final result = await service.captureCorrection(
        categoryId: 'missing',
        beforeText: 'test flight',
        afterText: 'TestFlight',
      );
      expect(result, CorrectionCaptureResult.categoryNotFound);
      verify(() => repo.getCategoryById('missing')).called(1);
    });
  });

  group('CorrectionCaptureNotifier – timer fires and clears state', () {
    test(
      'timer fires after delay: onSave is called and state is cleared',
      () {
        fakeAsync((async) {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          // Subscribe so the provider stays active; without a live listener,
          // Riverpod may not execute the timer callback reliably.
          container.listen<PendingCorrection?>(
            correctionCaptureProvider,
            (_, _) {},
            fireImmediately: true,
          );

          var saveCalled = false;

          final pending = PendingCorrection(
            before: 'before',
            after: 'after',
            categoryId: 'cat-1',
            categoryName: 'Test',
            createdAt: DateTime(2024, 3, 15),
          );

          container
              .read(correctionCaptureProvider.notifier)
              .setPending(
                pending: pending,
                onSave: () async {
                  saveCalled = true;
                },
              );

          expect(container.read(correctionCaptureProvider), equals(pending));

          // Advance time past the save delay, then flush microtasks to
          // complete the async continuation after onSave().
          async
            ..elapse(kCorrectionSaveDelay + const Duration(milliseconds: 100))
            ..flushMicrotasks();

          expect(saveCalled, isTrue);
          expect(container.read(correctionCaptureProvider), isNull);
        });
      },
    );

    test(
      'timer callback handles onSave exception without crashing; state is cleared',
      () {
        fakeAsync((async) {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          container.listen<PendingCorrection?>(
            correctionCaptureProvider,
            (_, _) {},
            fireImmediately: true,
          );

          final pending = PendingCorrection(
            before: 'before',
            after: 'after',
            categoryId: 'cat-1',
            categoryName: 'Test',
            createdAt: DateTime(2024, 3, 15),
          );

          container
              .read(correctionCaptureProvider.notifier)
              .setPending(
                pending: pending,
                onSave: () async {
                  throw Exception('save failed');
                },
              );

          expect(container.read(correctionCaptureProvider), equals(pending));

          // Should not throw even though onSave throws.
          expect(
            () => async
              ..elapse(
                kCorrectionSaveDelay + const Duration(milliseconds: 100),
              )
              ..flushMicrotasks(),
            returnsNormally,
          );

          // State is cleared even when onSave throws
          expect(container.read(correctionCaptureProvider), isNull);
        });
      },
    );

    test(
      'timer does not call onSave when state was changed before it fires',
      () {
        fakeAsync((async) {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          // Subscribe so the provider stays active.
          container.listen<PendingCorrection?>(
            correctionCaptureProvider,
            (_, _) {},
            fireImmediately: true,
          );

          var firstSaveCalled = false;
          var secondSaveCalled = false;

          final pending1 = PendingCorrection(
            before: 'first',
            after: 'after1',
            categoryId: 'cat-1',
            categoryName: 'Test',
            createdAt: DateTime(2024, 3, 15, 10),
          );

          container
              .read(correctionCaptureProvider.notifier)
              .setPending(
                pending: pending1,
                onSave: () async {
                  firstSaveCalled = true;
                },
              );

          final pending2 = PendingCorrection(
            before: 'second',
            after: 'after2',
            categoryId: 'cat-1',
            categoryName: 'Test',
            createdAt: DateTime(2024, 3, 15, 11),
          );

          // Replace with a second pending before timer fires.
          // The first timer is cancelled; only the second timer fires.
          container
              .read(correctionCaptureProvider.notifier)
              .setPending(
                pending: pending2,
                onSave: () async {
                  secondSaveCalled = true;
                },
              );

          async
            ..elapse(kCorrectionSaveDelay + const Duration(milliseconds: 100))
            ..flushMicrotasks();

          expect(firstSaveCalled, isFalse);
          expect(secondSaveCalled, isTrue);
          expect(container.read(correctionCaptureProvider), isNull);
        });
      },
    );
  });

  group('PendingCorrection – equality and hashCode', () {
    test('two distinct PendingCorrection instances are not equal', () {
      final a = PendingCorrection(
        before: 'before',
        after: 'after',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: DateTime(2024, 3, 15),
      );
      final b = PendingCorrection(
        before: 'before',
        after: 'after',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: DateTime(2024, 3, 15),
      );

      // Each constructor call gets a new auto-incremented id, so they differ
      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('same instance is equal to itself', () {
      final a = PendingCorrection(
        before: 'before',
        after: 'after',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: DateTime(2024, 3, 15),
      );

      expect(a == a, isTrue);
      expect(a.hashCode, equals(a.hashCode));
    });

    test('equality returns false for non-PendingCorrection object', () {
      final a = PendingCorrection(
        before: 'before',
        after: 'after',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: DateTime(2024, 3, 15),
      );

      // ignore: unrelated_type_equality_checks
      expect(a == 'not a PendingCorrection', isFalse);
    });
  });

  group('_saveCorrection – full persistence path via timer', () {
    test(
      'saves correction to repository after timer fires',
      () {
        fakeAsync((async) {
          when(
            () => mockCategoryRepository.getCategoryById('category-1'),
          ).thenAnswer((_) async => testCategory);
          when(
            () => mockCategoryRepository.updateCategory(any()),
          ).thenAnswer((_) async => testCategory);

          final container = ProviderContainer(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(
                mockCategoryRepository,
              ),
            ],
          );
          addTearDown(container.dispose);

          // Keep the correctionCaptureProvider active so the timer fires.
          container.listen<PendingCorrection?>(
            correctionCaptureProvider,
            (_, _) {},
            fireImmediately: true,
          );

          // Kick off async captureCorrection inside fakeAsync. Flush once to
          // drain the initial getCategoryById + setPending calls, then advance
          // past save delay. Multiple additional flushes drain the async chain
          // inside _saveCorrection (getCategoryById → updateCategory).
          container
              .read(correctionCaptureServiceProvider)
              .captureCorrection(
                categoryId: 'category-1',
                beforeText: 'test flight',
                afterText: 'TestFlight',
              );
          async
            ..flushMicrotasks()
            ..elapse(kCorrectionSaveDelay + const Duration(milliseconds: 100))
            ..flushMicrotasks()
            ..flushMicrotasks()
            ..flushMicrotasks();

          // updateCategory must have been called once with the new example
          final captured = verify(
            () => mockCategoryRepository.updateCategory(captureAny()),
          ).captured;
          expect(captured, hasLength(1));
          final saved = captured.first as CategoryDefinition;
          expect(saved.correctionExamples, hasLength(1));
          expect(saved.correctionExamples!.first.before, equals('test flight'));
          expect(saved.correctionExamples!.first.after, equals('TestFlight'));
        });
      },
    );

    test(
      'aborts save when category disappears between pending and timer firing',
      () {
        fakeAsync((async) {
          // First call (during captureCorrection) returns the category
          // Second call (during _saveCorrection after delay) returns null
          var callCount = 0;
          when(
            () => mockCategoryRepository.getCategoryById('category-1'),
          ).thenAnswer((_) async {
            callCount++;
            return callCount == 1 ? testCategory : null;
          });

          final container = ProviderContainer(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(
                mockCategoryRepository,
              ),
            ],
          );
          addTearDown(container.dispose);

          container.listen<PendingCorrection?>(
            correctionCaptureProvider,
            (_, _) {},
            fireImmediately: true,
          );

          container
              .read(correctionCaptureServiceProvider)
              .captureCorrection(
                categoryId: 'category-1',
                beforeText: 'test flight',
                afterText: 'TestFlight',
              );
          async
            ..flushMicrotasks()
            ..elapse(kCorrectionSaveDelay + const Duration(milliseconds: 100))
            ..flushMicrotasks()
            ..flushMicrotasks()
            ..flushMicrotasks();

          // Category was gone at save time — updateCategory must NOT be called
          verifyNever(() => mockCategoryRepository.updateCategory(any()));
        });
      },
    );

    test(
      'aborts save when duplicate appears between pending and timer firing',
      () {
        fakeAsync((async) {
          // First call: no existing examples (passes duplicate check in captureCorrection)
          // Second call: example already added by something else
          var callCount = 0;
          when(
            () => mockCategoryRepository.getCategoryById('category-1'),
          ).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) return testCategory;
            // On second call (inside _saveCorrection), duplicate is present
            return testCategory.copyWith(
              correctionExamples: [
                ChecklistCorrectionExample(
                  before: 'test flight',
                  after: 'TestFlight',
                  capturedAt: DateTime(2024, 3, 15),
                ),
              ],
            );
          });

          final container = ProviderContainer(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(
                mockCategoryRepository,
              ),
            ],
          );
          addTearDown(container.dispose);

          container.listen<PendingCorrection?>(
            correctionCaptureProvider,
            (_, _) {},
            fireImmediately: true,
          );

          container
              .read(correctionCaptureServiceProvider)
              .captureCorrection(
                categoryId: 'category-1',
                beforeText: 'test flight',
                afterText: 'TestFlight',
              );
          async
            ..flushMicrotasks()
            ..elapse(kCorrectionSaveDelay + const Duration(milliseconds: 100))
            ..flushMicrotasks()
            ..flushMicrotasks()
            ..flushMicrotasks();

          // Duplicate found at save time — updateCategory must NOT be called
          verifyNever(() => mockCategoryRepository.updateCategory(any()));
        });
      },
    );

    test(
      'logs error and does not rethrow when updateCategory throws',
      () {
        fakeAsync((async) {
          when(
            () => mockCategoryRepository.getCategoryById('category-1'),
          ).thenAnswer((_) async => testCategory);
          when(
            () => mockCategoryRepository.updateCategory(any()),
          ).thenThrow(Exception('DB write failed'));

          final container = ProviderContainer(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(
                mockCategoryRepository,
              ),
            ],
          );
          addTearDown(container.dispose);

          container.listen<PendingCorrection?>(
            correctionCaptureProvider,
            (_, _) {},
            fireImmediately: true,
          );

          container
              .read(correctionCaptureServiceProvider)
              .captureCorrection(
                categoryId: 'category-1',
                beforeText: 'test flight',
                afterText: 'TestFlight',
              );
          async.flushMicrotasks();

          // Should not throw even though updateCategory throws.
          expect(
            () => async
              ..elapse(
                kCorrectionSaveDelay + const Duration(milliseconds: 100),
              )
              ..flushMicrotasks()
              ..flushMicrotasks()
              ..flushMicrotasks(),
            returnsNormally,
          );

          // updateCategory was attempted
          verify(() => mockCategoryRepository.updateCategory(any())).called(1);
        });
      },
    );

    test(
      'appends new correction to existing examples list',
      () {
        fakeAsync((async) {
          when(
            () => mockCategoryRepository.getCategoryById('category-2'),
          ).thenAnswer((_) async => categoryWithExamples);
          when(
            () => mockCategoryRepository.updateCategory(any()),
          ).thenAnswer((_) async => categoryWithExamples);

          final container = ProviderContainer(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(
                mockCategoryRepository,
              ),
            ],
          );
          addTearDown(container.dispose);

          container.listen<PendingCorrection?>(
            correctionCaptureProvider,
            (_, _) {},
            fireImmediately: true,
          );

          container
              .read(correctionCaptureServiceProvider)
              .captureCorrection(
                categoryId: 'category-2',
                beforeText: 'new before',
                afterText: 'new after',
              );
          async
            ..flushMicrotasks()
            ..elapse(kCorrectionSaveDelay + const Duration(milliseconds: 100))
            ..flushMicrotasks()
            ..flushMicrotasks()
            ..flushMicrotasks();

          final captured = verify(
            () => mockCategoryRepository.updateCategory(captureAny()),
          ).captured;
          final saved = captured.first as CategoryDefinition;
          // Original example plus the new one
          expect(saved.correctionExamples, hasLength(2));
          expect(saved.correctionExamples!.last.before, equals('new before'));
          expect(saved.correctionExamples!.last.after, equals('new after'));
        });
      },
    );
  });
}
