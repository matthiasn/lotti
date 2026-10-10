import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/repository/ai_config_sync_ledger.dart';
import 'package:lotti/features/ai/repository/ai_config_sync_sender.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  late MockOutboxService outbox;
  late SettingsDb settingsDb;
  late Map<String, AiConfigResend?> held;
  late List<String> errors;
  final created = DateTime(2024, 3, 15, 12);

  final prompt = AiConfig.inferenceProvider(
    id: 'provider-1',
    baseUrl: 'https://api.example.com',
    apiKey: 'key',
    name: 'Provider',
    createdAt: created,
    inferenceProviderType: InferenceProviderType.genericOpenAi,
  );

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    outbox = MockOutboxService();
    settingsDb = SettingsDb(inMemoryDatabase: true);
    held = {};
    errors = [];
    when(() => outbox.enqueueMessageOrThrow(any())).thenAnswer((_) async {});
  });

  tearDown(() => settingsDb.close());

  AiConfigSyncSender sender({SettingsDb? settings}) => AiConfigSyncSender(
    settingsDb: settings,
    enqueue: outbox.enqueueMessageOrThrow,
    resendOf: (id) async => held[id],
    onError: (error, _, subDomain) => errors.add('$subDomain: $error'),
    retryDelay: const Duration(seconds: 30),
  );

  Future<Set<String>> owed() => AiConfigSyncLedger(settingsDb).load();

  SyncMessage edit(String id) => SyncMessage.aiConfigDelete(id: id);

  group('AiConfigResend', () {
    test('a stored row travels as an update with its stamp', () {
      final message = AiConfigResend(
        id: prompt.id,
        config: prompt,
        stamp: 7,
      ).toSyncMessage();

      expect(
        message,
        SyncMessage.aiConfig(
          aiConfig: prompt,
          status: SyncEntryStatus.update,
          versionStamp: 7,
        ),
      );
    });

    test('a stamp with no row travels as a hard deletion', () {
      expect(
        const AiConfigResend(id: 'gone', stamp: 9).toSyncMessage(),
        const SyncMessage.aiConfigDelete(
          id: 'gone',
          hardDelete: true,
          versionStamp: 9,
        ),
      );
    });
  });

  test('a send the outbox accepts leaves nothing owed', () async {
    await sender(settings: settingsDb).send('provider-1', edit('provider-1'));

    verify(() => outbox.enqueueMessageOrThrow(edit('provider-1'))).called(1);
    expect(await owed(), isEmpty);
  });

  test('a failed send stays owed and the retry sends what is held then', () {
    fakeAsync((async) {
      when(
        () => outbox.enqueueMessageOrThrow(any()),
      ).thenThrow(StateError('outbox down'));
      final subject = sender(settings: settingsDb)
        ..send('provider-1', edit('provider-1'));
      async.flushMicrotasks();

      Set<String>? pending;
      owed().then((ids) => pending = ids);
      async.flushMicrotasks();
      expect(pending, {'provider-1'});

      when(() => outbox.enqueueMessageOrThrow(any())).thenAnswer((_) async {});
      held['provider-1'] = AiConfigResend(
        id: 'provider-1',
        config: prompt,
        stamp: 3,
      );
      async
        ..elapse(const Duration(seconds: 30))
        ..flushMicrotasks();

      verify(
        () => outbox.enqueueMessageOrThrow(
          held['provider-1']!.toSyncMessage(),
        ),
      ).called(1);
      owed().then((ids) => pending = ids);
      async.flushMicrotasks();
      expect(pending, isEmpty);
      subject.dispose();
    });
  });

  test('failed sends started together all stay owed', () async {
    when(
      () => outbox.enqueueMessageOrThrow(any()),
    ).thenThrow(StateError('outbox down'));
    final subject = sender(settings: settingsDb);

    await Future.wait([
      subject.send('a', edit('a')),
      subject.send('b', edit('b')),
      subject.send('c', edit('c')),
    ]);

    expect(await owed(), {'a', 'b', 'c'});
    subject.dispose();
  });

  test('a flush overlapping a newer write of the same id does not settle '
      'that write when its enqueue fails', () async {
    await AiConfigSyncLedger(settingsDb).owe('a');
    held['a'] = const AiConfigResend(id: 'a', stamp: 1);
    const newer = SyncMessage.aiConfigDelete(id: 'a', versionStamp: 2);
    when(() => outbox.enqueueMessageOrThrow(any())).thenAnswer((invocation) {
      if (invocation.positionalArguments.single == newer) {
        throw StateError('outbox down');
      }
      return Future<void>.value();
    });
    final subject = sender(settings: settingsDb);

    await Future.wait([subject.flush(), subject.send('a', newer)]);

    expect(await owed(), {'a'});
    subject.dispose();
  });

  test('a flush forgets an id the device holds nothing for', () async {
    final ledger = AiConfigSyncLedger(settingsDb);
    await ledger.owe('pruned');

    await sender(settings: settingsDb).flush();

    verifyNever(() => outbox.enqueueMessageOrThrow(any()));
    expect(await owed(), isEmpty);
  });

  test('a failed flush keeps the rest owed until the retry', () {
    fakeAsync((async) {
      final ledger = AiConfigSyncLedger(settingsDb);
      ledger.owe('a').then((_) => ledger.owe('b'));
      async.flushMicrotasks();
      held['a'] = const AiConfigResend(id: 'a', stamp: 1);
      held['b'] = const AiConfigResend(id: 'b', stamp: 2);
      when(
        () => outbox.enqueueMessageOrThrow(any()),
      ).thenThrow(StateError('outbox down'));
      final subject = sender(settings: settingsDb)..flush();
      async.flushMicrotasks();

      Set<String>? pending;
      owed().then((ids) => pending = ids);
      async.flushMicrotasks();
      expect(pending, {'a', 'b'});

      when(() => outbox.enqueueMessageOrThrow(any())).thenAnswer((_) async {});
      async
        ..elapse(const Duration(seconds: 30))
        ..flushMicrotasks();
      owed().then((ids) => pending = ids);
      async.flushMicrotasks();
      expect(pending, isEmpty);
      subject.dispose();
    });
  });

  test('after dispose a failure arms no retry', () {
    fakeAsync((async) {
      when(
        () => outbox.enqueueMessageOrThrow(any()),
      ).thenThrow(StateError('outbox down'));
      sender(settings: settingsDb)
        ..dispose()
        ..send('provider-1', edit('provider-1'));
      async
        ..flushMicrotasks()
        ..elapse(const Duration(minutes: 5));

      verify(() => outbox.enqueueMessageOrThrow(any())).called(1);
    });
  });

  test('without settings storage a failure is only logged', () async {
    when(
      () => outbox.enqueueMessageOrThrow(any()),
    ).thenThrow(StateError('outbox down'));
    final subject = sender();

    await subject.send('provider-1', edit('provider-1'));
    await subject.flush();

    verify(() => outbox.enqueueMessageOrThrow(any())).called(1);
    expect(errors, ['aiConfig.send: Bad state: outbox down']);
    expect(await owed(), isEmpty);
  });
}
