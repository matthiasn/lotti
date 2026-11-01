import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/directed_relation.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/ai/link_suggestions/prior_work_mention.dart';
import 'package:lotti/features/ai/link_suggestions/task_link_suggestion.dart';
import 'package:lotti/features/ai/link_suggestions/task_link_suggestion_providers.dart';
import 'package:lotti/features/ai/repository/vector_search_repository.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'link_suggestion_fixtures.dart';

const _taskId = 'current';

TaskLinkSuggestion _suggestion(String targetId, {double distance = 0.3}) =>
    TaskLinkSuggestion(
      sourceTaskId: _taskId,
      targetTaskId: targetId,
      targetTitle: 'Task $targetId',
      relation: const DirectedRelation(EntryLinkType.basic),
      distance: distance,
      mention: const PriorWorkMention(
        sourceId: 'e1',
        sentence: 'Like last time.',
        relation: DirectedRelation(EntryLinkType.basic),
        query: null,
      ),
      mentionedAt: DateTime(2024, 3, 15),
    );

TaskLinkSuggestionScan _scan(List<TaskLinkSuggestion> suggestions) =>
    TaskLinkSuggestionScan(
      suggestions: suggestions,
      watchedIds: {_taskId, 'e1', for (final s in suggestions) s.targetTaskId},
    );

void main() {
  setUpAll(() => registerFallbackValue(TaskLinkSuggestionScan.empty));

  late MockTaskLinkSuggestionDetector detector;
  late MockSettingsDb settingsDb;
  late MockUpdateNotifications notifications;
  late MockDomainLogger logger;
  late StreamController<Set<String>> updates;
  late ProviderContainer container;

  setUp(() {
    detector = MockTaskLinkSuggestionDetector();
    settingsDb = MockSettingsDb();
    notifications = MockUpdateNotifications();
    logger = MockDomainLogger();
    updates = StreamController<Set<String>>.broadcast();
    addTearDown(updates.close);
    when(() => notifications.updateStream).thenAnswer((_) => updates.stream);
    when(
      () => settingsDb.itemByKey(taskLinkSuggestionsDismissedKey),
    ).thenAnswer((_) async => null);
    when(
      () => settingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);

    container = ProviderContainer(
      overrides: [
        taskLinkSuggestionDetectorProvider.overrideWithValue(detector),
        settingsDbProvider.overrideWithValue(settingsDb),
        updateNotificationsProvider.overrideWithValue(notifications),
        domainLoggerProvider.overrideWithValue(logger),
      ],
    );
    addTearDown(container.dispose);
  });

  void stubScan(
    TaskLinkSuggestionScan Function(TaskLinkSuggestionScan? previous) answer,
  ) =>
      when(
        () => detector.scan(_taskId, previous: any(named: 'previous')),
      ).thenAnswer(
        (invocation) async => answer(
          invocation.namedArguments[#previous] as TaskLinkSuggestionScan?,
        ),
      );

  /// Holds the scan provider open, as the suggestion list does in the app.
  Future<TaskLinkSuggestionScan> readScan() {
    final subscription = container.listen(
      taskLinkSuggestionScanProvider(_taskId),
      (_, _) {},
    );
    addTearDown(subscription.close);
    return container.read(taskLinkSuggestionScanProvider(_taskId).future);
  }

  List<TaskLinkSuggestion>? published() => container
      .read(taskLinkSuggestionScanProvider(_taskId))
      .value
      ?.suggestions;

  group('taskLinkSuggestionScanProvider', () {
    test('rescans on a change to a watched id, handing over the last scan '
        'so its searches are reused', () async {
      final first = _scan([_suggestion('census')]);
      stubScan((_) => first);
      await readScan();

      TaskLinkSuggestionScan? handedOver;
      stubScan((previous) {
        handedOver = previous;
        return _scan([]);
      });
      updates.add({'census'});
      await pumpEventQueue();

      expect(handedOver, same(first));
      expect(published(), isEmpty);
    });

    test('ignores changes to ids it does not watch', () async {
      stubScan((_) => _scan([_suggestion('census')]));
      await readScan();

      updates.add({'unrelated'});
      await pumpEventQueue();

      verify(
        () => detector.scan(_taskId, previous: any(named: 'previous')),
      ).called(1);
    });

    test('a slow rescan never overwrites a later one', () async {
      stubScan((_) => _scan([]));
      await readScan();

      final slow = Completer<TaskLinkSuggestionScan>();
      when(
        () => detector.scan(_taskId, previous: any(named: 'previous')),
      ).thenAnswer((_) => slow.future);
      updates.add({_taskId});
      await pumpEventQueue();

      stubScan((_) => _scan([_suggestion('newer')]));
      updates.add({'e1'});
      await pumpEventQueue();
      slow.complete(_scan([_suggestion('older')]));
      await pumpEventQueue();

      expect(published()?.map((s) => s.targetTaskId), ['newer']);
    });

    test('a failed rescan keeps the last list and is logged', () async {
      stubScan((_) => _scan([_suggestion('census')]));
      await readScan();

      when(
        () => detector.scan(_taskId, previous: any(named: 'previous')),
      ).thenThrow(StateError('db closed'));
      updates.add({_taskId});
      await pumpEventQueue();

      expect(published()?.map((s) => s.targetTaskId), ['census']);
      verify(
        () => logger.error(
          LogDomain.ai,
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'taskLinkSuggestionScan',
        ),
      ).called(1);
    });
  });

  group('taskLinkSuggestionsProvider', () {
    Future<List<TaskLinkSuggestion>> readSuggestions() async {
      final subscription = container.listen(
        taskLinkSuggestionsProvider(_taskId),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await readScan();
      await container.read(taskLinkSuggestionDismissalsProvider.future);
      return container.read(taskLinkSuggestionsProvider(_taskId));
    }

    test('is empty until the dismissals have loaded', () async {
      stubScan((_) => _scan([_suggestion('census')]));
      final stored = Completer<String?>();
      when(
        () => settingsDb.itemByKey(taskLinkSuggestionsDismissedKey),
      ).thenAnswer((_) => stored.future);
      container.listen(taskLinkSuggestionsProvider(_taskId), (_, _) {});
      await readScan();

      expect(container.read(taskLinkSuggestionsProvider(_taskId)), isEmpty);

      stored.complete(null);
      await pumpEventQueue();

      expect(
        container
            .read(taskLinkSuggestionsProvider(_taskId))
            .map((s) => s.targetTaskId),
        ['census'],
      );
    });

    test('a dismissal hides its pair and is stored on this device', () async {
      final census = _suggestion('census');
      stubScan((_) => _scan([census, _suggestion('relay')]));
      await readSuggestions();

      await container
          .read(taskLinkSuggestionDismissalsProvider.notifier)
          .dismiss(census);

      expect(
        container
            .read(taskLinkSuggestionsProvider(_taskId))
            .map((s) => s.targetTaskId),
        ['relay'],
      );
      verify(
        () => settingsDb.saveSettingsItem(
          taskLinkSuggestionsDismissedKey,
          jsonEncode(['current|census']),
        ),
      ).called(1);
    });

    test('a pair dismissed earlier never shows', () async {
      when(
        () => settingsDb.itemByKey(taskLinkSuggestionsDismissedKey),
      ).thenAnswer((_) async => jsonEncode(['current|census']));
      stubScan((_) => _scan([_suggestion('census'), _suggestion('relay')]));

      final suggestions = await readSuggestions();

      expect(suggestions.map((s) => s.targetTaskId), ['relay']);
    });

    test('an accepted suggestion is hidden at once, without a write', () async {
      final census = _suggestion('census');
      stubScan((_) => _scan([census]));
      await readSuggestions();

      container.read(taskLinkSuggestionAcceptedProvider.notifier)
        ..accept(census)
        ..accept(census);

      expect(container.read(taskLinkSuggestionsProvider(_taskId)), isEmpty);
      expect(container.read(taskLinkSuggestionAcceptedProvider), {
        'current|census',
      });
      verifyNever(() => settingsDb.saveSettingsItem(any(), any()));
    });
  });

  test('the detector searches the registered vector search', () async {
    final db = MockJournalDb();
    final search = MockVectorSearchRepository();
    when(
      () => db.journalEntityById(_taskId),
    ).thenAnswer((_) async => linkTask(_taskId, 'Recount'));
    when(() => db.getConfigFlag(enableEmbeddingsFlag)).thenAnswer(
      (_) async => true,
    );
    when(() => db.getLinkedEntities(_taskId)).thenAnswer(
      (_) async => [logEntry('e1', 'Follow-up to the census export.')],
    );
    when(
      () => search.searchRelatedTasks(
        query: any(named: 'query'),
        k: any(named: 'k'),
      ),
    ).thenAnswer(
      (_) async => VectorSearchResult(entities: [], elapsed: Duration.zero),
    );
    when(
      () => db.linksForEntryIdsBidirectional({_taskId}),
    ).thenAnswer((_) async => []);
    when(
      () => db.getJournalEntitiesForIdsUnordered(any()),
    ).thenAnswer((_) async => []);
    final wired = ProviderContainer(
      overrides: [
        journalDbProvider.overrideWithValue(db),
        vectorSearchRepositoryProvider.overrideWithValue(search),
        domainLoggerProvider.overrideWithValue(MockDomainLogger()),
      ],
    );
    addTearDown(wired.dispose);

    await wired.read(taskLinkSuggestionDetectorProvider).scan(_taskId);

    verify(
      () => search.searchRelatedTasks(
        query: 'the census export',
        k: any(named: 'k'),
      ),
    ).called(1);
  });
}
