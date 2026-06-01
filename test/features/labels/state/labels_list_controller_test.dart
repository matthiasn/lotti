import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  late MockEntitiesCacheService cache;
  late MockLabelsRepository repository;
  late StreamController<Set<String>> updateController;

  setUp(() async {
    cache = MockEntitiesCacheService();
    repository = MockLabelsRepository();
    updateController = StreamController<Set<String>>.broadcast();

    final mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<EntitiesCacheService>(cache);
      },
    );

    // Drive UpdateNotifications.updateStream from a controller we control so
    // we can trigger refetches in the notification-driven providers.
    when(
      () => mocks.updateNotifications.updateStream,
    ).thenAnswer((_) => updateController.stream);
  });

  tearDown(() async {
    await updateController.close();
    await tearDownTestGetIt();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        labelsRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('labelUsageStatsProvider', () {
    test('emits the fetched usage counts on first listen', () async {
      when(
        () => getIt<JournalDb>().getLabelUsageCounts(),
      ).thenAnswer((_) async => {'a': 3, 'b': 1});

      final container = makeContainer();
      final completer = Completer<Map<String, int>>();
      final sub = container.listen(
        labelUsageStatsProvider,
        (_, next) {
          if (next.hasValue && !completer.isCompleted) {
            completer.complete(next.value);
          }
        },
        fireImmediately: true,
      );
      addTearDown(sub.close);

      final value = await completer.future;
      expect(value, {'a': 3, 'b': 1});
    });

    test('refetches when a labelUsageNotification arrives', () async {
      var call = 0;
      when(() => getIt<JournalDb>().getLabelUsageCounts()).thenAnswer((
        _,
      ) async {
        call++;
        return call == 1 ? {'a': 1} : {'a': 1, 'b': 2};
      });

      final container = makeContainer();
      final emissions = <Map<String, int>>[];
      final firstEmission = Completer<void>();
      final secondEmission = Completer<void>();
      final sub = container.listen(
        labelUsageStatsProvider,
        (_, next) {
          final value = next.value;
          if (value != null) {
            emissions.add(value);
            if (emissions.length == 1 && !firstEmission.isCompleted) {
              firstEmission.complete();
            }
            if (emissions.length == 2 && !secondEmission.isCompleted) {
              secondEmission.complete();
            }
          }
        },
        fireImmediately: true,
      );
      addTearDown(sub.close);

      // Wait for the initial fetch to land before triggering a refetch.
      await firstEmission.future;
      expect(emissions.first, {'a': 1});

      updateController.add({labelUsageNotification});
      await secondEmission.future;

      expect(emissions.last, {'a': 1, 'b': 2});
      verify(() => getIt<JournalDb>().getLabelUsageCounts()).called(2);
    });
  });

  group('labelsStreamProvider (_visibleLabels filtering)', () {
    final publicLabel = LabelTestUtils.createTestLabel(
      id: 'public',
      name: 'Public',
    );
    final privateLabel = LabelTestUtils.createTestLabel(
      id: 'private',
      name: 'Private',
      private: true,
    );

    Future<List<LabelDefinition>> firstLabels(ProviderContainer container) {
      final completer = Completer<List<LabelDefinition>>();
      final sub = container.listen(
        labelsStreamProvider,
        (_, next) {
          if (next.hasValue && !completer.isCompleted) {
            completer.complete(next.value);
          }
        },
        fireImmediately: true,
      );
      addTearDown(sub.close);
      return completer.future;
    }

    for (final showPrivate in [true, false]) {
      test(
        'showPrivate=$showPrivate yields the expected visible labels',
        () async {
          when(
            () => getIt<JournalDb>().watchConfigFlag('private'),
          ).thenAnswer((_) => Stream.value(showPrivate));
          when(
            repository.watchLabels,
          ).thenAnswer((_) => Stream.value([publicLabel, privateLabel]));

          final container = makeContainer();
          final labels = await firstLabels(container);

          if (showPrivate) {
            // Line 28: returns the full list unchanged.
            expect(labels, [publicLabel, privateLabel]);
          } else {
            // Line 30: filters out private labels.
            expect(labels, [publicLabel]);
            expect(labels.any((l) => l.private ?? false), isFalse);
          }
        },
      );
    }

    test(
      'treats null private flag as not-private when hiding private',
      () async {
        final nullPrivate = LabelTestUtils.createTestLabel(
          id: 'null-private',
        );
        when(
          () => getIt<JournalDb>().watchConfigFlag('private'),
        ).thenAnswer((_) => Stream.value(false));
        when(
          repository.watchLabels,
        ).thenAnswer((_) => Stream.value([nullPrivate, privateLabel]));

        final container = makeContainer();
        final labels = await firstLabels(container);

        expect(labels, [nullPrivate]);
      },
    );

    test(
      'defaults to hiding private when the config flag stream is empty',
      () async {
        // showPrivateEntriesProvider has no data -> orElse() => false (line 39),
        // so _visibleLabels filters out private labels.
        when(
          () => getIt<JournalDb>().watchConfigFlag('private'),
        ).thenAnswer((_) => const Stream<bool>.empty());
        when(
          repository.watchLabels,
        ).thenAnswer((_) => Stream.value([publicLabel, privateLabel]));

        final container = makeContainer();
        final labels = await firstLabels(container);

        expect(labels, [publicLabel]);
      },
    );
  });

  group('availableLabelsForCategoryProvider', () {
    test(
      'delegates filtering to EntitiesCacheService with the visible labels',
      () async {
        final global = LabelTestUtils.createTestLabel(id: 'g', name: 'Global');
        final scoped = LabelTestUtils.createTestLabel(
          id: 's',
          name: 'Scoped',
          applicableCategoryIds: ['cat-1'],
        );

        when(
          () => getIt<JournalDb>().watchConfigFlag('private'),
        ).thenAnswer((_) => Stream.value(true));
        when(
          repository.watchLabels,
        ).thenAnswer((_) => Stream.value([global, scoped]));
        when(
          () => cache.filterLabelsForCategory(any(), any()),
        ).thenReturn([scoped]);

        final container = makeContainer();

        // Ensure the underlying stream provider has produced data first.
        await firstLabelsFor(container);

        final result = container.read(
          availableLabelsForCategoryProvider('cat-1'),
        );

        expect(result, [scoped]);
        final captured = verify(
          () => cache.filterLabelsForCategory(captureAny(), captureAny()),
        ).captured;
        expect(captured.last, 'cat-1');
        expect(captured.first, [global, scoped]);
      },
    );

    test('passes an empty list while the labels stream has no data', () {
      when(
        () => cache.filterLabelsForCategory(any(), any()),
      ).thenReturn(const []);
      // No watchLabels/watchConfigFlag emission -> labelsStreamProvider is in
      // loading state, so orElse() => const <LabelDefinition>[] (line 57).
      when(
        () => getIt<JournalDb>().watchConfigFlag('private'),
      ).thenAnswer((_) => const Stream<bool>.empty());
      when(
        repository.watchLabels,
      ).thenAnswer((_) => const Stream<List<LabelDefinition>>.empty());

      final container = makeContainer();
      final result = container.read(
        availableLabelsForCategoryProvider(null),
      );

      expect(result, isEmpty);
      verify(
        () => cache.filterLabelsForCategory(const [], null),
      ).called(1);
    });
  });
}

/// Subscribes to [labelsStreamProvider] and resolves once data is available so
/// callers can be sure the dependent providers have warm state.
Future<List<LabelDefinition>> firstLabelsFor(ProviderContainer container) {
  final completer = Completer<List<LabelDefinition>>();
  final sub = container.listen(
    labelsStreamProvider,
    (_, next) {
      if (next.hasValue && !completer.isCompleted) {
        completer.complete(next.value);
      }
    },
    fireImmediately: true,
  );
  addTearDown(sub.close);
  return completer.future;
}
