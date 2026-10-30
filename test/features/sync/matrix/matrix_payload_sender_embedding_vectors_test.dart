import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/sync/matrix/matrix_payload_sender.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import 'matrix_upload_test_stub.dart';

const _path = '/embedding_vectors/e1/m/host-a-3.json';

SyncEmbeddingVectors _message({bool deleted = false}) => SyncEmbeddingVectors(
  id: 'e1|m',
  entityId: 'e1',
  entityType: 'task',
  modelId: 'm',
  vectorClock: const VectorClock({'host-a': 3}),
  originatingHostId: 'host-a',
  contentHash: deleted ? '' : 'hash',
  deleted: deleted,
  jsonPath: deleted ? null : _path,
);

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(MatrixFile(bytes: Uint8List(0), name: 'fallback'));
  });

  late Directory docs;
  late MockRoom room;
  late MatrixUploadTestStub uploadStub;
  late MatrixPayloadSender sender;
  late List<MatrixFile> uploaded;

  File file() =>
      File(p.join(docs.path, 'embedding_vectors', 'e1', 'm', 'host-a-3.json'));

  setUp(() {
    docs = Directory.systemTemp.createTempSync('vectors_payload_sender');
    final logging = MockDomainLogger();
    when(
      () => logging.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) {});
    room = MockRoom();
    when(() => room.id).thenReturn('!room:test');
    uploadStub = MatrixUploadTestStub(room);
    uploaded = [];
    when(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
      ),
    ).thenAnswer(
      uploadStub.record((invocation) async {
        uploaded.add(invocation.positionalArguments.first as MatrixFile);
        return r'$vectors-upload';
      }),
    );
    sender = MatrixPayloadSender(
      loggingService: logging,
      journalDb: MockJournalDb(),
      documentsDirectory: docs,
      sentEventRegistry: SentEventRegistry(),
    );
  });

  tearDown(() => docs.deleteSync(recursive: true));

  test(
    'uploads the version file gzipped and points the message at it',
    () async {
      file()
        ..createSync(recursive: true)
        ..writeAsStringSync('{"dims":768,"chunks":[]}');

      final sent = await sender.sendEmbeddingVectorsPayload(
        room: room,
        message: _message(),
      );

      expect(sent!.attachmentEventId, r'$vectors-upload');
      expect(sent.jsonPath, _path);
      final upload = uploaded.single;
      expect(upload.name, 'host-a-3.json.gz');
      expect(
        utf8.decode(gzip.decode(upload.bytes)),
        '{"dims":768,"chunks":[]}',
      );
    },
  );

  test('a version whose file is gone goes out without one', () async {
    final sent = await sender.sendEmbeddingVectorsPayload(
      room: room,
      message: _message(),
    );

    expect(sent!.jsonPath, isNull);
    expect(sent.attachmentEventId, isNull);
    expect(uploaded, isEmpty);
  });

  test('a tombstone uploads nothing', () async {
    final tombstone = _message(deleted: true);

    expect(
      await sender.sendEmbeddingVectorsPayload(room: room, message: tombstone),
      tombstone,
    );
    expect(uploaded, isEmpty);
  });

  test('a failed upload returns null, so the row is retried', () async {
    file()
      ..createSync(recursive: true)
      ..writeAsStringSync('{}');
    when(
      () => room.sendFileEvent(
        any<MatrixFile>(),
        extraContent: any<Map<String, dynamic>>(named: 'extraContent'),
      ),
    ).thenAnswer((_) async => null);

    expect(
      await sender.sendEmbeddingVectorsPayload(room: room, message: _message()),
      isNull,
    );
    expect(file().existsSync(), isTrue);
  });

  test(
    'a sent version discards its file, and a missing one is no error',
    () async {
      file()
        ..createSync(recursive: true)
        ..writeAsStringSync('{}');

      await sender.discardEmbeddingVectorsFile(_message());
      expect(file().existsSync(), isFalse);

      await sender.discardEmbeddingVectorsFile(_message());
      await sender.discardEmbeddingVectorsFile(_message(deleted: true));
    },
  );
}
