import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'sync_event_processor_test_helpers.dart';

const _path = '/deep_backfill/upload-1.json';
const _clock = VectorClock({'host-a': 3});

void main() {
  late Directory tempDir;
  late AttachmentIndex index;
  late SyncEventProcessor resolver;

  const inventory = SyncDeepBackfillInventory(
    roundId: 'round-1',
    hostId: 'host-a',
    payloadType: SyncSequencePayloadType.journalEntity,
    batch: 0,
    jsonPath: _path,
    attachmentEventId: r'$upload-1',
  );
  const request = SyncDeepBackfillRequest(
    requesterId: 'host-b',
    targetHostId: 'host-a',
    payloadType: SyncSequencePayloadType.agentLink,
    jsonPath: _path,
    attachmentEventId: r'$upload-1',
  );

  /// Indexes the upload event, whose attachment decodes to [document].
  void indexUpload(Object document) {
    final descriptor = MockEvent();
    when(() => descriptor.eventId).thenReturn(r'$upload-1');
    when(() => descriptor.attachmentMimetype).thenReturn('application/json');
    when(() => descriptor.content).thenReturn({'relativePath': _path});
    when(descriptor.downloadAndDecryptAttachment).thenAnswer(
      (_) async => MatrixFile(
        bytes: Uint8List.fromList(utf8.encode(jsonEncode(document))),
        name: 'upload-1.json',
      ),
    );
    index.record(descriptor);
  }

  setUpAll(registerSyncProcessorFallbacks);

  setUp(() {
    setUpProcessorMocks();
    tempDir = Directory.systemTemp.createTempSync('deep_backfill_resolve');
    index = AttachmentIndex();
    resolver = SyncEventProcessor(
      loggingService: loggingService,
      updateNotifications: updateNotifications,
      aiConfigRepository: aiConfigRepository,
      savedTaskFiltersRepository: savedTaskFiltersRepository,
      settingsDb: settingsDb,
      journalEntityLoader: journalEntityLoader,
      documentsDirectory: tempDir,
      attachmentIndex: index,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test("fills an inventory's lists from its attachment and clears the "
      'attachment, without writing the document to disk', () async {
    indexUpload({
      'records': [
        const DeepBackfillRecord(id: 'a', vectorClock: _clock).toJson(),
      ],
      'conflicts': [
        const DeepBackfillRecord(id: 'b', vectorClock: _clock).toJson(),
      ],
    });

    final resolved =
        await resolver.resolveDeepBackfillMessageForTesting(inventory)
            as SyncDeepBackfillInventory;

    expect(resolved.records.single.id, 'a');
    expect(resolved.records.single.vectorClock, _clock);
    expect(resolved.conflicts.single.id, 'b');
    expect(resolved.attachmentEventId, isNull);
    expect(resolved.jsonPath, isNull);
    expect(resolved.hostId, 'host-a');
    expect(File('${tempDir.path}$_path').existsSync(), isFalse);
  });

  test("fills a request's records from its attachment", () async {
    indexUpload({
      'records': [
        const DeepBackfillRequestRecord(id: 'x', absent: true).toJson(),
      ],
    });

    final resolved =
        await resolver.resolveDeepBackfillMessageForTesting(request)
            as SyncDeepBackfillRequest;

    expect(resolved.records, const [
      DeepBackfillRequestRecord(id: 'x', absent: true),
    ]);
    expect(resolved.attachmentEventId, isNull);
  });

  test('leaves a message with inline lists, and any other message, as it '
      'is', () async {
    final inline = inventory.copyWith(jsonPath: null, attachmentEventId: null);
    const other = SyncMessage.backfillRequest(entries: [], requesterId: 'b');

    expect(
      await resolver.resolveDeepBackfillMessageForTesting(inline),
      same(inline),
    );
    expect(
      await resolver.resolveDeepBackfillMessageForTesting(other),
      same(other),
    );
  });

  test(
    'waits for an attachment that has not arrived yet: the queue retries',
    () async {
      await expectLater(
        resolver.resolveDeepBackfillMessageForTesting(inventory),
        throwsA(
          isA<FileSystemException>().having(
            (e) => e.message,
            'message',
            'attachment descriptor not yet available',
          ),
        ),
      );
    },
  );

  test('returns an unreadable document unresolved — still naming its '
      'attachment, so the service ignores it rather than read an empty '
      'inventory', () async {
    indexUpload(['not', 'a', 'document']);

    final resolved = await resolver.resolveDeepBackfillMessageForTesting(
      inventory,
    );

    expect(resolved, same(inventory));
    verify(
      () => loggingService.error(
        any(),
        any(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'processor.resolve.deepBackfill.parse',
      ),
    ).called(1);
  });

  test('returns a message whose path escapes the documents directory '
      'unresolved', () async {
    final escaping = inventory.copyWith(jsonPath: '../../outside.json');

    expect(
      await resolver.resolveDeepBackfillMessageForTesting(escaping),
      same(escaping),
    );
    verify(
      () => loggingService.error(
        any(),
        any(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'processor.resolve.deepBackfill.invalidPath',
      ),
    ).called(1);
  });
}
