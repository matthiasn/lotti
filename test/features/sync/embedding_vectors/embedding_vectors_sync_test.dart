import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/ai/database/embedding_register.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/embedding_sync/embedding_vectors_payload.dart';
import 'package:lotti/features/ai/embedding_sync/synced_embedding_sink.dart';
import 'package:lotti/features/sync/embedding_vectors/embedding_vectors_sync.dart';
import 'package:lotti/features/sync/queue/inbound_queue_models.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/fallbacks.dart';
import '../../../helpers/in_memory_embedding_store.dart';
import '../../../mocks/mocks.dart';

const _model = 'embeddinggemma-300m-q4';

Float32List _vector(double value) =>
    Float32List(kEmbeddingDimensions)
      ..fillRange(0, kEmbeddingDimensions, value);

EmbeddingRegister _register(
  String entityId, {
  VectorClock? vc,
  String host = 'host-a',
  bool deleted = false,
  String model = _model,
  String taskId = '',
}) => EmbeddingRegister(
  entityId: entityId,
  modelId: model,
  entityType: 'journal_text',
  contentHash: deleted ? '' : 'hash-$entityId',
  vectorClock: vc,
  deleted: deleted,
  taskId: taskId,
  originatingHostId: vc == null ? '' : host,
);

void main() {
  late Directory docs;
  late MockVectorClockService vcService;
  late MockOutboxService outbox;
  late MockDomainLogger logger;
  late InMemoryEmbeddingStore store;
  late Map<String, bool> flags;
  late Map<String, String> settings;
  late List<SyncMessage> enqueued;
  late MockVcReservation reservation;
  late EmbeddingVectorsSync vectors;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('embedding_vectors_sync_');
    vcService = MockVectorClockService();
    outbox = MockOutboxService();
    logger = MockDomainLogger();
    store = InMemoryEmbeddingStore();
    flags = {enableEmbeddingsFlag: true, syncEmbeddingsFlag: true};
    settings = {};
    enqueued = [];
    reservation = MockVcReservation();
    when(() => reservation.vc).thenReturn(
      const VectorClock({'host-a': 5}),
    );
    when(reservation.commit).thenAnswer((_) async {});
    when(reservation.release).thenAnswer((_) async {});
    when(vcService.getHost).thenAnswer((_) async => 'host-a');
    when(
      () => vcService.reserveNextVectorClock(
        previous: any(named: 'previous'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async => reservation);
    when(() => outbox.enqueueMessageOrThrow(any())).thenAnswer((i) async {
      enqueued.add(i.positionalArguments.first as SyncMessage);
    });
    vectors = EmbeddingVectorsSync(
      vectorClockService: vcService,
      outboxService: outbox,
      readFlag: (flag) async => flags[flag] ?? false,
      documentsPath: docs.path,
      domainLogger: logger,
      expectsPipeline: true,
      readSetting: (key) async => settings[key],
      writeSetting: (key, value) async => settings[key] = value,
    );
  });

  tearDown(() async {
    await vectors.dispose();
    await docs.delete(recursive: true);
  });

  Future<void> attach({SyncedEmbeddingSink? sink}) => vectors.attach(
    store: store,
    modelId: _model,
    sink: sink ?? MockSyncedEmbeddingSink(),
  );

  File fileOf(SyncEmbeddingVectors message) => File(
    p.joinAll([
      docs.path,
      ...message.jsonPath!.split('/').where((s) => s.isNotEmpty),
    ]),
  );

  group('reserve', () {
    test('grants nothing before the pipeline attaches', () async {
      expect(await vectors.reserve(registerId: 'e1|$_model'), isNull);
      verifyNever(
        () => vcService.reserveNextVectorClock(
          previous: any(named: 'previous'),
          payload: any(named: 'payload'),
        ),
      );
    });

    test('grants nothing while either flag is off', () async {
      await attach();
      for (final flag in [enableEmbeddingsFlag, syncEmbeddingsFlag]) {
        flags
          ..[enableEmbeddingsFlag] = true
          ..[syncEmbeddingsFlag] = true
          ..[flag] = false;
        expect(await vectors.reserve(registerId: 'e1|$_model'), isNull);
      }
    });

    test('grants nothing without a host', () async {
      await attach();
      when(vcService.getHost).thenAnswer((_) async => null);

      expect(await vectors.reserve(registerId: 'e1|$_model'), isNull);
    });

    test(
      'reserves the next clock after the previous one, naming its payload',
      () async {
        await attach();

        final ticket = await vectors.reserve(
          registerId: 'e1|$_model',
          previous: const VectorClock({'host-a': 2}),
        );

        expect(ticket!.vectorClock, const VectorClock({'host-a': 5}));
        expect(ticket.hostId, 'host-a');
        verify(
          () => vcService.reserveNextVectorClock(
            previous: const VectorClock({'host-a': 2}),
            payload: (
              id: 'e1|$_model',
              type: SyncSequencePayloadType.embeddingVectors,
            ),
          ),
        ).called(1);
      },
    );
  });

  group('sending a version', () {
    test(
      'writes the attachment at a path of its own, enqueues the message and '
      'commits the reservation',
      () async {
        await attach();
        final ticket = await vectors.reserve(registerId: 'e1|$_model');
        final version = _register('e1', vc: ticket!.vectorClock);

        await ticket.send(version, [_vector(0.25), _vector(0.5)]);

        final message = enqueued.single as SyncEmbeddingVectors;
        expect(message.id, 'e1|$_model');
        expect(message.vectorClock, const VectorClock({'host-a': 5}));
        expect(message.jsonPath, '/embedding_vectors/e1/$_model/host-a-5.json');
        final chunks = decodeEmbeddingVectors(
          fileOf(message).readAsBytesSync(),
        );
        expect(chunks.map((c) => c.first), [0.25, 0.5]);
        verify(reservation.commit).called(1);
        verifyNever(reservation.release);
      },
    );

    test("a newer version's file replaces the older one's", () async {
      await attach();
      final ticket = await vectors.reserve(registerId: 'e1|$_model');
      await ticket!.send(
        _register('e1', vc: const VectorClock({'host-a': 4})),
        [_vector(0.1)],
      );
      await ticket.send(
        _register('e1', vc: const VectorClock({'host-a': 5})),
        [_vector(0.2)],
      );

      final directory = Directory(
        p.join(docs.path, 'embedding_vectors', 'e1', _model),
      );
      expect(
        directory.listSync().map((f) => p.basename(f.path)),
        ['host-a-5.json'],
      );
    });

    test('a tombstone travels without an attachment', () async {
      await attach();
      final ticket = await vectors.reserve(registerId: 'e1|$_model');

      await ticket!.send(
        _register('e1', vc: ticket.vectorClock, deleted: true),
        const [],
      );

      final message = enqueued.single as SyncEmbeddingVectors;
      expect(message.deleted, isTrue);
      expect(message.jsonPath, isNull);
    });

    test(
      'a version the outbox refuses releases its reservation, never throws',
      () async {
        await attach();
        when(
          () => outbox.enqueueMessageOrThrow(any()),
        ).thenThrow(StateError('full'));
        final ticket = await vectors.reserve(registerId: 'e1|$_model');

        await ticket!.send(_register('e1', vc: ticket.vectorClock), [
          _vector(1),
        ]);

        verify(reservation.release).called(1);
        verifyNever(reservation.commit);
      },
    );

    test('a ticket released by its caller releases the reservation', () async {
      await attach();
      final ticket = await vectors.reserve(registerId: 'e1|$_model');

      await ticket!.release();

      verify(reservation.release).called(1);
    });
  });

  group('answering from the store', () {
    test(
      'heldVersion is the shared register of this model, tombstones included',
      () async {
        await attach();
        store
          ..registers['live'] = _register(
            'live',
            vc: const VectorClock({'b': 1}),
          )
          ..registers['gone'] = _register(
            'gone',
            vc: const VectorClock({'b': 2}),
            deleted: true,
          )
          ..registers['local'] = _register('local');

        expect((await vectors.heldVersion('live|$_model'))!.entityId, 'live');
        expect((await vectors.heldVersion('gone|$_model'))!.deleted, isTrue);
        expect(await vectors.heldVersion('local|$_model'), isNull);
        expect(await vectors.heldVersion('live|other-model'), isNull);
        expect(await vectors.heldVersion('malformed'), isNull);
        expect(await vectors.heldVersion('live|'), isNull);
      },
    );

    test('resends the held version with its stored chunks', () async {
      await attach();
      store.replaceEntityEmbeddings(
        entityId: 'e1',
        entityType: 'journal_text',
        modelId: _model,
        contentHash: 'h',
        embeddings: [_vector(0.75)],
        register: _register(
          'e1',
          vc: const VectorClock({'host-b': 3}),
          host: 'host-b',
        ),
      );

      expect(await vectors.resend('e1|$_model'), isTrue);

      final message = enqueued.single as SyncEmbeddingVectors;
      expect(message.originatingHostId, 'host-b');
      expect(message.jsonPath, '/embedding_vectors/e1/$_model/host-b-3.json');
      expect(
        decodeEmbeddingVectors(fileOf(message).readAsBytesSync()).single.first,
        0.75,
      );
    });

    test(
      'resends nothing for a register it does not hold, or one without chunks',
      () async {
        await attach();
        store.registers['bare'] = _register(
          'bare',
          vc: const VectorClock({'b': 1}),
        );

        expect(await vectors.resend('absent|$_model'), isFalse);
        expect(await vectors.resend('bare|$_model'), isFalse);
        expect(enqueued, isEmpty);
      },
    );

    test(
      'sharedRegisters lists shared versions of this model in id order',
      () async {
        await attach();
        store
          ..registers['b'] = _register('b', vc: const VectorClock({'x': 1}))
          ..registers['a'] = _register('a', vc: const VectorClock({'x': 2}))
          ..registers['local'] = _register('local')
          ..registers['old'] = _register(
            'old',
            vc: const VectorClock({'x': 3}),
            model: 'old',
          );

        expect((await vectors.sharedRegisters()).map((r) => r.entityId), [
          'a',
          'b',
        ]);
      },
    );

    test('lists nothing before the pipeline attaches', () async {
      expect(await vectors.sharedRegisters(), isEmpty);
      expect(await vectors.registerIdsToSend(), isEmpty);
      await vectors.sendCurrent('e1|$_model');
      expect(enqueued, isEmpty);
    });
  });

  group('Add Device', () {
    test(
      'sends every live version and every shared tombstone, never a local '
      'tombstone',
      () async {
        await attach();
        store
          ..registers['shared'] = _register(
            'shared',
            vc: const VectorClock({'x': 1}),
          )
          ..registers['local'] = _register('local')
          ..registers['shared-gone'] = _register(
            'shared-gone',
            vc: const VectorClock({'x': 2}),
            deleted: true,
          )
          ..registers['local-gone'] = _register('local-gone', deleted: true);

        expect(await vectors.registerIdsToSend(), [
          'local|$_model',
          'shared-gone|$_model',
          'shared|$_model',
        ]);
      },
    );

    test(
      'a version stored while sharing was off is versioned, then sent',
      () async {
        await attach();
        store.replaceEntityEmbeddings(
          entityId: 'e1',
          entityType: 'journal_text',
          modelId: _model,
          contentHash: 'h',
          embeddings: [_vector(0.5)],
          register: _register('e1'),
        );

        await vectors.sendCurrent('e1|$_model');

        expect(
          store.registers['e1']!.vectorClock,
          const VectorClock({'host-a': 5}),
        );
        expect(store.registers['e1']!.originatingHostId, 'host-a');
        final message = enqueued.single as SyncEmbeddingVectors;
        expect(message.vectorClock, const VectorClock({'host-a': 5}));
        verify(reservation.commit).called(1);
      },
    );

    test(
      'a shared version is resent as it is, and a refused one throws',
      () async {
        await attach();
        store.replaceEntityEmbeddings(
          entityId: 'e1',
          entityType: 'journal_text',
          modelId: _model,
          contentHash: 'h',
          embeddings: [_vector(0.5)],
          register: _register('e1', vc: const VectorClock({'x': 9}), host: 'x'),
        );

        await vectors.sendCurrent('e1|$_model');
        expect(
          (enqueued.single as SyncEmbeddingVectors).vectorClock,
          const VectorClock({'x': 9}),
        );

        when(
          () => outbox.enqueueMessageOrThrow(any()),
        ).thenThrow(StateError('full'));
        await expectLater(vectors.sendCurrent('e1|$_model'), throwsStateError);
      },
    );

    test(
      'nothing is sent for a version stored unshared while sharing is off',
      () async {
        await attach();
        flags[syncEmbeddingsFlag] = false;
        store.registers['e1'] = _register('e1');

        await vectors.sendCurrent('e1|$_model');

        expect(store.registers['e1']!.isShared, isFalse);
        expect(enqueued, isEmpty);
      },
    );
  });

  group('waiting for the pipeline', () {
    test(
      'a version waits only while the pipeline is due but not attached',
      () async {
        expect(await vectors.awaitsPipeline, isTrue);
        flags[syncEmbeddingsFlag] = false;
        expect(await vectors.awaitsPipeline, isFalse);
        flags[syncEmbeddingsFlag] = true;
        await attach();
        expect(await vectors.awaitsPipeline, isFalse);
        await vectors.detach();
        expect(vectors.isAttached, isFalse);
        expect(vectors.sink, isNull);
      },
    );
  });

  group('catch-up', () {
    test('runs once per model, when it can first store', () async {
      var rounds = 0;
      vectors.catchUpRound = () async => rounds++;
      flags[syncEmbeddingsFlag] = false;
      final flagChanges = StreamController<void>();
      addTearDown(flagChanges.close);

      await vectors.attach(
        store: store,
        modelId: _model,
        sink: MockSyncedEmbeddingSink(),
        flagChanges: flagChanges.stream,
      );
      expect(rounds, 0);

      flags[syncEmbeddingsFlag] = true;
      flagChanges.add(null);
      await pumpEventQueue();
      expect(rounds, 1);
      expect(settings[embeddingVectorsCaughtUpKey(_model)], 'true');

      flagChanges.add(null);
      await pumpEventQueue();
      await vectors.catchUp();
      expect(rounds, 1);
    });

    test('a round that fails is tried again later', () async {
      var attempts = 0;
      vectors.catchUpRound = () async {
        attempts++;
        if (attempts == 1) throw StateError('no host yet');
      };

      await attach();
      expect(settings, isEmpty);
      verify(
        () => logger.error(
          any(),
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'embeddingVectors',
          message: any(named: 'message'),
        ),
      ).called(1);

      await vectors.catchUp();
      expect(attempts, 2);
      expect(settings[embeddingVectorsCaughtUpKey(_model)], 'true');
    });

    test('does nothing without a round to run', () async {
      await attach();
      expect(settings, isEmpty);
    });
  });

  group('inbound queue', () {
    test(
      're-checks held versions each time the queue drains after work',
      () async {
        final sink = MockSyncedEmbeddingSink();
        when(sink.recheckAll).thenAnswer((_) async {});
        await attach(sink: sink);
        final depth = StreamController<QueueDepthSignal>();
        addTearDown(depth.close);
        vectors.watchInboundQueue(depth.stream);

        depth.add(const QueueDepthSignal(total: 0));
        await pumpEventQueue();
        verifyNever(sink.recheckAll);

        depth
          ..add(const QueueDepthSignal(total: 3))
          ..add(const QueueDepthSignal(total: 0));
        await pumpEventQueue();
        verify(sink.recheckAll).called(1);
      },
    );

    test('a re-check that fails is logged', () async {
      final sink = MockSyncedEmbeddingSink();
      when(sink.recheckAll).thenThrow(StateError('store closed'));
      await attach(sink: sink);
      final depth = StreamController<QueueDepthSignal>();
      addTearDown(depth.close);
      vectors.watchInboundQueue(depth.stream);

      depth
        ..add(const QueueDepthSignal(total: 1))
        ..add(const QueueDepthSignal(total: 0));
      await pumpEventQueue();

      verify(
        () => logger.error(
          any(),
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'embeddingVectors',
          message: 'held embedding versions could not be re-checked',
        ),
      ).called(1);
    });

    test('a drain without the pipeline re-checks nothing', () async {
      final depth = StreamController<QueueDepthSignal>();
      addTearDown(depth.close);
      vectors.watchInboundQueue(depth.stream);

      depth
        ..add(const QueueDepthSignal(total: 1))
        ..add(const QueueDepthSignal(total: 0));
      await pumpEventQueue();

      expect(vectors.sink, isNull);
    });
  });

  test('messageFor carries every field of the version', () {
    const version = EmbeddingRegister(
      entityId: 'r1',
      modelId: _model,
      entityType: 'agent_report',
      contentHash: 'h',
      vectorClock: VectorClock({'a': 1}),
      sourceVectorClock: VectorClock({'a': 0}),
      taskId: 't1',
      subtype: 'current',
      originatingHostId: 'a',
    );

    final message = EmbeddingVectorsSync.messageFor(
      version,
      jsonPath: '/x.json',
    );

    expect(
      SyncMessage.fromJson(
        jsonDecode(jsonEncode(message)) as Map<String, dynamic>,
      ),
      message,
    );
    expect(message.taskId, 't1');
    expect(message.subtype, 'current');
    expect(message.sourceVectorClock, const VectorClock({'a': 0}));
    expect(message.jsonPath, '/x.json');
    final journal = EmbeddingVectorsSync.messageFor(
      _register('e', vc: const VectorClock({'a': 1})),
    );
    expect(journal.taskId, isNull);
    expect(journal.subtype, isNull);
  });
}
