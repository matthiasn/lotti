import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_directive_models.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow_models.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../agents/test_utils.dart';

// The rest of day_agent_workflow_models.dart (tool exceptions, observation
// trimming, scheduled-wake carry-over, counter GC) is exercised through
// day_agent_workflow_test.dart; this file covers the pure schedule helper
// added for the ADR 0032 digest cadence.
void main() {
  group('nextDigestTime', () {
    test('before the digest hour resolves to today at 06:00', () {
      expect(
        nextDigestTime(DateTime(2026, 7, 23, 4, 30)),
        DateTime(2026, 7, 23, 6),
      );
    });

    test('at or after the digest hour resolves to tomorrow at 06:00', () {
      expect(
        nextDigestTime(DateTime(2026, 7, 23, 6)),
        DateTime(2026, 7, 24, 6),
        reason: 'Exactly 06:00 is not strictly ahead — schedule tomorrow.',
      );
      expect(
        nextDigestTime(DateTime(2026, 7, 23, 21, 15)),
        DateTime(2026, 7, 24, 6),
      );
    });

    test('rolls over month boundaries via day arithmetic', () {
      expect(
        nextDigestTime(DateTime(2026, 7, 31, 9)),
        DateTime(2026, 8, 1, 6),
      );
    });
  });

  group('selectDigestStatusEvents', () {
    DayStatusEventEntity event(
      String id,
      DateTime raisedAt, {
      DayStatusKind status = DayStatusKind.attentionNeeded,
      List<DayStatusReason> reasons = const [DayStatusReason.overCommitted],
    }) => makeTestDayStatusEvent(
      id: id,
      status: status,
      reasons: reasons,
      raisedAt: raisedAt,
      createdAt: raisedAt,
    );

    test('within the limit everything survives, chronologically', () {
      final (:selected, :truncated) = selectDigestStatusEvents(
        [
          event('b', DateTime(2026, 7, 23, 12)),
          event('a', DateTime(2026, 7, 23, 8)),
        ],
        limit: 2,
      );

      expect(truncated, isFalse);
      expect([for (final e in selected) e.id], ['a', 'b']);
    });

    test('severity outranks age when truncating: an old escalation beats a '
        'new routine close', () {
      final (:selected, :truncated) = selectDigestStatusEvents(
        [
          event(
            'old-escalation',
            DateTime(2026, 7, 22, 8),
            reasons: const [DayStatusReason.directiveUnsatisfiable],
          ),
          event(
            'mid-close',
            DateTime(2026, 7, 22, 21),
            status: DayStatusKind.dayClosed,
            reasons: const [],
          ),
          event(
            'new-ontrack',
            DateTime(2026, 7, 23, 9),
            status: DayStatusKind.onTrack,
            reasons: const [],
          ),
        ],
        limit: 2,
      );

      expect(truncated, isTrue);
      expect(
        [for (final e in selected) e.id],
        ['old-escalation', 'mid-close'],
        reason:
            'The onTrack event is the least decision-relevant despite being '
            'newest; survivors render chronologically.',
      );
    });

    test('reason weight breaks ties within attentionNeeded', () {
      final (:selected, truncated: _) = selectDigestStatusEvents(
        [
          event(
            'newer-divergence',
            DateTime(2026, 7, 23, 10),
            reasons: const [DayStatusReason.userDivergence],
          ),
          event(
            'older-unsatisfiable',
            DateTime(2026, 7, 23, 8),
            reasons: const [DayStatusReason.directiveUnsatisfiable],
          ),
          event(
            'older-blocked',
            DateTime(2026, 7, 23, 6),
            reasons: const [DayStatusReason.processingBlocked],
          ),
        ],
        limit: 2,
      );

      expect(
        [for (final e in selected) e.id],
        ['older-blocked', 'older-unsatisfiable'],
        reason:
            'directiveUnsatisfiable (4) and processingBlocked (2) outrank '
            'userDivergence (1) regardless of recency.',
      );
    });

    test('recency then id give a deterministic total order in a tier', () {
      final t = DateTime(2026, 7, 23, 9);
      final (:selected, truncated: _) = selectDigestStatusEvents(
        [
          event('c-same-time', t),
          event('a-same-time', t),
          event('older', t.subtract(const Duration(hours: 1))),
        ],
        limit: 2,
      );

      expect(
        [for (final e in selected) e.id],
        ['a-same-time', 'c-same-time'],
        reason: 'Equal severity: the two newest survive, id breaks the tie.',
      );
    });
  });

  group('day-agent inference timeout', () {
    test('uses a materially shorter bound for drafting than general wakes', () {
      const policy = DayAgentInferenceTimeoutPolicy();

      expect(
        policy.forKind(DayAgentWakeKind.capture),
        const Duration(seconds: 20),
      );
      expect(
        policy.forKind(DayAgentWakeKind.draft),
        const Duration(seconds: 30),
      );
      expect(
        policy.forKind(DayAgentWakeKind.refine),
        const Duration(seconds: 30),
      );
      expect(
        policy.forKind(DayAgentWakeKind.general),
        const Duration(seconds: 60),
      );
    });

    test('rejects a non-positive deadline', () {
      expect(
        () => DayAgentTimeoutInferenceRepository(
          delegate: const _StreamInferenceRepository(Stream.empty()),
          wakeKind: DayAgentWakeKind.draft,
          timeout: Duration.zero,
        ),
        throwsArgumentError,
      );
    });

    test('a completed provider turn stays closed after the wake deadline', () {
      fakeAsync((async) {
        final source = StreamController<CreateChatCompletionStreamResponse>(
          sync: true,
        );
        final chunks = <CreateChatCompletionStreamResponse>[];
        final errors = <Object>[];
        final repository = DayAgentTimeoutInferenceRepository(
          delegate: _StreamInferenceRepository(source.stream),
          wakeKind: DayAgentWakeKind.capture,
          timeout: const Duration(seconds: 20),
        );

        repository
            .generateText(
              prompt: 'capture',
              model: 'glm-5.2',
              temperature: 0.3,
              systemMessage: null,
              provider: testInferenceProvider(),
            )
            .listen(
              chunks.add,
              onError: errors.add,
            );
        source
          ..add(_thinkingChunk('glm-5.2'))
          ..close();
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 21))
          ..flushMicrotasks();

        expect(chunks, hasLength(1));
        expect(errors, isEmpty);
      });
    });

    test(
      'a provider turn started after the wake deadline fails immediately',
      () {
        fakeAsync((async) {
          var upstreamListened = false;
          final source = StreamController<CreateChatCompletionStreamResponse>(
            sync: true,
            onListen: () {
              upstreamListened = true;
            },
          );
          final errors = <Object>[];
          final repository = DayAgentTimeoutInferenceRepository(
            delegate: _StreamInferenceRepository(source.stream),
            wakeKind: DayAgentWakeKind.draft,
            timeout: const Duration(seconds: 30),
          );

          async
            ..elapse(const Duration(seconds: 30))
            ..flushMicrotasks();
          repository
              .generateTextWithMessages(
                messages: const [],
                model: 'qwen3.5-397b-a17b',
                temperature: 0.3,
                provider: testInferenceProvider(),
              )
              .listen((_) {}, onError: errors.add);
          async.flushMicrotasks();

          expect(errors.single, isA<DayAgentInferenceTimedOutException>());
          expect(
            upstreamListened,
            isFalse,
            reason: 'An expired wake must not start another provider request.',
          );
          unawaited(source.close());
        });
      },
    );

    test('downstream cancellation cancels the active provider stream', () {
      fakeAsync((async) {
        var upstreamCancelled = false;
        final source = StreamController<CreateChatCompletionStreamResponse>(
          sync: true,
          onCancel: () {
            upstreamCancelled = true;
          },
        );
        final errors = <Object>[];
        final repository = DayAgentTimeoutInferenceRepository(
          delegate: _StreamInferenceRepository(source.stream),
          wakeKind: DayAgentWakeKind.draft,
          timeout: const Duration(seconds: 30),
        );

        final subscription = repository
            .generateTextWithMessages(
              messages: const [],
              model: 'qwen3.5-397b-a17b',
              temperature: 0.3,
              provider: testInferenceProvider(),
            )
            .listen((_) {}, onError: errors.add);
        unawaited(subscription.cancel());
        async.flushMicrotasks();

        expect(upstreamCancelled, isTrue);
        expect(errors, isEmpty);
        unawaited(source.close());
      });
    });

    test('classifies and cancels a provider stream at the total deadline', () {
      fakeAsync((async) {
        var upstreamCancelled = false;
        final source = StreamController<CreateChatCompletionStreamResponse>(
          sync: true,
          onCancel: () {
            upstreamCancelled = true;
          },
        );
        final errors = <Object>[];
        final repository = DayAgentTimeoutInferenceRepository(
          delegate: _StreamInferenceRepository(source.stream),
          wakeKind: DayAgentWakeKind.draft,
          timeout: const Duration(seconds: 30),
        );

        final subscription = repository
            .generateTextWithMessages(
              messages: const [],
              model: 'glm-5.2',
              temperature: 0.3,
              provider: testInferenceProvider(),
            )
            .listen((_) {}, onError: errors.add);

        async
          ..elapse(const Duration(seconds: 29))
          ..flushMicrotasks();
        expect(errors, isEmpty);

        async
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks();
        expect(errors, hasLength(1));
        expect(errors.single, isA<TimeoutException>());
        expect(errors.single, isA<DayAgentInferenceTimedOutException>());
        expect(errors.single.toString(), contains('draft'));
        expect(errors.single.toString(), contains('30s'));
        expect(
          upstreamCancelled,
          isTrue,
          reason:
              'The inner timeout must cancel the provider stream so a late '
              'tool batch cannot mutate after the retry starts.',
        );

        unawaited(subscription.cancel());
        unawaited(source.close());
      });
    });

    test('stream activity does not extend the total deadline', () {
      fakeAsync((async) {
        var upstreamCancelled = false;
        final source = StreamController<CreateChatCompletionStreamResponse>(
          sync: true,
          onCancel: () {
            upstreamCancelled = true;
          },
        );
        final errors = <Object>[];
        final repository = DayAgentTimeoutInferenceRepository(
          delegate: _StreamInferenceRepository(source.stream),
          wakeKind: DayAgentWakeKind.draft,
          timeout: const Duration(seconds: 30),
        );

        repository
            .generateTextWithMessages(
              messages: const [],
              model: 'qwen3.5-397b-a17b',
              temperature: 0.3,
              provider: testInferenceProvider(),
            )
            .listen((_) {}, onError: errors.add);

        for (var i = 0; i < 5; i++) {
          async.elapse(const Duration(seconds: 5));
          source.add(_thinkingChunk('qwen3.5-397b-a17b'));
          async.flushMicrotasks();
          expect(errors, isEmpty);
        }
        async
          ..elapse(const Duration(seconds: 5))
          ..flushMicrotasks();

        expect(errors.single, isA<DayAgentInferenceTimedOutException>());
        expect(upstreamCancelled, isTrue);
        unawaited(source.close());
      });
    });

    test('later provider turns receive only the remaining wake deadline', () {
      fakeAsync((async) {
        final first = StreamController<CreateChatCompletionStreamResponse>(
          sync: true,
        );
        var secondCancelled = false;
        final second = StreamController<CreateChatCompletionStreamResponse>(
          sync: true,
          onCancel: () {
            secondCancelled = true;
          },
        );
        final errors = <Object>[];
        final repository = DayAgentTimeoutInferenceRepository(
          delegate: _SequenceInferenceRepository([
            first.stream,
            second.stream,
          ]),
          wakeKind: DayAgentWakeKind.draft,
          timeout: const Duration(seconds: 30),
        );

        repository
            .generateTextWithMessages(
              messages: const [],
              model: 'qwen3.5-397b-a17b',
              temperature: 0.3,
              provider: testInferenceProvider(),
            )
            .listen((_) {}, onError: errors.add);
        async.elapse(const Duration(seconds: 20));
        unawaited(first.close());
        async.flushMicrotasks();

        repository
            .generateTextWithMessages(
              messages: const [],
              model: 'qwen3.5-397b-a17b',
              temperature: 0.3,
              provider: testInferenceProvider(),
            )
            .listen((_) {}, onError: errors.add);
        async
          ..elapse(const Duration(seconds: 9))
          ..flushMicrotasks();
        expect(errors, isEmpty);

        async
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks();
        expect(errors.single, isA<DayAgentInferenceTimedOutException>());
        expect(secondCancelled, isTrue);
        unawaited(second.close());
      });
    });
  });
}

CreateChatCompletionStreamResponse _thinkingChunk(String model) =>
    CreateChatCompletionStreamResponse(
      id: 'thinking',
      created: 0,
      model: model,
      choices: const [],
    );

class _StreamInferenceRepository implements InferenceRepositoryInterface {
  const _StreamInferenceRepository(this.stream);

  final Stream<CreateChatCompletionStreamResponse> stream;

  @override
  Stream<CreateChatCompletionStreamResponse> generateText({
    required String prompt,
    required String model,
    required double temperature,
    required String? systemMessage,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
  }) => stream;

  @override
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    Map<String, String>? thoughtSignatures,
    ThoughtSignatureCollector? signatureCollector,
    int? turnIndex,
    InferenceImpactCollector? impactCollector,
  }) => stream;
}

class _SequenceInferenceRepository implements InferenceRepositoryInterface {
  _SequenceInferenceRepository(this.streams);

  final List<Stream<CreateChatCompletionStreamResponse>> streams;
  var _next = 0;

  Stream<CreateChatCompletionStreamResponse> _take() => streams[_next++];

  @override
  Stream<CreateChatCompletionStreamResponse> generateText({
    required String prompt,
    required String model,
    required double temperature,
    required String? systemMessage,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
  }) => _take();

  @override
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    Map<String, String>? thoughtSignatures,
    ThoughtSignatureCollector? signatureCollector,
    int? turnIndex,
    InferenceImpactCollector? impactCollector,
  }) => _take();
}
