import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/features/ai/backfill/inference_backfill.dart';
import 'package:lotti/features/ai/backfill/inference_backfill_detector.dart';
import 'package:lotti/features/ai/backfill/inference_backfill_providers.dart';
import 'package:lotti/features/ai/backfill/inference_backfill_queue.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

const _taskId = 'task-1';

InferenceBackfillCandidate _candidate(
  String entryId, [
  InferenceBackfillKind kind = InferenceBackfillKind.imageAnalysis,
]) => InferenceBackfillCandidate(
  entryId: entryId,
  kind: kind,
  capturedAt: testFixedDate,
);

InferenceBackfillScan _scan(List<InferenceBackfillCandidate> candidates) =>
    InferenceBackfillScan(
      candidates: candidates,
      watchedIds: {_taskId, for (final c in candidates) c.entryId},
    );

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(_candidate('fallback'));
  });

  late MockInferenceBackfillDetector detector;
  late MockSettingsDb settingsDb;
  late MockUpdateNotifications notifications;
  late MockDomainLogger logger;
  late StreamController<Set<String>> updates;
  late Map<AiConfigType, StreamController<List<AiConfig>>> configs;
  late ProviderContainer container;

  setUp(() {
    detector = MockInferenceBackfillDetector();
    settingsDb = MockSettingsDb();
    notifications = MockUpdateNotifications();
    logger = MockDomainLogger();
    updates = StreamController<Set<String>>.broadcast();
    addTearDown(updates.close);
    when(() => notifications.updateStream).thenAnswer((_) => updates.stream);
    when(
      () => settingsDb.itemByKey(inferenceBackfillDismissedKey),
    ).thenAnswer((_) async => null);
    when(
      () => settingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);

    final aiConfig = MockAiConfigRepository();
    configs = {
      for (final type in AiConfigType.values)
        type: StreamController<List<AiConfig>>.broadcast(),
    };
    for (final MapEntry(key: type, value: controller) in configs.entries) {
      addTearDown(controller.close);
      when(
        () => aiConfig.watchConfigsByType(type),
      ).thenAnswer((_) => controller.stream);
    }

    container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(aiConfig),
        inferenceBackfillDetectorProvider.overrideWithValue(detector),
        settingsDbProvider.overrideWithValue(settingsDb),
        updateNotificationsProvider.overrideWithValue(notifications),
        domainLoggerProvider.overrideWithValue(logger),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Holds the scan provider open, as the suggestion list does in the app.
  Future<InferenceBackfillScan> readScan() {
    final subscription = container.listen(
      inferenceBackfillScanProvider(_taskId),
      (_, _) {},
    );
    addTearDown(subscription.close);
    return container.read(inferenceBackfillScanProvider(_taskId).future);
  }

  group('inferenceBackfillScanProvider', () {
    test('rescans when the task or one of its media entries changes', () async {
      when(
        () => detector.scan(_taskId),
      ).thenAnswer((_) async => _scan([_candidate('img')]));
      await readScan();

      when(() => detector.scan(_taskId)).thenAnswer((_) async => _scan([]));
      updates.add({'img'});
      await pumpEventQueue();

      expect(
        container
            .read(inferenceBackfillScanProvider(_taskId))
            .value
            ?.candidates,
        isEmpty,
      );
      verify(() => detector.scan(_taskId)).called(2);
    });

    test(
      'rescans when a category changes, since its switch is the gate',
      () async {
        when(() => detector.scan(_taskId)).thenAnswer((_) async => _scan([]));
        await readScan();

        updates.add({categoriesNotification});
        await pumpEventQueue();

        verify(() => detector.scan(_taskId)).called(2);
      },
    );

    test('rescans when the AI configuration the gate reads changes, but '
        'not on the snapshot each stream replays', () async {
      when(() => detector.scan(_taskId)).thenAnswer((_) async => _scan([]));
      await readScan();

      for (final type in [
        AiConfigType.inferenceProfile,
        AiConfigType.skill,
        AiConfigType.model,
        AiConfigType.inferenceProvider,
      ]) {
        configs[type]!.add(const []);
      }
      await pumpEventQueue();
      verify(() => detector.scan(_taskId)).called(1);

      // A profile now automates image analysis.
      configs[AiConfigType.inferenceProfile]!.add(const []);
      await pumpEventQueue();
      verify(() => detector.scan(_taskId)).called(1);

      // Prompts are not part of the gate.
      configs[AiConfigType.prompt]!
        ..add(const [])
        ..add(const []);
      await pumpEventQueue();
      verifyNever(() => detector.scan(_taskId));
    });

    test(
      'a slow scan that started first never overwrites a later one',
      () async {
        when(
          () => detector.scan(_taskId),
        ).thenAnswer((_) async => _scan([_candidate('img')]));
        await readScan();

        final older = Completer<InferenceBackfillScan>();
        final newer = Completer<InferenceBackfillScan>();
        final pending = [older, newer];
        when(
          () => detector.scan(_taskId),
        ).thenAnswer((_) => pending.removeAt(0).future);

        updates.add({_taskId});
        await pumpEventQueue();
        updates.add({'img'});
        await pumpEventQueue();

        // The analysis landed: the later scan saw it, the earlier one did not.
        newer.complete(_scan([]));
        await pumpEventQueue();
        older.complete(_scan([_candidate('img')]));
        await pumpEventQueue();

        expect(
          container
              .read(inferenceBackfillScanProvider(_taskId))
              .value
              ?.candidates,
          isEmpty,
        );
      },
    );

    test('ignores changes to unrelated entries', () async {
      when(
        () => detector.scan(_taskId),
      ).thenAnswer((_) async => _scan([_candidate('img')]));
      await readScan();

      updates.add({'some-other-entry'});
      await pumpEventQueue();

      verify(() => detector.scan(_taskId)).called(1);
    });

    test('keeps the last list when a background rescan fails', () async {
      when(
        () => detector.scan(_taskId),
      ).thenAnswer((_) async => _scan([_candidate('img')]));
      await readScan();

      final failure = StateError('db closed');
      when(
        () => detector.scan(_taskId),
      ).thenAnswer((_) async => throw failure);
      updates.add({_taskId});
      await pumpEventQueue();

      expect(
        container
            .read(inferenceBackfillScanProvider(_taskId))
            .value
            ?.candidates,
        [_candidate('img')],
      );
      verify(
        () => logger.error(
          LogDomain.ai,
          failure,
          stackTrace: any(named: 'stackTrace', that: isNotNull),
          subDomain: 'inferenceBackfillScan',
        ),
      ).called(1);
    });
  });

  group('inferenceBackfillDismissalsProvider', () {
    test('loads the dismissed keys stored on this device', () async {
      when(
        () => settingsDb.itemByKey(inferenceBackfillDismissedKey),
      ).thenAnswer((_) async => jsonEncode(['imageAnalysis:a']));

      expect(
        await container.read(inferenceBackfillDismissalsProvider.future),
        {'imageAnalysis:a'},
      );
    });

    test('reads a malformed value as nothing dismissed', () async {
      when(
        () => settingsDb.itemByKey(inferenceBackfillDismissedKey),
      ).thenAnswer((_) async => 'not json');

      expect(
        await container.read(inferenceBackfillDismissalsProvider.future),
        isEmpty,
      );
    });

    test('a dismissal is kept and persisted once', () async {
      final dismissals = container.read(
        inferenceBackfillDismissalsProvider.notifier,
      );
      await dismissals.dismiss(_candidate('b'));
      await dismissals.dismiss(_candidate('a'));
      await dismissals.dismiss(_candidate('a'));

      expect(container.read(inferenceBackfillDismissalsProvider).value, {
        'imageAnalysis:a',
        'imageAnalysis:b',
      });
      verify(
        () => settingsDb.saveSettingsItem(
          inferenceBackfillDismissedKey,
          jsonEncode(['imageAnalysis:b']),
        ),
      ).called(1);
      verify(
        () => settingsDb.saveSettingsItem(
          inferenceBackfillDismissedKey,
          jsonEncode(['imageAnalysis:a', 'imageAnalysis:b']),
        ),
      ).called(1);
      // The repeated dismissal of a writes nothing.
      verifyNever(() => settingsDb.saveSettingsItem(any(), any()));
    });
  });

  group('inferenceBackfillSuggestionsProvider', () {
    Future<List<InferenceBackfillCandidate>> suggestions() async {
      final subscription = container.listen(
        inferenceBackfillSuggestionsProvider(_taskId),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(inferenceBackfillScanProvider(_taskId).future);
      await container.read(inferenceBackfillDismissalsProvider.future);
      return container.read(inferenceBackfillSuggestionsProvider(_taskId));
    }

    void setStatus(String id, AiResponseType type, InferenceStatus status) {
      final key = (id: id, aiResponseType: type);
      final keepAlive = container.listen(
        inferenceStatusControllerProvider(key),
        (_, _) {},
      );
      addTearDown(keepAlive.close);
      container
          .read(inferenceStatusControllerProvider(key).notifier)
          .setStatus(status);
    }

    test('is empty before the scan has loaded', () {
      when(
        () => detector.scan(_taskId),
      ).thenAnswer((_) => Completer<InferenceBackfillScan>().future);

      expect(
        container.read(inferenceBackfillSuggestionsProvider(_taskId)),
        isEmpty,
      );
    });

    test('lists every candidate of the scan', () async {
      final candidates = [
        _candidate('img'),
        _candidate('rec', InferenceBackfillKind.transcription),
      ];
      when(
        () => detector.scan(_taskId),
      ).thenAnswer((_) async => _scan(candidates));

      expect(await suggestions(), candidates);
    });

    test('hides dismissed suggestions', () async {
      when(() => detector.scan(_taskId)).thenAnswer(
        (_) async => _scan([_candidate('img'), _candidate('other')]),
      );
      when(
        () => settingsDb.itemByKey(inferenceBackfillDismissedKey),
      ).thenAnswer((_) async => jsonEncode(['imageAnalysis:img']));

      expect(await suggestions(), [_candidate('other')]);
    });

    test('never offers an entry whose inference is running, and offers it '
        'again when that run fails', () async {
      when(() => detector.scan(_taskId)).thenAnswer(
        (_) async => _scan([
          _candidate('img'),
          _candidate('rec', InferenceBackfillKind.audioSummary),
        ]),
      );
      setStatus('img', AiResponseType.imageAnalysis, InferenceStatus.running);
      // A transcription in flight will run the summary itself.
      setStatus(
        'rec',
        AiResponseType.audioTranscription,
        InferenceStatus.running,
      );

      expect(await suggestions(), isEmpty);

      setStatus('img', AiResponseType.imageAnalysis, InferenceStatus.error);
      expect(container.read(inferenceBackfillSuggestionsProvider(_taskId)), [
        _candidate('img'),
      ]);
    });

    test('hides a suggestion the moment it is queued', () async {
      when(
        () => detector.scan(_taskId),
      ).thenAnswer((_) async => _scan([_candidate('img'), _candidate('b')]));
      // Hold the queued job at its first check so it stays queued.
      when(
        () => detector.isStillMissing(any()),
      ).thenAnswer((_) => Completer<bool>().future);
      await suggestions();

      container
          .read(inferenceBackfillQueueProvider.notifier)
          .enqueue(taskId: _taskId, candidate: _candidate('img'));

      expect(container.read(inferenceBackfillSuggestionsProvider(_taskId)), [
        _candidate('b'),
      ]);
    });
  });
}
