import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/ai/database/embedding_register.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/embedding_sync/embedding_sync_receiver.dart';
import 'package:lotti/features/ai/embedding_sync/embedding_vectors_payload.dart';
import 'package:lotti/features/ai/embedding_sync/held_embedding_versions.dart';
import 'package:lotti/features/ai/embedding_sync/synced_embedding_sink.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/in_memory_embedding_store.dart';
import '../../../mocks/mocks.dart';

const _model = 'embeddinggemma-300m-q4';
final _date = DateTime.utc(2026, 10, 30);

String _hash(String text) => EmbeddingContentExtractor.contentHash(text);

Float32List _vector(double value) =>
    Float32List(kEmbeddingDimensions)
      ..fillRange(0, kEmbeddingDimensions, value);

String _payload(List<double> values) =>
    utf8.decode(encodeEmbeddingVectors([for (final v in values) _vector(v)]));

Metadata _meta(
  String id, {
  VectorClock? vc,
  String? categoryId,
  List<String>? labelIds,
}) => Metadata(
  id: id,
  createdAt: _date,
  updatedAt: _date,
  dateFrom: _date,
  dateTo: _date,
  vectorClock: vc,
  categoryId: categoryId,
  labelIds: labelIds,
);

JournalEntry _entry(
  String id,
  String text, {
  VectorClock? vc,
  String? categoryId,
}) => JournalEntry(
  meta: _meta(id, vc: vc, categoryId: categoryId),
  entryText: EntryText(plainText: text),
);

Task _task(String id, String title, {required List<String> labelIds}) => Task(
  meta: _meta(id, labelIds: labelIds),
  data: TaskData(
    status: TaskStatus.open(id: 's', createdAt: _date, utcOffset: 0),
    title: title,
    statusHistory: const [],
    dateFrom: _date,
    dateTo: _date,
  ),
);

LabelDefinition _label(String id, String name, {bool private = false}) =>
    LabelDefinition(
      id: id,
      createdAt: _date,
      updatedAt: _date,
      name: name,
      color: '#000000',
      vectorClock: null,
      private: private,
    );

AgentReportText _report(String content, {String? tldr, String? oneLiner}) =>
    (content: content, tldr: tldr, oneLiner: oneLiner);

EmbeddingRegister _version({
  required String entityId,
  required String text,
  required Map<String, int> vc,
  Map<String, int>? source,
  String host = 'host-a',
  String entityType = kEntityTypeJournalText,
  String taskId = '',
  bool deleted = false,
  String model = _model,
}) => EmbeddingRegister(
  entityId: entityId,
  modelId: model,
  entityType: entityType,
  contentHash: deleted ? '' : _hash(text),
  vectorClock: VectorClock(vc),
  sourceVectorClock: source == null ? null : VectorClock(source),
  deleted: deleted,
  taskId: taskId,
  originatingHostId: host,
);

/// One receiving device: an in-memory vector store, a held-versions file,
/// and the journal, labels and reports its own copy holds.
class _Device {
  _Device(this.holdPath);

  final String holdPath;
  final store = InMemoryEmbeddingStore();
  final journal = <String, JournalEntity>{};
  final labels = <LabelDefinition>[];
  final reports = <String, AgentReportText>{};
  final flags = <String, bool>{
    enableEmbeddingsFlag: true,
    syncEmbeddingsFlag: true,
  };
  late MockJournalDb journalDb;
  late HeldEmbeddingVersions held;
  late EmbeddingSyncReceiver receiver;

  Future<void> open() async {
    journalDb = MockJournalDb();
    when(() => journalDb.journalEntityById(any())).thenAnswer(
      (i) async => journal[i.positionalArguments.first as String],
    );
    when(
      journalDb.getAllLabelDefinitionsIncludingPrivate,
    ).thenAnswer((_) async => labels);
    // This device hides private items: the toggle-aware read leaves them out.
    when(journalDb.getAllLabelDefinitions).thenAnswer(
      (_) async => [
        for (final label in labels)
          if (!(label.private ?? false)) label,
      ],
    );
    held = await HeldEmbeddingVersions.open(holdPath);
    receiver = EmbeddingSyncReceiver(
      store: store,
      modelId: _model,
      journalDb: journalDb,
      held: held,
      reportContent: (id) async => reports[id],
      readFlag: (flag) async => flags[flag] ?? false,
    );
  }

  Future<void> receive(EmbeddingRegister version, {String? payload}) =>
      receiver.apply(
        IncomingEmbeddingVersion(
          register: version,
          payload: version.deleted ? null : payload ?? _payload([0.5]),
        ),
      );

  /// The first value of each stored chunk of [entityId].
  List<double>? storedValues(String entityId) => [
    for (final chunk in store.chunkVectors(entityId)) chunk.first,
  ];
}

void main() {
  late Directory tempDir;
  var deviceIndex = 0;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('embedding_receiver_');
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  Future<_Device> device() async {
    final d = _Device(p.join(tempDir.path, 'holds_${deviceIndex++}.json'));
    await d.open();
    return d;
  }

  group('agentReportTextReader', () {
    test('reads the body, TLDR and one-liner of a report', () async {
      final repository = MockAgentRepository();
      when(() => repository.getEntity('r1')).thenAnswer(
        (_) async => AgentDomainEntity.agentReport(
          id: 'r1',
          agentId: 'agent-1',
          scope: 'current',
          createdAt: _date,
          vectorClock: null,
          content: 'The body',
          tldr: 'The TLDR',
          oneLiner: 'The one-liner',
        ),
      );

      final read = agentReportTextReader(() => repository);

      expect(await read('r1'), (
        content: 'The body',
        tldr: 'The TLDR',
        oneLiner: 'The one-liner',
      ));
    });

    test(
      'reads nothing for another entity, a missing one, or no database',
      () async {
        final repository = MockAgentRepository();
        when(() => repository.getEntity('head')).thenAnswer(
          (_) async => AgentDomainEntity.agentReportHead(
            id: 'head',
            agentId: 'agent-1',
            scope: 'current',
            reportId: 'r1',
            updatedAt: _date,
            vectorClock: null,
          ),
        );
        when(
          () => repository.getEntity('gone'),
        ).thenAnswer((_) async => null);

        final read = agentReportTextReader(() => repository);
        expect(await read('head'), isNull);
        expect(await read('gone'), isNull);
        expect(await agentReportTextReader(() => null)('r1'), isNull);
      },
    );
  });

  group('merge', () {
    test(
      'stores a version whose hash matches, in the local category',
      () async {
        final d = await device();
        d.journal['e1'] = _entry(
          'e1',
          'A long enough journal entry text',
          categoryId: 'c1',
        );

        await d.receive(
          _version(
            entityId: 'e1',
            text: 'A long enough journal entry text',
            vc: {'a': 1},
          ),
          payload: _payload([0.1, 0.2]),
        );

        expect(d.storedValues('e1'), [closeTo(0.1, 1e-6), closeTo(0.2, 1e-6)]);
        expect(d.store.chunks['e1']!.categoryId, 'c1');
        expect(
          d.store.registers['e1']!.vectorClock,
          const VectorClock({'a': 1}),
        );
        expect(d.held.all, isEmpty);
      },
    );

    test(
      'drops a dominated or equal version and keeps what is stored',
      () async {
        final d = await device();
        d.journal['e1'] = _entry('e1', 'A long enough journal entry text');
        const text = 'A long enough journal entry text';
        await d.receive(
          _version(entityId: 'e1', text: text, vc: {'a': 2}),
          payload: _payload([0.2]),
        );

        await d.receive(
          _version(entityId: 'e1', text: text, vc: {'a': 1}),
          payload: _payload([0.9]),
        );
        await d.receive(
          _version(entityId: 'e1', text: text, vc: {'a': 2}),
          payload: _payload([0.8]),
        );

        expect(d.storedValues('e1'), [closeTo(0.2, 1e-6)]);
        expect(
          d.store.registers['e1']!.vectorClock,
          const VectorClock({'a': 2}),
        );
      },
    );

    test('a dominating version replaces the whole chunk set', () async {
      final d = await device();
      const text = 'A long enough journal entry text';
      d.journal['e1'] = _entry('e1', text);
      await d.receive(
        _version(entityId: 'e1', text: text, vc: {'a': 1}),
        payload: _payload([0.1, 0.2, 0.3]),
      );

      await d.receive(
        _version(entityId: 'e1', text: text, vc: {'a': 1, 'b': 1}, host: 'b'),
        payload: _payload([0.7]),
      );

      expect(d.storedValues('e1'), [closeTo(0.7, 1e-6)]);
    });

    test(
      'a receiver keeps the received clock and never adds its own',
      () async {
        final d = await device();
        const text = 'A long enough journal entry text';
        d.journal['e1'] = _entry('e1', text);

        await d.receive(_version(entityId: 'e1', text: text, vc: {'a': 3}));

        expect(d.store.registers['e1']!.vectorClock!.vclock, {'a': 3});
      },
    );

    test(
      'of two concurrent versions every device keeps the same one, '
      'whatever its own text',
      () async {
        const older = 'The text as host a embedded it first';
        const newer = 'The text as host b embedded it later';
        // b embedded the newer text: its source clock is larger.
        final fromA = _version(
          entityId: 'e1',
          text: older,
          vc: {'a': 1},
          source: {'a': 1},
          host: 'a',
        );
        final fromB = _version(
          entityId: 'e1',
          text: newer,
          vc: {'b': 1},
          source: {'a': 1, 'b': 1},
          host: 'b',
        );

        // One device already holds the newer text, the other still the older.
        final upToDate = await device();
        upToDate.journal['e1'] = _entry(
          'e1',
          newer,
          vc: const VectorClock({'a': 1, 'b': 1}),
        );
        final behind = await device();
        behind.journal['e1'] = _entry(
          'e1',
          older,
          vc: const VectorClock({'a': 1}),
        );

        await upToDate.receive(fromA, payload: _payload([0.1]));
        await upToDate.receive(fromB, payload: _payload([0.2]));
        await behind.receive(fromB, payload: _payload([0.2]));
        await behind.receive(fromA, payload: _payload([0.1]));

        const merged = VectorClock({'a': 1, 'b': 1});
        // The device on the newer text discarded a's version — its entry
        // has moved past a's source — and stored b's.
        expect(upToDate.storedValues('e1'), [closeTo(0.2, 1e-6)]);
        expect(upToDate.store.registers['e1']!.originatingHostId, 'b');
        // The device still on the older text holds b's version, rather than
        // storing a's: it is the winner everywhere, and stored once the
        // newer text arrives.
        expect(behind.store.registers['e1'], isNull);
        expect(behind.held['e1|$_model']!.register.originatingHostId, 'b');
        expect(behind.held['e1|$_model']!.register.vectorClock, merged);

        behind.journal['e1'] = _entry(
          'e1',
          newer,
          vc: const VectorClock({'a': 1, 'b': 1}),
        );
        await behind.receiver.onJournalEntityApplied('e1');

        expect(behind.storedValues('e1'), [closeTo(0.2, 1e-6)]);
        expect(behind.store.registers['e1']!.originatingHostId, 'b');
        expect(behind.store.registers['e1']!.vectorClock, merged);
      },
    );

    test(
      'a stored version that wins a concurrent pair keeps its chunks and '
      'takes the merged clock',
      () async {
        final d = await device();
        const text = 'A long enough journal entry text';
        d.journal['e1'] = _entry('e1', text);
        await d.receive(
          _version(
            entityId: 'e1',
            text: text,
            vc: {'a': 1},
            source: {'a': 2},
            host: 'a',
          ),
          payload: _payload([0.1]),
        );

        await d.receive(
          _version(
            entityId: 'e1',
            text: text,
            vc: {'b': 1},
            source: {'a': 1},
            host: 'b',
          ),
          payload: _payload([0.9]),
        );

        expect(d.storedValues('e1'), [closeTo(0.1, 1e-6)]);
        expect(
          d.store.registers['e1']!.vectorClock,
          const VectorClock({'a': 1, 'b': 1}),
        );
      },
    );

    test('a redelivered version is a no-op', () async {
      final d = await device();
      const text = 'A long enough journal entry text';
      d.journal['e1'] = _entry('e1', text);
      final version = _version(entityId: 'e1', text: text, vc: {'a': 1});
      await d.receive(version, payload: _payload([0.3]));
      final stored = d.store.chunks['e1'];

      await d.receive(version, payload: _payload([0.3]));

      expect(identical(d.store.chunks['e1'], stored), isTrue);
    });
  });

  group('concurrent pairs', () {
    test('of two versions of the same text, the lower host wins', () async {
      final d = await device();
      const text = 'A long enough journal entry text';
      d.journal['e1'] = _entry('e1', text);

      await d.receive(
        _version(
          entityId: 'e1',
          text: text,
          vc: {'b': 1},
          source: {'a': 1},
          host: 'b',
        ),
        payload: _payload([0.2]),
      );
      await d.receive(
        _version(
          entityId: 'e1',
          text: text,
          vc: {'a': 1},
          source: {'a': 1},
          host: 'a',
        ),
        payload: _payload([0.1]),
      );

      expect(d.storedValues('e1'), [closeTo(0.1, 1e-6)]);
      expect(d.store.registers['e1']!.originatingHostId, 'a');
    });

    test('a version that beats a concurrent held one replaces it', () async {
      final d = await device();
      await d.receive(
        _version(
          entityId: 'e1',
          text: 'Older text not here',
          vc: {'a': 1},
          source: {'a': 1},
          host: 'a',
        ),
      );
      await d.receive(
        _version(
          entityId: 'e1',
          text: 'Newer text not here',
          vc: {'b': 1},
          source: {'a': 1, 'b': 1},
          host: 'b',
        ),
      );

      final held = d.held['e1|$_model']!.register;
      expect(held.originatingHostId, 'b');
      expect(held.vectorClock, const VectorClock({'a': 1, 'b': 1}));
    });

    test(
      'a stored winner that takes the merged clock drops a held version it '
      'now covers',
      () async {
        final d = await device();
        const text = 'A long enough journal entry text';
        d.journal['e1'] = _entry('e1', text);
        await d.receive(
          _version(
            entityId: 'e1',
            text: text,
            vc: {'a': 1},
            source: {'a': 5},
            host: 'a',
          ),
        );
        await d.held.put(
          HeldEmbeddingVersion(
            register: _version(
              entityId: 'e1',
              text: 'x',
              vc: {'b': 1},
              host: 'b',
            ),
            payload: _payload([0.3]),
          ),
        );

        await d.receive(
          _version(
            entityId: 'e1',
            text: 'Other text',
            vc: {'b': 1},
            source: {'a': 1},
            host: 'b',
          ),
        );

        expect(d.held.all, isEmpty);
        expect(d.store.registers['e1']!.originatingHostId, 'a');
      },
    );
  });

  test('a re-check whose store write fails keeps the version held', () async {
    final failing = _Device(p.join(tempDir.path, 'failing.json'));
    await failing.open();
    const text = 'An entry that has not synced yet';
    await failing.receive(_version(entityId: 'e1', text: text, vc: {'a': 1}));
    failing.journal['e1'] = _entry('e1', text);
    final receiver = EmbeddingSyncReceiver(
      store: _ThrowingStore(),
      modelId: _model,
      journalDb: failing.journalDb,
      held: failing.held,
      reportContent: (_) async => null,
      readFlag: (_) async => true,
    );

    await expectLater(receiver.recheckAll(), throwsStateError);

    expect(failing.held.all, hasLength(1));
  });

  group('holding', () {
    test(
      'a version ahead of its entry is held, then stored when it applies',
      () async {
        final d = await device();
        const text = 'The edited text that arrives later';
        d.journal['e1'] = _entry(
          'e1',
          'The text this device still has',
          vc: const VectorClock({'a': 1}),
        );
        await d.receive(
          _version(entityId: 'e1', text: text, vc: {'a': 2}, source: {'a': 2}),
          payload: _payload([0.4]),
        );
        expect(d.store.chunks, isEmpty);
        expect(d.held.all, hasLength(1));

        d.journal['e1'] = _entry('e1', text, vc: const VectorClock({'a': 2}));
        await d.receiver.onJournalEntityApplied('e1');

        expect(d.storedValues('e1'), [closeTo(0.4, 1e-6)]);
        expect(d.held.all, isEmpty);
      },
    );

    test(
      'a version whose entity is missing is held until it arrives',
      () async {
        final d = await device();
        const text = 'An entry that has not synced yet';
        await d.receive(_version(entityId: 'e1', text: text, vc: {'a': 1}));
        expect(d.held.all, hasLength(1));

        // Another entity's arrival releases nothing.
        d.journal['e2'] = _entry('e2', 'Some other entry altogether here');
        await d.receiver.onJournalEntityApplied('e2');
        expect(d.held.all, hasLength(1));

        d.journal['e1'] = _entry('e1', text);
        await d.receiver.onJournalEntityApplied('e1');
        expect(d.store.chunks.keys, ['e1']);
      },
    );

    test(
      'a report vector before its report is held, then stored in the task '
      'category when the report applies',
      () async {
        final d = await device();
        const content = 'The agent report about the task progress';
        d.journal['t1'] = _task('t1', 'The task', labelIds: const []).copyWith(
          meta: _meta('t1', categoryId: 'work'),
        );
        await d.receive(
          _version(
            entityId: 'r1',
            text: content,
            vc: {'a': 1},
            entityType: kEntityTypeAgentReport,
            taskId: 't1',
          ),
        );
        expect(d.held.all, hasLength(1));

        d.reports['r1'] = _report('  $content  ');
        await d.receiver.onAgentEntityApplied('r1');

        expect(d.store.chunks['r1']!.categoryId, 'work');
        expect(d.store.chunks['r1']!.taskId, 't1');
        expect(d.held.all, isEmpty);
      },
    );

    test(
      'a report vector whose task has not arrived is held, then stored in '
      "the task's category when the task applies",
      () async {
        final d = await device();
        const content = 'The agent report about the task progress';
        d.reports['r1'] = _report(content);
        await d.receive(
          _version(
            entityId: 'r1',
            text: content,
            vc: {'a': 1},
            entityType: kEntityTypeAgentReport,
            taskId: 't1',
          ),
        );
        expect(d.store.chunks, isEmpty);

        d.journal['t1'] = _task('t1', 'The task', labelIds: const []).copyWith(
          meta: _meta('t1', categoryId: 'work'),
        );
        await d.receiver.onJournalEntityApplied('t1');

        expect(d.store.chunks['r1']!.categoryId, 'work');
      },
    );

    test(
      "a task vector before its label's definition is held, then stored when "
      'the definition applies',
      () async {
        final d = await device();
        const title = 'Fix the login flow for everyone';
        d.journal['t1'] = _task('t1', title, labelIds: const ['l1']);
        final text = EmbeddingContentExtractor.extractTaskText(
          title: title,
          labelNames: const ['security'],
        )!;
        await d.receive(
          _version(
            entityId: 't1',
            text: text,
            vc: {'a': 1},
            entityType: kEntityTypeTask,
          ),
        );
        expect(d.held['t1|$_model']!.labelIds, ['l1']);

        await d.receiver.onEntityDefinitionApplied('l2');
        expect(d.store.chunks, isEmpty);

        d.labels.add(_label('l1', 'security'));
        await d.receiver.onEntityDefinitionApplied('l1');

        expect(d.store.chunks.keys, ['t1']);
      },
    );

    test(
      'a task vector naming a private label is stored on a device that hides '
      'private items',
      () async {
        // The sender showed private items and named the label; this device
        // hides them. Its text must still name the label, or the version
        // waits for good with its receipt recorded.
        final d = await device();
        const title = 'Plan the surprise for the team';
        d.labels.add(_label('l1', 'personal', private: true));
        d.journal['t1'] = _task('t1', title, labelIds: const ['l1']);
        final text = EmbeddingContentExtractor.extractTaskText(
          title: title,
          labelNames: const ['personal'],
        )!;

        await d.receive(
          _version(
            entityId: 't1',
            text: text,
            vc: {'a': 1},
            entityType: kEntityTypeTask,
          ),
        );

        expect(d.store.registers['t1']!.contentHash, _hash(text));
        expect(d.held.all, isEmpty);
      },
    );

    test(
      'a report vector made from the whole report is stored when this '
      "device's report says the same",
      () async {
        final d = await device();
        d.journal['t1'] = _task('t1', 'The task', labelIds: const []);
        final local = _report(
          'The detailed body of the report.',
          tldr: 'Shipping is blocked on review.',
          oneLiner: 'Blocked on review',
        );
        d.reports['r1'] = local;
        final whole = EmbeddingContentExtractor.extractAgentReportText(
          content: local.content,
          tldr: local.tldr,
          oneLiner: local.oneLiner,
        )!;

        await d.receive(
          _version(
            entityId: 'r1',
            text: whole,
            vc: {'a': 1},
            entityType: kEntityTypeAgentReport,
            taskId: 't1',
          ),
        );

        expect(d.store.registers['r1']!.contentHash, _hash(whole));
        expect(d.held.all, isEmpty);
      },
    );

    test(
      'a report vector an older writer made from the body alone is still '
      'stored',
      () async {
        final d = await device();
        d.journal['t1'] = _task('t1', 'The task', labelIds: const []);
        const body = 'The detailed body of the report.';
        d.reports['r1'] = _report(
          body,
          tldr: 'Shipping is blocked on review.',
          oneLiner: 'Blocked on review',
        );

        await d.receive(
          _version(
            entityId: 'r1',
            text: body,
            vc: {'a': 1},
            entityType: kEntityTypeAgentReport,
            taskId: 't1',
          ),
        );

        expect(d.store.registers['r1']!.contentHash, _hash(body));
        expect(d.held.all, isEmpty);
      },
    );

    test(
      'a report vector of a text this device does not hold is held',
      () async {
        final d = await device();
        d.journal['t1'] = _task('t1', 'The task', labelIds: const []);
        d.reports['r1'] = _report('The detailed body of the report.');

        await d.receive(
          _version(
            entityId: 'r1',
            text: 'Another report text entirely, not this one',
            vc: {'a': 1},
            entityType: kEntityTypeAgentReport,
            taskId: 't1',
          ),
        );

        expect(d.store.registers, isEmpty);
        expect(d.held.all.single.register.entityId, 'r1');
      },
    );

    test('watchHeldCount reports each hold and each release', () async {
      final d = await device();
      final counts = <int>[];
      final subscription = d.receiver.watchHeldCount().listen(counts.add);
      addTearDown(subscription.cancel);
      const text = 'The entry text as the sender wrote it';

      await d.receive(_version(entityId: 'e1', text: text, vc: {'a': 1}));
      d.journal['e1'] = _entry('e1', text);
      await d.receiver.onJournalEntityApplied('e1');
      await pumpEventQueue();

      expect(counts, [0, 1, 0]);
      expect(d.store.chunks.keys, ['e1']);
    });

    test(
      'a held version is discarded once the entry has moved past its source',
      () async {
        final d = await device();
        d.journal['e1'] = _entry(
          'e1',
          'The original text of this entry',
          vc: const VectorClock({'a': 1}),
        );
        await d.receive(
          _version(
            entityId: 'e1',
            text: 'A text this device never had at all',
            vc: {'a': 1},
            source: {'a': 1},
          ),
        );
        expect(d.held.all, hasLength(1));

        d.journal['e1'] = _entry(
          'e1',
          'The entry as edited here afterwards',
          vc: const VectorClock({'a': 1, 'b': 1}),
        );
        await d.receiver.onJournalEntityApplied('e1');

        expect(d.held.all, isEmpty);
        expect(d.store.chunks, isEmpty);
      },
    );

    test('a held version survives a restart', () async {
      final path = p.join(tempDir.path, 'restart.json');
      final first = _Device(path);
      await first.open();
      const text = 'An entry that has not synced yet';
      await first.receive(
        _version(entityId: 'e1', text: text, vc: {'a': 1}),
        payload: _payload([0.6]),
      );

      final second = _Device(path);
      await second.open();
      second.journal['e1'] = _entry('e1', text);
      await second.receiver.recheckAll();

      expect(second.storedValues('e1'), [closeTo(0.6, 1e-6)]);
    });

    test('a newer version replaces the one held of its register', () async {
      final d = await device();
      await d.receive(
        _version(
          entityId: 'e1',
          text: 'First version of the text',
          vc: {'a': 1},
        ),
      );
      await d.receive(
        _version(
          entityId: 'e1',
          text: 'Second version of the text',
          vc: {'a': 2},
        ),
      );
      await d.receive(
        _version(
          entityId: 'e1',
          text: 'Stale copy of the first one',
          vc: {'a': 1},
        ),
      );

      expect(d.held.all, hasLength(1));
      expect(
        d.held['e1|$_model']!.register.vectorClock,
        const VectorClock({'a': 2}),
      );
    });
  });

  group('tombstones', () {
    test(
      'a tombstone for an entry this device never held is kept, never held, '
      'and dominates a late live copy',
      () async {
        final d = await device();
        await d.receive(
          _version(entityId: 'e1', text: '', vc: {'a': 2}, deleted: true),
        );

        expect(d.store.registers['e1']!.deleted, isTrue);
        expect(d.held.all, isEmpty);

        const text = 'The entry before it was deleted';
        d.journal['e1'] = _entry('e1', text);
        await d.receive(_version(entityId: 'e1', text: text, vc: {'a': 1}));

        expect(d.store.chunks, isEmpty);
        expect(d.store.registers['e1']!.deleted, isTrue);
      },
    );

    test(
      'a tombstone beats concurrent vectors of the same text on every device',
      () async {
        const text = 'The entry right before it was deleted';
        final live = _version(
          entityId: 'e1',
          text: text,
          vc: {'a': 1},
          source: {'a': 1},
          host: 'a',
        );
        final tombstone = _version(
          entityId: 'e1',
          text: '',
          vc: {'b': 1},
          source: {'a': 1},
          host: 'b',
          deleted: true,
        );
        for (final order in [
          [live, tombstone],
          [tombstone, live],
        ]) {
          final d = await device();
          d.journal['e1'] = _entry('e1', text, vc: const VectorClock({'a': 1}));
          for (final version in order) {
            await d.receive(version);
          }

          expect(d.store.chunks, isEmpty);
          expect(d.store.registers['e1']!.deleted, isTrue);
          expect(
            d.store.registers['e1']!.vectorClock,
            const VectorClock({'a': 1, 'b': 1}),
          );
        }
      },
    );

    test('a tombstone removes stored vectors and what is held', () async {
      final d = await device();
      const text = 'A long enough journal entry text';
      d.journal['e1'] = _entry('e1', text);
      await d.receive(_version(entityId: 'e1', text: text, vc: {'a': 1}));
      await d.receive(
        _version(
          entityId: 'e1',
          text: 'Text that is not here yet',
          vc: {'a': 2},
        ),
      );
      expect(d.held.all, hasLength(1));

      await d.receive(
        _version(entityId: 'e1', text: '', vc: {'a': 3}, deleted: true),
      );

      expect(d.store.chunks, isEmpty);
      expect(d.held.all, isEmpty);
    });

    test(
      'a superseded report never returns, in either delivery order, and its '
      'successor stays',
      () async {
        const r1Text = 'The first agent report for this task';
        const r2Text = 'The second agent report for this task';
        EmbeddingRegister report(
          String id,
          String text,
          int counter, {
          bool deleted = false,
        }) => _version(
          entityId: id,
          text: text,
          vc: {'a': counter},
          entityType: kEntityTypeAgentReport,
          taskId: 't1',
          deleted: deleted,
        );

        for (final order in [
          // Tombstone first, then the delayed live copy.
          [report('r1', '', 3, deleted: true), report('r1', r1Text, 1)],
          // Live copy, tombstone, then a redelivery of the live copy.
          [
            report('r1', r1Text, 1),
            report('r1', '', 3, deleted: true),
            report('r1', r1Text, 1),
          ],
        ]) {
          final d = await device();
          d.journal['t1'] = _task('t1', 'The task', labelIds: const []);
          d.reports
            ..['r1'] = _report(r1Text)
            ..['r2'] = _report(r2Text);
          await d.receive(report('r2', r2Text, 2));
          for (final version in order) {
            await d.receive(version);
          }

          expect(d.store.chunks.keys, ['r2']);
          expect(d.store.registers['r1']!.deleted, isTrue);
        }
      },
    );
  });

  group('refusals', () {
    test('drops a version of another model', () async {
      final d = await device();
      const text = 'A long enough journal entry text';
      d.journal['e1'] = _entry('e1', text);

      await d.receive(
        _version(
          entityId: 'e1',
          text: text,
          vc: {'a': 1},
          model: 'other-model',
        ),
      );

      expect(d.store.registers, isEmpty);
      expect(d.held.all, isEmpty);
    });

    test(
      'drops a payload of the wrong width or with a non-finite value',
      () async {
        final d = await device();
        const text = 'A long enough journal entry text';
        d.journal['e1'] = _entry('e1', text);
        final narrow = jsonEncode({'dims': 4, 'chunks': <String>[]});
        final nan = utf8.decode(encodeEmbeddingVectors([_vector(double.nan)]));

        await d.receive(
          _version(entityId: 'e1', text: text, vc: {'a': 1}),
          payload: narrow,
        );
        await d.receive(
          _version(entityId: 'e1', text: text, vc: {'a': 2}),
          payload: nan,
        );

        expect(d.store.registers, isEmpty);
        expect(d.held.all, isEmpty);
      },
    );

    test('stores nothing while either flag is off', () async {
      for (final flag in [enableEmbeddingsFlag, syncEmbeddingsFlag]) {
        final d = await device();
        const text = 'A long enough journal entry text';
        d.journal['e1'] = _entry('e1', text);
        d.flags[flag] = false;

        await d.receive(_version(entityId: 'e1', text: text, vc: {'a': 1}));

        expect(d.store.registers, isEmpty, reason: flag);
      }
    });

    test(
      'a version sent without its file stores nothing and clears an older '
      'held one',
      () async {
        final d = await device();
        await d.receive(
          _version(
            entityId: 'e1',
            text: 'Text that is not here yet',
            vc: {'a': 1},
          ),
        );
        expect(d.held.all, hasLength(1));

        await d.receiver.apply(
          IncomingEmbeddingVersion(
            register: _version(
              entityId: 'e1',
              text: 'Newer text',
              vc: {'a': 2},
            ),
          ),
        );

        expect(d.held.all, isEmpty);
        expect(d.store.registers, isEmpty);
      },
    );
  });
}

/// A store whose writes fail.
class _ThrowingStore extends InMemoryEmbeddingStore {
  @override
  void replaceEntityEmbeddings({
    required String entityId,
    required String entityType,
    required String modelId,
    required String contentHash,
    required List<Float32List> embeddings,
    String categoryId = '',
    String taskId = '',
    String subtype = '',
    EmbeddingRegister? register,
  }) => throw StateError('store closed');
}
