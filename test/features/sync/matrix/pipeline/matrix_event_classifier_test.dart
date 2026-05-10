import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_event_classifier.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

class _GeneratedClassifierScenario {
  const _GeneratedClassifierScenario({
    required this.syncMsgType,
    required this.validFallbackText,
    required this.nonEmptyAttachmentMime,
  });

  final bool syncMsgType;
  final bool validFallbackText;
  final bool nonEmptyAttachmentMime;

  bool get expectedSyncPayload => syncMsgType || validFallbackText;

  bool get expectedAttachment => nonEmptyAttachmentMime;

  @override
  String toString() {
    return '_GeneratedClassifierScenario('
        'syncMsgType: $syncMsgType, '
        'validFallbackText: $validFallbackText, '
        'nonEmptyAttachmentMime: $nonEmptyAttachmentMime'
        ')';
  }
}

extension _AnyMatrixEventClassifierScenario on glados.Any {
  glados.Generator<_GeneratedClassifierScenario> get classifierScenario =>
      glados.CombinableAny(this).combine3(
        glados.BoolAny(this).bool,
        glados.BoolAny(this).bool,
        glados.BoolAny(this).bool,
        (
          bool syncMsgType,
          bool validFallbackText,
          bool nonEmptyAttachmentMime,
        ) => _GeneratedClassifierScenario(
          syncMsgType: syncMsgType,
          validFallbackText: validFallbackText,
          nonEmptyAttachmentMime: nonEmptyAttachmentMime,
        ),
      );
}

Event _generatedEvent(_GeneratedClassifierScenario scenario) {
  final event = MockEvent();
  when(() => event.attachmentMimetype).thenReturn(
    scenario.nonEmptyAttachmentMime ? 'application/json' : '',
  );
  when(() => event.content).thenReturn(<String, dynamic>{
    if (scenario.syncMsgType) 'msgtype': syncMessageType,
  });
  when(() => event.text).thenReturn(
    scenario.validFallbackText
        ? base64.encode(utf8.encode('{"runtimeType":"journalEntity"}'))
        : 'not-base64',
  );
  return event;
}

void main() {
  group('MatrixEventClassifier', () {
    test('isAttachment returns true when attachmentMimetype is not empty', () {
      final e = MockEvent();
      when(() => e.attachmentMimetype).thenReturn('application/json');
      expect(MatrixEventClassifier.isAttachment(e), isTrue);
    });

    test('isSyncPayloadEvent detects by msgtype == syncMessageType', () {
      final e = MockEvent();
      when(
        () => e.content,
      ).thenReturn(<String, dynamic>{'msgtype': syncMessageType});
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
        final payload = base64.encode(
          utf8.encode('{"runtimeType":"journalEntity"}'),
        );
        when(() => e.text).thenReturn(payload);
        expect(MatrixEventClassifier.isSyncPayloadEvent(e), isTrue);
      },
    );

    test('isSyncPayloadEvent false when neither msgtype nor valid payload', () {
      final e = MockEvent();
      when(() => e.content).thenReturn(<String, dynamic>{});
      when(() => e.text).thenReturn('not-base64');
      expect(MatrixEventClassifier.isSyncPayloadEvent(e), isFalse);
    });

    // Prefetch behavior removed.

    glados.Glados(
      glados.any.classifierScenario,
    ).test(
      'generated classification matches msgtype/text and attachment model',
      (scenario) {
        final event = _generatedEvent(scenario);

        expect(
          MatrixEventClassifier.isSyncPayloadEvent(event),
          scenario.expectedSyncPayload,
        );
        expect(
          MatrixEventClassifier.isAttachment(event),
          scenario.expectedAttachment,
        );
      },
      tags: 'glados',
    );
  });
}
