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
  });

  final bool syncMsgType;
  final bool validFallbackText;
  bool get expectedSyncPayload => syncMsgType || validFallbackText;

  @override
  String toString() {
    return '_GeneratedClassifierScenario('
        'syncMsgType: $syncMsgType, '
        'validFallbackText: $validFallbackText'
        ')';
  }
}

extension _AnyMatrixEventClassifierScenario on glados.Any {
  glados.Generator<_GeneratedClassifierScenario> get classifierScenario =>
      glados.CombinableAny(this).combine2(
        glados.BoolAny(this).bool,
        glados.BoolAny(this).bool,
        (bool syncMsgType, bool validFallbackText) =>
            _GeneratedClassifierScenario(
              syncMsgType: syncMsgType,
              validFallbackText: validFallbackText,
            ),
      );
}

Event _generatedEvent(_GeneratedClassifierScenario scenario) {
  final event = MockEvent();
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

    glados.Glados(glados.any.classifierScenario).test(
      'generated classification matches msgtype and fallback text model',
      (scenario) {
        final event = _generatedEvent(scenario);

        expect(
          MatrixEventClassifier.isSyncPayloadEvent(event),
          scenario.expectedSyncPayload,
        );
      },
      tags: 'glados',
    );
  });
}
