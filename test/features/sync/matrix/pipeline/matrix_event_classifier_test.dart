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

    test('shouldPrefetchAttachment true for media and json (sender agnostic)',
        () {
      final image = MockEvent();
      when(() => image.senderId).thenReturn('@other:server');
      when(() => image.attachmentMimetype).thenReturn('image/png');
      expect(
          MatrixEventClassifier.shouldPrefetchAttachment(image, '@me:server'),
          isTrue);

      final json = MockEvent();
      when(() => json.senderId).thenReturn('@me:server');
      when(() => json.attachmentMimetype).thenReturn('application/json');
      expect(MatrixEventClassifier.shouldPrefetchAttachment(json, '@me:server'),
          isTrue);

      final none = MockEvent();
      when(() => none.senderId).thenReturn('@other:server');
      when(() => none.attachmentMimetype).thenReturn('');
      expect(MatrixEventClassifier.shouldPrefetchAttachment(none, '@me:server'),
          isFalse);
    });
  });
}
