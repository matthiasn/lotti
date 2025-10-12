import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_event_classifier.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockEvent extends Mock implements Event {}

void main() {
  group('MatrixEventClassifier', () {
    test('isAttachment returns true when attachmentMimetype is not empty', () {
      final e = MockEvent();
      when(() => e.attachmentMimetype).thenReturn('application/json');
      expect(MatrixEventClassifier.isAttachment(e), isTrue);
    });

    test('isSyncPayloadEvent detects by msgtype == syncMessageType', () {
      final e = MockEvent();
      when(() => e.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      // text is unused in this branch
      when(() => e.text).thenReturn('');
      expect(MatrixEventClassifier.isSyncPayloadEvent(e), isTrue);
    });

    test(
        'isSyncPayloadEvent detects valid fallback base64 JSON with runtimeType',
        () {
      final e = MockEvent();
      // no msgtype
      when(() => e.content).thenReturn(<String, dynamic>{});
      final payload =
          base64.encode(utf8.encode('{"runtimeType":"journalEntity"}'));
      when(() => e.text).thenReturn(payload);
      expect(MatrixEventClassifier.isSyncPayloadEvent(e), isTrue);
    });

    test('isSyncPayloadEvent false when neither msgtype nor valid payload', () {
      final e = MockEvent();
      when(() => e.content).thenReturn(<String, dynamic>{});
      when(() => e.text).thenReturn('not-base64');
      expect(MatrixEventClassifier.isSyncPayloadEvent(e), isFalse);
    });

    test('shouldPrefetchAttachment true only for remote attachments', () {
      final file = MockEvent();
      when(() => file.senderId).thenReturn('@other:server');
      when(() => file.attachmentMimetype).thenReturn('image/png');
      expect(MatrixEventClassifier.shouldPrefetchAttachment(file, '@me:server'),
          isTrue);

      final mine = MockEvent();
      when(() => mine.senderId).thenReturn('@me:server');
      when(() => mine.attachmentMimetype).thenReturn('image/png');
      expect(MatrixEventClassifier.shouldPrefetchAttachment(mine, '@me:server'),
          isFalse);

      final nofile = MockEvent();
      when(() => nofile.senderId).thenReturn('@other:server');
      when(() => nofile.attachmentMimetype).thenReturn('');
      expect(
          MatrixEventClassifier.shouldPrefetchAttachment(nofile, '@me:server'),
          isFalse);
    });
  });
}
