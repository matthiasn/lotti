import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_agent_trigger_tokens.dart';
import 'package:lotti/classes/day_directive_models.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
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

  group('reanchorDigestTriggerTokens', () {
    test('rewrites a digest token whose day has already passed', () {
      final tokens = reanchorDigestTriggerTokens(
        {dayAgentDigestToken('dayplan-2026-07-20')},
        DateTime(2026, 7, 23, 9),
      );

      expect(tokens, {dayAgentDigestToken('dayplan-2026-07-23')});
    });

    test('preserves the non-digest tokens riding along', () {
      final tokens = reanchorDigestTriggerTokens({
        dayAgentDigestToken('dayplan-2026-07-20'),
        dayAgentProcessingJobToken(
          'job-1',
          requestedAt: DateTime(2026, 7, 20, 6),
        ),
      }, DateTime(2026, 7, 23, 9));

      expect(tokens, {
        dayAgentProcessingJobToken(
          'job-1',
          requestedAt: DateTime(2026, 7, 20, 6),
        ),
        dayAgentDigestToken('dayplan-2026-07-23'),
      });
    });

    test('leaves an on-time wake untouched', () {
      final original = {dayAgentDigestToken('dayplan-2026-07-23')};

      expect(
        identical(
          reanchorDigestTriggerTokens(original, DateTime(2026, 7, 23, 6, 2)),
          original,
        ),
        isTrue,
        reason: 'No rewrite means the caller keeps the exact token identity.',
      );
    });

    test('leaves a wake that fires early for a future day untouched', () {
      final original = {dayAgentDigestToken('dayplan-2026-07-24')};

      expect(
        reanchorDigestTriggerTokens(original, DateTime(2026, 7, 23, 23, 58)),
        original,
        reason:
            'Firing before the anchored day is clock skew, not staleness — '
            'pulling the anchor backwards would digest a day twice.',
      );
    });

    test('leaves a non-digest token set untouched', () {
      final original = {
        dayAgentDraftingToken('dayplan-2026-07-20'),
        dayAgentPlanningDayToken('dayplan-2026-07-20'),
      };

      expect(
        reanchorDigestTriggerTokens(original, DateTime(2026, 7, 23, 9)),
        original,
        reason: 'Only the coordinator digest re-anchors; day work does not.',
      );
    });

    test('ignores an unparseable digest day rather than rewriting it', () {
      final original = {'${dayAgentDigestPrefix}not-a-day'};

      expect(
        reanchorDigestTriggerTokens(original, DateTime(2026, 7, 23, 9)),
        original,
      );
    });
  });

  group('nextDigestTimeAfterDay', () {
    test('keeps the plain next slot when it clears the anchored day', () {
      expect(
        nextDigestTimeAfterDay(
          DateTime(2026, 7, 23, 6, 5),
          DateTime(2026, 7, 23),
        ),
        DateTime(2026, 7, 24, 6),
      );
    });

    test('skips a slot that would digest the anchored day twice', () {
      expect(
        nextDigestTimeAfterDay(DateTime(2026, 7, 23, 3), DateTime(2026, 7, 23)),
        DateTime(2026, 7, 24, 6),
        reason:
            'A stale wake re-anchored to today at 03:00 must not be followed '
            'by today 06:00 — that is a second digest for the same day.',
      );
    });

    test('rolls over a month boundary while skipping', () {
      expect(
        nextDigestTimeAfterDay(DateTime(2026, 7, 31, 3), DateTime(2026, 7, 31)),
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
        policy.forKind(DayAgentWakeKind.digest),
        const Duration(seconds: 60),
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
      'workflow setup before the first provider turn does not consume the '
      'deadline',
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

          expect(upstreamListened, isTrue);
          expect(errors, isEmpty);

          async
            ..elapse(const Duration(seconds: 29))
            ..flushMicrotasks();
          expect(errors, isEmpty);

          async
            ..elapse(const Duration(seconds: 1))
            ..flushMicrotasks();
          expect(errors.single, isA<DayAgentInferenceTimedOutException>());
          unawaited(source.close());
        });
      },
    );

    test('a later provider turn cannot start after the deadline expires', () {
      fakeAsync((async) {
        final first = StreamController<CreateChatCompletionStreamResponse>(
          sync: true,
        );
        var secondListened = false;
        final second = StreamController<CreateChatCompletionStreamResponse>(
          sync: true,
          onListen: () {
            secondListened = true;
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

        expect(errors, hasLength(2));
        expect(
          errors,
          everyElement(isA<DayAgentInferenceTimedOutException>()),
        );
        expect(secondListened, isFalse);
        unawaited(first.close());
        unawaited(second.close());
      });
    });

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

    test('disposing the wake cancels its deadline and active provider', () {
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
        unawaited(repository.dispose());
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 31))
          ..flushMicrotasks();

        expect(upstreamCancelled, isTrue);
        expect(
          errors,
          isEmpty,
          reason: 'Disposal is normal wake teardown, not a timeout failure.',
        );
        unawaited(source.close());
      });
    });

    test(
      'a provider stream subscribed after disposal closes without starting',
      () async {
        var upstreamListened = false;
        final source = StreamController<CreateChatCompletionStreamResponse>(
          sync: true,
          onListen: () {
            upstreamListened = true;
          },
        );
        final repository = DayAgentTimeoutInferenceRepository(
          delegate: _StreamInferenceRepository(source.stream),
          wakeKind: DayAgentWakeKind.draft,
          timeout: const Duration(seconds: 30),
        );
        final stream = repository.generateTextWithMessages(
          messages: const [],
          model: 'qwen3.5-397b-a17b',
          temperature: 0.3,
          provider: testInferenceProvider(),
        );

        await repository.dispose();

        final chunks = await stream.toList();

        expect(chunks, isEmpty);
        expect(
          upstreamListened,
          isFalse,
          reason:
              'Disposed wake wrappers must not start new provider requests.',
        );
        unawaited(source.close());
      },
    );

    test('absorbs an upstream error surfaced by timeout cancellation', () {
      fakeAsync((async) {
        final source = StreamController<CreateChatCompletionStreamResponse>(
          sync: true,
          onCancel: () => Future<void>.error(
            StateError('detached provider request failed during cancellation'),
          ),
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
        async
          ..elapse(const Duration(seconds: 30))
          ..flushMicrotasks();

        expect(errors, hasLength(1));
        expect(errors.single, isA<DayAgentInferenceTimedOutException>());
        unawaited(source.close());
      });
    });
  });

  group('day-agent output token budget', () {
    test('uses measured headroom per wake kind', () {
      const policy = DayAgentOutputTokenBudgetPolicy();

      expect(policy.forKind(DayAgentWakeKind.capture), 4096);
      expect(policy.forKind(DayAgentWakeKind.draft), 8192);
      expect(policy.forKind(DayAgentWakeKind.refine), 4096);
      expect(policy.forKind(DayAgentWakeKind.digest), 4096);
      expect(policy.forKind(DayAgentWakeKind.general), 4096);
    });

    test('rejects a non-positive provider ceiling', () {
      expect(
        () => DayAgentOutputBudgetInferenceRepository(
          delegate: const _StreamInferenceRepository(Stream.empty()),
          wakeKind: DayAgentWakeKind.draft,
          maxCompletionTokens: 0,
        ),
        throwsA(
          isA<ArgumentError>()
              .having(
                (error) => error.invalidValue,
                'invalidValue',
                0,
              )
              .having(
                (error) => error.name,
                'name',
                'maxCompletionTokens',
              ),
        ),
      );
    });

    test(
      'forwards the configured ceiling and preserves a lower caller cap',
      () async {
        final delegate = _RecordingInferenceRepository([
          Stream.value(
            _textChunk(finishReason: ChatCompletionFinishReason.stop),
          ),
          Stream.value(
            _textChunk(finishReason: ChatCompletionFinishReason.stop),
          ),
        ]);
        final repository = DayAgentOutputBudgetInferenceRepository(
          delegate: delegate,
          wakeKind: DayAgentWakeKind.draft,
          maxCompletionTokens: 8192,
        );

        await repository
            .generateTextWithMessages(
              messages: const [],
              model: 'glm-5.2',
              temperature: 0.3,
              provider: testInferenceProvider(),
            )
            .drain<void>();
        await repository
            .generateTextWithMessages(
              messages: const [],
              model: 'glm-5.2',
              temperature: 0.3,
              provider: testInferenceProvider(),
              maxCompletionTokens: 2048,
            )
            .drain<void>();

        expect(delegate.maxCompletionTokens, [8192, 2048]);
      },
    );

    test(
      'a provider length finish becomes a typed retryable failure',
      () async {
        final repository = DayAgentOutputBudgetInferenceRepository(
          delegate: _StreamInferenceRepository(
            Stream.fromIterable([
              _textChunk(finishReason: ChatCompletionFinishReason.length),
              _usageChunk(outputTokens: 4096),
            ]),
          ),
          wakeKind: DayAgentWakeKind.capture,
          maxCompletionTokens: 4096,
        );

        await expectLater(
          repository.generateTextWithMessages(
            messages: const [],
            model: 'glm-5.2',
            temperature: 0.3,
            provider: testInferenceProvider(),
          ),
          emitsInOrder([
            isA<CreateChatCompletionStreamResponse>(),
            isA<CreateChatCompletionStreamResponse>(),
            emitsError(
              isA<DayAgentOutputLimitExceededException>()
                  .having(
                    (error) => error.wakeKind,
                    'wakeKind',
                    DayAgentWakeKind.capture,
                  )
                  .having(
                    (error) => error.maxCompletionTokens,
                    'maxCompletionTokens',
                    4096,
                  ),
            ),
          ]),
        );
      },
    );

    test(
      'usage at the ceiling catches providers that omit finish reason',
      () async {
        final repository = DayAgentOutputBudgetInferenceRepository(
          delegate: _StreamInferenceRepository(
            Stream.fromIterable([
              _textChunk(finishReason: ChatCompletionFinishReason.stop),
              _usageChunk(outputTokens: 4096),
            ]),
          ),
          wakeKind: DayAgentWakeKind.refine,
          maxCompletionTokens: 4096,
        );

        await expectLater(
          repository
              .generateText(
                prompt: 'refine',
                model: 'qwen3.5-397b-a17b',
                temperature: 0.3,
                systemMessage: null,
                provider: testInferenceProvider(),
              )
              .drain<void>(),
          throwsA(isA<DayAgentOutputLimitExceededException>()),
        );
      },
    );

    test(
      'reasoning usage contributes to the provider output ceiling',
      () async {
        final repository = DayAgentOutputBudgetInferenceRepository(
          delegate: _StreamInferenceRepository(
            Stream.fromIterable([
              _textChunk(finishReason: ChatCompletionFinishReason.stop),
              _usageChunk(outputTokens: 3000, reasoningTokens: 1096),
            ]),
          ),
          wakeKind: DayAgentWakeKind.refine,
          maxCompletionTokens: 4096,
        );

        await expectLater(
          repository
              .generateText(
                prompt: 'refine',
                model: 'gemini-2.5-pro',
                temperature: 0.3,
                systemMessage: null,
                provider: testInferenceProvider(),
              )
              .drain<void>(),
          throwsA(isA<DayAgentOutputLimitExceededException>()),
        );
      },
    );

    test(
      'OpenAI-compatible completion usage does not double-count reasoning',
      () async {
        final chunks = [
          _textChunk(finishReason: ChatCompletionFinishReason.stop),
          _usageChunk(outputTokens: 3000, reasoningTokens: 1096),
        ];
        final repository = DayAgentOutputBudgetInferenceRepository(
          delegate: _StreamInferenceRepository(Stream.fromIterable(chunks)),
          wakeKind: DayAgentWakeKind.refine,
          maxCompletionTokens: 4096,
        );

        expect(
          await repository
              .generateText(
                prompt: 'refine',
                model: 'glm-5.2',
                temperature: 0.3,
                systemMessage: null,
                provider: testInferenceProvider(
                  inferenceProviderType: InferenceProviderType.melious,
                ),
              )
              .toList(),
          chunks,
        );
      },
    );

    test('a natural response below the ceiling completes normally', () async {
      final chunks = [
        _textChunk(finishReason: ChatCompletionFinishReason.stop),
        _usageChunk(outputTokens: 1200),
      ];
      final repository = DayAgentOutputBudgetInferenceRepository(
        delegate: _StreamInferenceRepository(Stream.fromIterable(chunks)),
        wakeKind: DayAgentWakeKind.digest,
        maxCompletionTokens: 4096,
      );

      expect(
        await repository
            .generateTextWithMessages(
              messages: const [],
              model: 'glm-5.2',
              temperature: 0.3,
              provider: testInferenceProvider(),
            )
            .toList(),
        chunks,
      );
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

CreateChatCompletionStreamResponse _textChunk({
  required ChatCompletionFinishReason finishReason,
}) => CreateChatCompletionStreamResponse(
  id: 'text',
  created: 0,
  model: 'model',
  choices: [
    ChatCompletionStreamResponseChoice(
      index: 0,
      delta: const ChatCompletionStreamResponseDelta(content: 'response'),
      finishReason: finishReason,
    ),
  ],
);

CreateChatCompletionStreamResponse _usageChunk({
  required int outputTokens,
  int? reasoningTokens,
}) => CreateChatCompletionStreamResponse(
  id: 'usage',
  created: 0,
  model: 'model',
  choices: const [],
  usage: CompletionUsage(
    promptTokens: 100,
    completionTokens: outputTokens,
    totalTokens: 100 + outputTokens,
    completionTokensDetails: CompletionTokensDetails(
      reasoningTokens: reasoningTokens,
    ),
  ),
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

class _RecordingInferenceRepository implements InferenceRepositoryInterface {
  _RecordingInferenceRepository(this.streams);

  final List<Stream<CreateChatCompletionStreamResponse>> streams;
  final List<int?> maxCompletionTokens = [];
  var _next = 0;

  Stream<CreateChatCompletionStreamResponse> _take(int? limit) {
    maxCompletionTokens.add(limit);
    return streams[_next++];
  }

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
  }) => _take(maxCompletionTokens);

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
  }) => _take(maxCompletionTokens);
}
