import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/repository/mistral_inference_repository.dart';
import 'package:lotti/features/front_agent/model/front_turn_failure.dart';

void main() {
  group('ofInference', () {
    // What the Mistral repository actually throws, by status.
    MistralInferenceException http(int status) => MistralInferenceException(
      'Mistral API error (HTTP $status, type=x, code=1)',
    );

    final cases = <String, (Object, FrontTurnFailure)>{
      'HTTP 429': (http(429), FrontTurnFailure.rateLimit),
      'HTTP 401': (http(401), FrontTurnFailure.authentication),
      'HTTP 402': (http(402), FrontTurnFailure.outOfCredit),
      'HTTP 503': (http(503), FrontTurnFailure.provider),
      'HTTP 400': (http(400), FrontTurnFailure.provider),
      'a stalled stream': (
        TimeoutException('No stream event', const Duration(seconds: 15)),
        FrontTurnFailure.timeout,
      ),
      'no route to the host': (
        const SocketException('Failed host lookup: api.mistral.ai'),
        FrontTurnFailure.network,
      ),
      'anything else': (StateError('odd'), FrontTurnFailure.unknown),
    };
    for (final MapEntry(key: name, value: (error, failure)) in cases.entries) {
      test('$name is $failure', () {
        expect(FrontTurnFailure.ofInference(error), failure);
      });
    }
  });

  group('across the wake boundary', () {
    test('every failure survives the wake exception that carries it', () {
      for (final failure in FrontTurnFailure.values) {
        // As agent_wiring throws it for a failed registered runner.
        final wakeError = WakeFailedException(
          kind: 'front',
          reason: failure.wakeError(http429),
        );
        expect(FrontTurnFailure.fromWakeError(wakeError), failure);
      }
    });

    test("the wake error keeps the exception's type but never its message", () {
      expect(
        FrontTurnFailure.rateLimit.wakeError(http429),
        'front turn failed: rateLimit (MistralInferenceException)',
      );
      expect(
        FrontTurnFailure.noModel.wakeError(),
        'front turn failed: noModel',
      );
    });

    test("the run cap's timeout is a timeout; a user's stop is not", () {
      expect(
        FrontTurnFailure.fromWakeError(TimeoutException('timeout')),
        FrontTurnFailure.timeout,
      );
      expect(
        FrontTurnFailure.fromWakeError(TimeoutException('cancelled')),
        FrontTurnFailure.unknown,
      );
    });

    test('an error from anywhere else is unknown', () {
      expect(FrontTurnFailure.fromWakeError(null), FrontTurnFailure.unknown);
      expect(
        FrontTurnFailure.fromWakeError(StateError('wake failed')),
        FrontTurnFailure.unknown,
      );
      expect(
        FrontTurnFailure.fromWakeError('front turn failed: notACause'),
        FrontTurnFailure.unknown,
      );
    });
  });
}

final http429 = MistralInferenceException('Mistral API error (HTTP 429)');
