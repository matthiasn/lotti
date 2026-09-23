import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/wake/wake_intent_store.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late SettingsDb settingsDb;
  late MockDomainLogger logger;

  setUp(() {
    settingsDb = SettingsDb(inMemoryDatabase: true);
    logger = MockDomainLogger();
  });

  tearDown(() async => settingsDb.close());

  WakeIntentStore newStore([SettingsDb? db]) =>
      WakeIntentStore(settingsDb: db ?? settingsDb, domainLogger: logger);

  void record(
    WakeIntentStore store, {
    String runKey = 'run-1',
    String agentId = 'agent-1',
    String? workspaceKey,
    Set<String> tokens = const {'entry-1'},
  }) => store.record(
    runKey: runKey,
    agentId: agentId,
    workspaceKey: workspaceKey,
    reason: 'subscription',
    initiator: WakeInitiator.automation,
    tokens: tokens,
  );

  Future<List<Map<String, dynamic>>> persisted() async {
    final raw = await settingsDb.itemByKey(WakeIntentStore.settingsKey);
    if (raw == null) return const [];
    return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  void verifyLogged(String messagePart) => verify(
    () => logger.error(
      LogDomain.agentRuntime,
      any(),
      message: any(named: 'message', that: contains(messagePart)),
      stackTrace: any(named: 'stackTrace'),
      subDomain: 'wake.intents',
    ),
  ).called(1);

  test('a recorded intent survives into the next process', () async {
    final store = newStore();
    await store.load();
    record(store, tokens: {'entry-1'});
    record(store, tokens: {'entry-2'});
    record(store, runKey: 'run-2', agentId: 'agent-2', workspaceKey: 'ws');
    await store.flush();

    final next = newStore();
    await next.load();
    final restored = next.takeRestorable();

    expect(restored, hasLength(2));
    final first = restored.singleWhere((i) => i.agentId == 'agent-1');
    expect(first.runKey, 'run-1');
    expect(first.tokens, {'entry-1', 'entry-2'});
    expect(first.workspaceKey, isNull);
    expect(first.reason, 'subscription');
    expect(first.initiator, WakeInitiator.automation);
    expect(first.restores, 1);
    expect(
      restored.singleWhere((i) => i.agentId == 'agent-2').workspaceKey,
      'ws',
    );
  });

  test('a settled job leaves the other jobs of its agent owed', () async {
    // Regression: settling by agent and a sequence cutoff also forgot a
    // trigger queued in a separate job of the same agent, so a crash while
    // that job ran lost it (WakeRuntime.tla, NoLostWake).
    final store = newStore();
    await store.load();
    record(store, tokens: {'early'});
    record(store, runKey: 'run-2', tokens: {'late'});

    store.settle('run-1');
    await store.flush();

    expect((await persisted()).single['tokens'], ['late']);

    store.settle('run-2');
    await store.flush();
    expect(
      await settingsDb.itemByKey(WakeIntentStore.settingsKey),
      isNull,
      reason: 'an empty store removes its key',
    );
  });

  test('settling an unknown job writes nothing', () async {
    final mockDb = MockSettingsDb();
    when(() => mockDb.itemByKey(any())).thenAnswer((_) async => null);
    final store = newStore(mockDb);
    await store.load();

    store.settle('never-recorded');
    await store.flush();

    verifyNever(() => mockDb.saveSettingsItem(any(), any()));
    verifyNever(() => mockDb.removeSettingsItem(any()));
  });

  test('only what a previous process left is restorable, once', () async {
    // Regression: intents this process had recorded since startup — jobs
    // the subscription passes had just queued — were restored as well, and
    // their tokens folded into a duplicate manual wake.
    final store = newStore();
    await store.load();
    record(store, tokens: {'owed'});
    await store.flush();

    final next = newStore();
    await next.load();
    record(next, runKey: 'run-here', tokens: {'queued-here'});
    final restored = next.takeRestorable();

    expect(restored.map((i) => i.runKey), ['run-1']);
    expect(next.takeRestorable(), isEmpty, reason: 'once per startup');
  });

  test('a second load neither drops live intents nor restores again', () async {
    // A re-run initialization calls load and restore again on the same
    // store: that must not re-queue what is already queued.
    final store = newStore();
    await store.load();
    record(store, tokens: {'owed'});
    await store.flush();

    final next = newStore();
    await next.load();
    expect(next.takeRestorable(), hasLength(1));
    record(next, runKey: 'run-here', tokens: {'queued-here'});

    await next.load();
    expect(next.takeRestorable(), isEmpty);
    await next.flush();
    expect(
      (await persisted()).map((i) => i['runKey']),
      unorderedEquals(['run-1', 'run-here']),
    );
  });

  group('while the startup read is pending', () {
    late MockSettingsDb mockDb;
    late Completer<String?> read;
    late List<String> written;

    setUp(() {
      mockDb = MockSettingsDb();
      read = Completer<String?>();
      written = [];
      when(() => mockDb.itemByKey(any())).thenAnswer((_) => read.future);
      when(() => mockDb.saveSettingsItem(any(), any())).thenAnswer((
        call,
      ) async {
        written.add(call.positionalArguments[1] as String);
        return 1;
      });
    });

    String persistedIntent(String runKey) => jsonEncode([
      {
        'runKey': runKey,
        'agentId': 'agent-1',
        'workspaceKey': null,
        'reason': 'creation',
        'initiator': 'user',
        'tokens': ['from-disk'],
      },
    ]);

    test('a write waits and keeps what is on disk', () async {
      // Regression: a snapshot taken before the read finished replaced the
      // persisted intents with this process's alone.
      final store = newStore(mockDb);
      record(store, runKey: 'run-new', tokens: {'new'});
      final flushed = store.flush();
      await pumpEventQueue();
      expect(written, isEmpty, reason: 'no write before the read');

      read.complete(persistedIntent('run-old'));
      await flushed;

      final saved = (jsonDecode(written.last) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(
        saved.map((i) => i['runKey']),
        unorderedEquals(['run-old', 'run-new']),
      );
      expect(store.takeRestorable().map((i) => i.runKey), ['run-old']);
    });

    test(
      'a job recorded meanwhile under a persisted run key merges with it',
      () async {
        // Deterministic run keys (restorePendingWake) can recur across
        // processes: the job is live here, so its intent is not restorable,
        // but it keeps the persisted tokens and restore count.
        final store = newStore(mockDb);
        record(store, runKey: 'run-old', tokens: {'new'});
        final flushed = store.flush();

        read.complete(
          jsonEncode([
            {
              'runKey': 'run-old',
              'agentId': 'agent-1',
              'workspaceKey': null,
              'reason': 'creation',
              'initiator': 'user',
              'tokens': ['from-disk'],
              'restores': 1,
            },
          ]),
        );
        await flushed;

        final saved =
            (jsonDecode(written.last) as List<dynamic>).single
                as Map<String, dynamic>;
        expect(saved['tokens'], ['from-disk', 'new']);
        expect(saved['restores'], 1);
        expect(store.takeRestorable(), isEmpty);
      },
    );

    test('a job settled meanwhile is not brought back from disk', () async {
      final store = newStore(mockDb);
      final loading = store.load();
      store.settle('run-old');

      read.complete(persistedIntent('run-old'));
      await loading;

      expect(store.takeRestorable(), isEmpty);
    });
  });

  test('an adopted intent hands its restore count to its new job', () async {
    final store = newStore();
    await store.load();
    record(store);
    await store.flush();

    final next = newStore();
    await next.load();
    final restored = next.takeRestorable().single;
    record(next, runKey: 'run-new');
    next.adopt(restored, runKey: 'run-new');
    await next.flush();

    final intents = await persisted();
    expect(intents.single['runKey'], 'run-new');
    expect(intents.single['restores'], 1);
  });

  test('adopting into the same job keeps it', () async {
    final store = newStore();
    await store.load();
    record(store);
    await store.flush();

    final next = newStore();
    await next.load();
    next.adopt(next.takeRestorable().single, runKey: 'run-1');
    await next.flush();

    expect((await persisted()).single['runKey'], 'run-1');
  });

  test(
    'an intent restored maxRestores times without settling is dropped',
    () async {
      final store = newStore();
      await store.load();
      record(store);
      await store.flush();

      for (var boot = 1; boot <= WakeIntentStore.maxRestores; boot++) {
        final booted = newStore();
        await booted.load();
        expect(booted.takeRestorable().single.restores, boot);
        await booted.flush();
      }

      final last = newStore();
      await last.load();
      expect(last.takeRestorable(), isEmpty);
      await last.flush();
      expect(await persisted(), isEmpty);
      verifyLogged('dropped after ${WakeIntentStore.maxRestores} restores');
    },
  );

  test(
    'unreadable entries are skipped and logged, readable ones kept',
    () async {
      await settingsDb.saveSettingsItem(
        WakeIntentStore.settingsKey,
        jsonEncode([
          {'agentId': 'agent-1'},
          {
            'runKey': 'run-2',
            'agentId': 'agent-2',
            'workspaceKey': null,
            'reason': 'manual',
            'initiator': 'user',
            'tokens': ['t'],
          },
        ]),
      );
      final store = newStore();
      await store.load();

      final restored = store.takeRestorable();

      expect(restored.single.agentId, 'agent-2');
      expect(restored.single.initiator, WakeInitiator.user);
      verifyLogged('unreadable wake intent skipped');
    },
  );

  test('an unreadable blob loads as empty and is logged', () async {
    await settingsDb.saveSettingsItem(WakeIntentStore.settingsKey, '{oops');
    final store = newStore();
    await store.load();

    expect(store.takeRestorable(), isEmpty);
    verifyLogged('unreadable wake intents skipped');
  });

  group('writes', () {
    late MockSettingsDb mockDb;

    setUp(() {
      mockDb = MockSettingsDb();
      when(() => mockDb.itemByKey(any())).thenAnswer((_) async => null);
    });

    test('a burst of triggers is coalesced into at most two writes', () async {
      when(
        () => mockDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);
      final store = newStore(mockDb);
      await store.load();

      for (var i = 0; i < 10; i++) {
        record(store, tokens: {'entry-$i'});
      }
      await store.flush();

      final written = verify(
        () => mockDb.saveSettingsItem(
          WakeIntentStore.settingsKey,
          captureAny(),
        ),
      ).captured;
      expect(written.length, lessThanOrEqualTo(2));
      final last = jsonDecode(written.last as String) as List<dynamic>;
      expect(
        ((last.single as Map<String, dynamic>)['tokens'] as List).length,
        10,
      );
    });

    test('a failed write is logged, not thrown', () async {
      when(
        () => mockDb.saveSettingsItem(any(), any()),
      ).thenThrow(StateError('disk full'));
      final store = newStore(mockDb);
      await store.load();

      record(store);
      await store.flush();

      verifyLogged('failed to persist wake intents');
    });
  });
}
