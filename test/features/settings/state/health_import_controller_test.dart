import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:lotti/features/settings/state/health_import_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockHealthImport mockHealthImport;

  /// A deterministic "now" with a non-midnight time-of-day, so the day
  /// normalization in the range arithmetic is actually exercised.
  final now = DateTime(2024, 3, 15, 14, 30, 45, 123);

  setUp(() {
    mockHealthImport = MockHealthImport();
    getIt.registerSingleton<HealthImport>(mockHealthImport);
  });

  tearDown(getIt.reset);

  /// Grants every import method the given result.
  void stubImports(HealthImportResult result) {
    when(
      () => mockHealthImport.getActivityHealthData(
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
      ),
    ).thenAnswer((_) async => result);
    when(
      () => mockHealthImport.getWorkoutsHealthData(
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
      ),
    ).thenAnswer((_) async => result);
    when(
      () => mockHealthImport.fetchHealthData(
        types: any(named: 'types'),
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
      ),
    ).thenAnswer((_) async => result);
  }

  /// Builds a container with the clock pinned, and disposes it afterwards.
  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  T withPinnedClock<T>(T Function() body) => withClock(Clock.fixed(now), body);

  group('initial state', () {
    test('defaults to the last seven days, ending at the end of today', () {
      final state = withPinnedClock(
        () => makeContainer().read(healthImportControllerProvider),
      );

      expect(state.dateFrom, DateTime(2024, 3, 8));
      expect(state.dateTo, DateTime(2024, 3, 15, 23, 59, 59, 999));
    });

    test('the default end never lies about being in the future', () {
      // The previous page defaulted to "tomorrow" and displayed it, while the
      // import capped every request at the current instant regardless.
      final state = withPinnedClock(
        () => makeContainer().read(healthImportControllerProvider),
      );

      expect(state.dateTo.day, now.day);
      expect(state.dateTo.isAfter(now), isTrue, reason: 'covers all of today');
    });

    test('starts with no category state and nothing running', () {
      final state = withPinnedClock(
        () => makeContainer().read(healthImportControllerProvider),
      );

      expect(state.categories, isEmpty);
      expect(state.isAnyRunning, isFalse);
      for (final category in HealthImportCategory.values) {
        expect(state.stateFor(category).isRunning, isFalse);
        expect(state.stateFor(category).lastResult, isNull);
      }
    });
  });

  group('date range', () {
    test('setDateFrom normalizes to the start of the chosen day', () {
      final container = makeContainer();
      withPinnedClock(
        () => container.read(healthImportControllerProvider.notifier),
      ).setDateFrom(DateTime(2024, 2, 10, 17, 45));

      expect(
        container.read(healthImportControllerProvider).dateFrom,
        DateTime(2024, 2, 10),
      );
    });

    test('setDateTo normalizes to the end of the chosen day', () {
      final container = makeContainer();
      withPinnedClock(
        () => container.read(healthImportControllerProvider.notifier),
      ).setDateTo(DateTime(2024, 3, 10, 6));

      expect(
        container.read(healthImportControllerProvider).dateTo,
        DateTime(2024, 3, 10, 23, 59, 59, 999),
      );
    });

    test('a start after the end drags the end along', () {
      // An inverted range would silently import nothing, with the page showing
      // a plausible-looking pair of dates.
      final container = makeContainer();
      withPinnedClock(
        () => container.read(healthImportControllerProvider.notifier),
      ).setDateFrom(DateTime(2024, 5, 20));

      final state = container.read(healthImportControllerProvider);
      expect(state.dateFrom, DateTime(2024, 5, 20));
      expect(state.dateTo, DateTime(2024, 5, 20, 23, 59, 59, 999));
      expect(state.dateFrom.isAfter(state.dateTo), isFalse);
    });

    test('an end before the start drags the start along', () {
      final container = makeContainer();
      withPinnedClock(
        () => container.read(healthImportControllerProvider.notifier),
      ).setDateTo(DateTime(2024));

      final state = container.read(healthImportControllerProvider);
      expect(state.dateFrom, DateTime(2024));
      expect(state.dateTo, DateTime(2024, 1, 1, 23, 59, 59, 999));
      expect(state.dateFrom.isAfter(state.dateTo), isFalse);
    });

    test('a start still before the end leaves the end alone', () {
      final container = makeContainer();
      final controller = withPinnedClock(
        () => container.read(healthImportControllerProvider.notifier),
      );
      final originalEnd = container.read(healthImportControllerProvider).dateTo;

      // ignore: avoid_redundant_argument_values
      controller.setDateFrom(DateTime(2024, 3, 1));

      expect(
        container.read(healthImportControllerProvider).dateTo,
        originalEnd,
      );
    });

    test('an end still after the start leaves the start alone', () {
      final container = makeContainer();
      final controller = withPinnedClock(
        () => container.read(healthImportControllerProvider.notifier),
      );
      final originalStart = container
          .read(healthImportControllerProvider)
          .dateFrom;

      controller.setDateTo(DateTime(2024, 3, 14));

      expect(
        container.read(healthImportControllerProvider).dateFrom,
        originalStart,
      );
    });

    for (final days in healthImportQuickRangeDays) {
      test('the $days-day quick range spans exactly $days days back', () {
        final container = makeContainer();
        withPinnedClock(() {
          container
              .read(healthImportControllerProvider.notifier)
              .selectQuickRange(days);
        });

        final state = container.read(healthImportControllerProvider);
        expect(state.dateFrom, DateTime(2024, 3, 15 - days));
        expect(state.dateTo, DateTime(2024, 3, 15, 23, 59, 59, 999));
      });
    }
  });

  group('a result only describes the range it was imported for', () {
    Future<ProviderContainer> containerWithFinishedRun() async {
      final container = makeContainer();
      final controller = withPinnedClock(
        () => container.read(healthImportControllerProvider.notifier),
      );
      stubImports(const HealthImportResult.imported(42));
      await controller.runImport(HealthImportCategory.sleep);
      expect(
        container
            .read(healthImportControllerProvider)
            .resultFor(HealthImportCategory.sleep)
            ?.sampleCount,
        42,
      );
      return container;
    }

    HealthImportResult? sleepResult(ProviderContainer container) => container
        .read(healthImportControllerProvider)
        .resultFor(HealthImportCategory.sleep);

    test('setDateFrom hides a result from the old range', () async {
      final container = await containerWithFinishedRun();
      container
          .read(healthImportControllerProvider.notifier)
          .setDateFrom(DateTime(2024));

      expect(sleepResult(container), isNull);
    });

    test('setDateTo hides a result from the old range', () async {
      final container = await containerWithFinishedRun();
      container
          .read(healthImportControllerProvider.notifier)
          .setDateTo(DateTime(2024, 6));

      expect(sleepResult(container), isNull);
    });

    test('a quick range hides a result from the old range', () async {
      final container = await containerWithFinishedRun();
      withPinnedClock(
        () => container.read(healthImportControllerProvider.notifier),
      ).selectQuickRange(30);

      expect(sleepResult(container), isNull);
    });

    test('returning to the original range shows the result again', () async {
      // The result was never destroyed — it is keyed to its range, so the
      // range coming back brings it back rather than needing a re-import.
      final container = await containerWithFinishedRun();
      final controller = container.read(
        healthImportControllerProvider.notifier,
      );
      final original = container.read(healthImportControllerProvider);

      controller.setDateFrom(DateTime(2024));
      expect(sleepResult(container), isNull);

      controller
        ..setDateFrom(original.dateFrom)
        ..setDateTo(original.dateTo);

      expect(sleepResult(container)?.sampleCount, 42);
    });

    test(
      'a run in flight when the range changes never shows its result',
      () async {
        // The hard case: it finishes against the *old* dates, so its count would
        // otherwise land beside a range it never covered.
        final container = makeContainer();
        final controller = withPinnedClock(
          () => container.read(healthImportControllerProvider.notifier),
        );

        final gate = Completer<HealthImportResult>();
        when(
          () => mockHealthImport.fetchHealthData(
            types: any(named: 'types'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          ),
        ).thenAnswer((_) => gate.future);

        final pending = controller.runImport(HealthImportCategory.sleep);
        controller.setDateFrom(DateTime(2024));

        // The spinner keeps its row while it runs.
        expect(
          container
              .read(healthImportControllerProvider)
              .stateFor(HealthImportCategory.sleep)
              .isRunning,
          isTrue,
        );

        gate.complete(const HealthImportResult.imported(7));
        await pending;

        expect(
          container
              .read(healthImportControllerProvider)
              .stateFor(HealthImportCategory.sleep)
              .isRunning,
          isFalse,
        );
        expect(
          sleepResult(container),
          isNull,
          reason: 'imported another range',
        );
      },
    );
  });

  group('runImport', () {
    test('marks the category running, then records the result', () async {
      final container = makeContainer();
      final controller = withPinnedClock(
        () => container.read(healthImportControllerProvider.notifier),
      );

      // Hold the import open so the intermediate state is observable.
      final gate = Completer<HealthImportResult>();
      when(
        () => mockHealthImport.fetchHealthData(
          types: any(named: 'types'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((_) => gate.future);

      final pending = controller.runImport(HealthImportCategory.heartRate);

      var state = container.read(healthImportControllerProvider);
      expect(state.stateFor(HealthImportCategory.heartRate).isRunning, isTrue);
      expect(state.isAnyRunning, isTrue);

      gate.complete(const HealthImportResult.imported(12));
      await pending;

      state = container.read(healthImportControllerProvider);
      final categoryState = state.stateFor(HealthImportCategory.heartRate);
      expect(categoryState.isRunning, isFalse);
      expect(categoryState.lastResult?.sampleCount, 12);
      expect(state.isAnyRunning, isFalse);
    });

    test('a fresh run clears the previous result before it starts', () async {
      // A stale "42 samples imported" sitting next to a spinner would read as
      // a finished import.
      final container = makeContainer();
      final controller = withPinnedClock(
        () => container.read(healthImportControllerProvider.notifier),
      );

      stubImports(const HealthImportResult.imported(42));
      await controller.runImport(HealthImportCategory.sleep);
      expect(
        container
            .read(healthImportControllerProvider)
            .stateFor(HealthImportCategory.sleep)
            .lastResult
            ?.sampleCount,
        42,
      );

      final gate = Completer<HealthImportResult>();
      when(
        () => mockHealthImport.fetchHealthData(
          types: any(named: 'types'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((_) => gate.future);

      final pending = controller.runImport(HealthImportCategory.sleep);
      final running = container
          .read(healthImportControllerProvider)
          .stateFor(HealthImportCategory.sleep);
      expect(running.isRunning, isTrue);
      expect(running.lastResult, isNull);

      gate.complete(const HealthImportResult.imported(1));
      await pending;
    });

    test('refuses a second run of a category already importing', () async {
      final container = makeContainer();
      final controller = withPinnedClock(
        () => container.read(healthImportControllerProvider.notifier),
      );

      final gate = Completer<HealthImportResult>();
      when(
        () => mockHealthImport.fetchHealthData(
          types: any(named: 'types'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((_) => gate.future);

      final first = controller.runImport(HealthImportCategory.bloodPressure);
      final second = await controller.runImport(
        HealthImportCategory.bloodPressure,
      );

      expect(second, isNull, reason: 'the re-entrant call is refused');

      gate.complete(const HealthImportResult.imported(3));
      await first;

      verify(
        () => mockHealthImport.fetchHealthData(
          types: any(named: 'types'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).called(1);
    });

    // The controller must not depend on `HealthImport` keeping its
    // never-throws contract: if it ever breaks, the row would spin forever and
    // refuse taps while it did.
    test(
      'a throwing import becomes a failed result, not a stuck row',
      () async {
        final container = makeContainer();
        final controller = withPinnedClock(
          () => container.read(healthImportControllerProvider.notifier),
        );

        final failure = StateError('the layer below broke its contract');
        when(
          () => mockHealthImport.fetchHealthData(
            types: any(named: 'types'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          ),
        ).thenThrow(failure);

        final result = await controller.runImport(HealthImportCategory.sleep);

        expect(result?.status, HealthImportStatus.failed);
        expect(result?.error, same(failure));

        final categoryState = container
            .read(healthImportControllerProvider)
            .stateFor(HealthImportCategory.sleep);
        expect(
          categoryState.isRunning,
          isFalse,
          reason: 'row must not stay stuck',
        );
        expect(categoryState.lastResult?.status, HealthImportStatus.failed);
        // The row is tappable again, so the user can retry.
        expect(
          container.read(healthImportControllerProvider).isAnyRunning,
          isFalse,
        );
      },
    );

    test('refuses a run while a different category is importing', () async {
      // `HealthImport` serializes into the health store anyway, so a second
      // request would only queue behind the first while its row spun — and
      // starting one mid-`runAll` made that batch skip the category it
      // reached later.
      final container = makeContainer();
      final controller = withPinnedClock(
        () => container.read(healthImportControllerProvider.notifier),
      );

      final gate = Completer<HealthImportResult>();
      when(
        () => mockHealthImport.getActivityHealthData(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((_) => gate.future);
      stubImports(const HealthImportResult.imported(1));
      when(
        () => mockHealthImport.getActivityHealthData(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((_) => gate.future);

      final activity = controller.runImport(HealthImportCategory.activity);
      final refused = await controller.runImport(HealthImportCategory.sleep);

      expect(refused, isNull);
      verifyNever(
        () => mockHealthImport.fetchHealthData(
          types: any(named: 'types'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      );

      gate.complete(const HealthImportResult.imported(3));
      await activity;
    });

    test('records a non-success outcome verbatim', () async {
      final container = makeContainer();
      final controller = withPinnedClock(
        () => container.read(healthImportControllerProvider.notifier),
      );

      stubImports(const HealthImportResult.permissionDenied());
      await controller.runImport(HealthImportCategory.activity);

      final categoryState = container
          .read(healthImportControllerProvider)
          .stateFor(HealthImportCategory.activity);
      expect(
        categoryState.lastResult?.status,
        HealthImportStatus.permissionDenied,
      );
      expect(categoryState.isRunning, isFalse);
    });

    // Each category has to reach the right `HealthImport` entry point with the
    // right type list — a wiring mistake here would import the wrong data
    // under the right-looking row.
    final expectedTypes = <HealthImportCategory, List<HealthDataType>>{
      HealthImportCategory.sleep: sleepTypes,
      HealthImportCategory.heartRate: heartRateTypes,
      HealthImportCategory.bloodPressure: bpTypes,
      HealthImportCategory.bodyMeasurement: bodyMeasurementTypes,
    };

    for (final MapEntry(key: category, value: types) in expectedTypes.entries) {
      test('${category.name} fetches exactly its own type list', () async {
        final container = makeContainer();
        final controller = withPinnedClock(
          () => container.read(healthImportControllerProvider.notifier),
        );
        final state = container.read(healthImportControllerProvider);

        stubImports(const HealthImportResult.imported(0));
        await controller.runImport(category);

        verify(
          () => mockHealthImport.fetchHealthData(
            types: types,
            dateFrom: state.dateFrom,
            dateTo: state.dateTo,
          ),
        ).called(1);
      });
    }

    test('activity uses the aggregating activity importer', () async {
      final container = makeContainer();
      final controller = withPinnedClock(
        () => container.read(healthImportControllerProvider.notifier),
      );
      final state = container.read(healthImportControllerProvider);

      stubImports(const HealthImportResult.imported(0));
      await controller.runImport(HealthImportCategory.activity);

      verify(
        () => mockHealthImport.getActivityHealthData(
          dateFrom: state.dateFrom,
          dateTo: state.dateTo,
        ),
      ).called(1);
      verifyNever(
        () => mockHealthImport.fetchHealthData(
          types: any(named: 'types'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      );
    });

    test('workout uses the workout importer', () async {
      final container = makeContainer();
      final controller = withPinnedClock(
        () => container.read(healthImportControllerProvider.notifier),
      );
      final state = container.read(healthImportControllerProvider);

      stubImports(const HealthImportResult.imported(0));
      await controller.runImport(HealthImportCategory.workout);

      verify(
        () => mockHealthImport.getWorkoutsHealthData(
          dateFrom: state.dateFrom,
          dateTo: state.dateTo,
        ),
      ).called(1);
    });

    test('imports use the range as it stood when the run started', () async {
      final container = makeContainer();
      final controller = withPinnedClock(
        () => container.read(healthImportControllerProvider.notifier),
      );

      withPinnedClock(() => controller.selectQuickRange(30));
      final expected = container.read(healthImportControllerProvider);

      stubImports(const HealthImportResult.imported(0));
      await controller.runImport(HealthImportCategory.sleep);

      verify(
        () => mockHealthImport.fetchHealthData(
          types: sleepTypes,
          dateFrom: expected.dateFrom,
          dateTo: expected.dateTo,
        ),
      ).called(1);
    });
  });

  group('runAll', () {
    test('runs every category once, in order, and sums the counts', () async {
      final container = makeContainer();
      final controller = withPinnedClock(
        () => container.read(healthImportControllerProvider.notifier),
      );

      stubImports(const HealthImportResult.imported(2));
      final result = await controller.runAll();

      expect(result.isSuccess, isTrue);
      expect(result.sampleCount, 2 * HealthImportCategory.values.length);

      final state = container.read(healthImportControllerProvider);
      for (final category in HealthImportCategory.values) {
        expect(
          state.stateFor(category).lastResult?.sampleCount,
          2,
          reason: '${category.name} was not run',
        );
      }
      expect(state.isAnyRunning, isFalse);
    });

    test('reports the first non-success rather than a partial total', () async {
      final container = makeContainer();
      final controller = withPinnedClock(
        () => container.read(healthImportControllerProvider.notifier),
      );

      stubImports(const HealthImportResult.imported(5));
      when(
        () => mockHealthImport.getWorkoutsHealthData(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((_) async => const HealthImportResult.permissionDenied());

      final result = await controller.runAll();

      expect(result.status, HealthImportStatus.permissionDenied);
      // Every category still ran — one refusal does not abort the batch.
      final state = container.read(healthImportControllerProvider);
      expect(
        state.categories.length,
        HealthImportCategory.values.length,
      );
    });

    test('a throwing category does not abandon the ones after it', () async {
      final container = makeContainer();
      final controller = withPinnedClock(
        () => container.read(healthImportControllerProvider.notifier),
      );

      stubImports(const HealthImportResult.imported(1));
      when(
        () => mockHealthImport.getActivityHealthData(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenThrow(StateError('activity blew up'));

      final result = await controller.runAll();

      expect(result.status, HealthImportStatus.failed);
      // Activity is first in the enum; every later category still ran.
      final state = container.read(healthImportControllerProvider);
      expect(state.categories.length, HealthImportCategory.values.length);
      expect(
        state.stateFor(HealthImportCategory.workout).lastResult?.sampleCount,
        1,
      );
      expect(state.isAnyRunning, isFalse);
    });

    test('runs categories one at a time, never overlapping', () async {
      final container = makeContainer();
      final controller = withPinnedClock(
        () => container.read(healthImportControllerProvider.notifier),
      );

      // `HealthImport` serializes into the health store anyway; firing all six
      // concurrently would only spin six rows in front of the same queue.
      var inFlight = 0;
      var maxInFlight = 0;
      Future<HealthImportResult> track() async {
        inFlight++;
        maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
        await null;
        await null;
        inFlight--;
        return const HealthImportResult.imported(1);
      }

      when(
        () => mockHealthImport.fetchHealthData(
          types: any(named: 'types'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((_) => track());
      when(
        () => mockHealthImport.getActivityHealthData(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((_) => track());
      when(
        () => mockHealthImport.getWorkoutsHealthData(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((_) => track());

      await controller.runAll();

      expect(maxInFlight, 1);
    });
  });
}
