import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/ai/embedding_sync/synced_embedding_sink.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import 'recorded_attachment_stack.dart';
import 'sync_event_processor_test_helpers.dart';

const _path = '/embedding_vectors/e1/m/host-a-3.json';
const _payload = '{"dims":768,"chunks":[]}';

SyncEmbeddingVectors _message({
  bool deleted = false,
  String? attachmentEventId = r'$upload-1',
  List<VectorClock>? covered,
}) => SyncEmbeddingVectors(
  id: 'e1|m',
  entityId: 'e1',
  entityType: 'task',
  modelId: 'm',
  vectorClock: const VectorClock({'host-a': 3}),
  originatingHostId: 'host-a',
  contentHash: deleted ? '' : 'hash',
  deleted: deleted,
  sourceVectorClock: const VectorClock({'host-a': 2}),
  jsonPath: deleted ? null : _path,
  attachmentEventId: deleted ? null : attachmentEventId,
  taskId: 't1',
  subtype: 'current',
  coveredVectorClocks: covered,
);

void main() {
  late Directory tempDir;
  late RecordedAttachmentStack attachments;
  late MockSyncSequenceLogService sequenceLog;
  late MockEmbeddingVectorsSync vectors;
  late MockSyncedEmbeddingSink sink;

  setUpAll(() {
    registerSyncProcessorFallbacks();
    registerAllFallbackValues();
  });

  setUp(() {
    setUpProcessorMocks();
    tempDir = Directory.systemTemp.createTempSync('embedding_vectors_apply');
    attachments = RecordedAttachmentStack();
    sequenceLog = MockSyncSequenceLogService();
    when(
      () => sequenceLog.recordReceivedEntry(
        entryId: any(named: 'entryId'),
        vectorClock: any(named: 'vectorClock'),
        originatingHostId: any(named: 'originatingHostId'),
        coveredVectorClocks: any(named: 'coveredVectorClocks'),
        payloadType: any(named: 'payloadType'),
      ),
    ).thenAnswer((_) async => const <({String hostId, int counter})>[]);
    sink = MockSyncedEmbeddingSink();
    when(() => sink.apply(any())).thenAnswer((_) async {});
    vectors = MockEmbeddingVectorsSync();
    when(() => vectors.sink).thenReturn(sink);
    when(() => vectors.awaitsPipeline).thenAnswer((_) async => false);
    processor = SyncEventProcessor(
      loggingService: loggingService,
      updateNotifications: updateNotifications,
      aiConfigRepository: aiConfigRepository,
      savedTaskFiltersRepository: savedTaskFiltersRepository,
      settingsDb: settingsDb,
      journalEntityLoader: journalEntityLoader,
      sequenceLogService: sequenceLog,
      documentsDirectory: tempDir,
      attachmentIndex: attachments.index,
      attachmentFetcher: attachments.fetcher,
    )..embeddingVectors = vectors;
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  void indexUpload() {
    final descriptor = MockEvent();
    when(() => descriptor.eventId).thenReturn(r'$upload-1');
    when(() => descriptor.attachmentMimetype).thenReturn('application/json');
    when(() => descriptor.content).thenReturn({'relativePath': _path});
    when(descriptor.downloadAndDecryptAttachment).thenAnswer(
      (_) async => MatrixFile(
        bytes: Uint8List.fromList(utf8.encode(_payload)),
        name: 'host-a-3.json',
      ),
    );
    attachments.record(descriptor);
  }

  void receive(SyncEmbeddingVectors message) {
    when(() => event.text).thenReturn(encodeMessage(message));
  }

  Future<void> process() =>
      processor.process(envelope: event, journalDb: journalDb);

  IncomingEmbeddingVersion applied() =>
      verify(() => sink.apply(captureAny())).captured.single
          as IncomingEmbeddingVersion;

  void verifyReceipt({List<VectorClock>? covered}) => verify(
    () => sequenceLog.recordReceivedEntry(
      entryId: 'e1|m',
      vectorClock: const VectorClock({'host-a': 3}),
      originatingHostId: 'host-a',
      coveredVectorClocks: covered,
      payloadType: SyncSequencePayloadType.embeddingVectors,
    ),
  ).called(1);

  void verifyNoReceipt() => verifyNever(
    () => sequenceLog.recordReceivedEntry(
      entryId: any(named: 'entryId'),
      vectorClock: any(named: 'vectorClock'),
      originatingHostId: any(named: 'originatingHostId'),
      coveredVectorClocks: any(named: 'coveredVectorClocks'),
      payloadType: any(named: 'payloadType'),
    ),
  );

  test(
    'a version reaches the sink with its attachment, read from the '
    'descriptor and never written to disk, then records its receipts',
    () async {
      indexUpload();
      receive(
        _message(
          covered: const [
            VectorClock({'host-a': 2}),
          ],
        ),
      );

      await process();

      final version = applied();
      expect(version.payload, _payload);
      expect(version.register.id, 'e1|m');
      expect(version.register.contentHash, 'hash');
      expect(
        version.register.sourceVectorClock,
        const VectorClock({'host-a': 2}),
      );
      expect(version.register.taskId, 't1');
      expect(version.register.subtype, 'current');
      expect(version.register.originatingHostId, 'host-a');
      expect(File('${tempDir.path}$_path').existsSync(), isFalse);
      verifyReceipt(
        covered: const [
          VectorClock({'host-a': 2}),
        ],
      );
    },
  );

  test('a tombstone reaches the sink without a payload', () async {
    receive(_message(deleted: true));

    await process();

    final version = applied();
    expect(version.register.deleted, isTrue);
    expect(version.payload, isNull);
    verifyReceipt();
  });

  test(
    'a version sent without its file reaches the sink without a payload',
    () async {
      receive(_message(attachmentEventId: null));

      await process();

      expect(applied().payload, isNull);
      verifyReceipt();
    },
  );

  test(
    'a version whose attachment has not arrived waits: no sink, no receipt',
    () async {
      receive(_message());

      await expectLater(process(), throwsA(isA<FileSystemException>()));

      verifyNever(() => sink.apply(any()));
      verifyNoReceipt();
    },
  );

  test(
    'a device that does not store vectors records the receipt alone',
    () async {
      when(() => vectors.sink).thenReturn(null);
      receive(_message(deleted: true));

      await process();

      verifyReceipt();
    },
  );

  test(
    'a version that arrives before the pipeline attaches is retried, its '
    'receipt not recorded',
    () async {
      when(() => vectors.sink).thenReturn(null);
      when(() => vectors.awaitsPipeline).thenAnswer((_) async => true);
      receive(_message(deleted: true));

      await expectLater(process(), throwsStateError);

      verifyNoReceipt();
    },
  );

  test(
    'a sink failure records no receipt, so the version is retried',
    () async {
      when(() => sink.apply(any())).thenThrow(StateError('store closed'));
      receive(_message(deleted: true));

      await expectLater(process(), throwsStateError);

      verifyNoReceipt();
    },
  );

  test(
    'without the vectors register wired, the receipt is still recorded',
    () async {
      processor.embeddingVectors = null;
      receive(_message(deleted: true));

      await process();

      verifyReceipt();
    },
  );
}
