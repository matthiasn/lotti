import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_config.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/ai_config_factories.dart';
import '../../../ai_consumption/test_utils.dart';
import '../../integration/scripted_conversation_repository.dart';
import 'eval_constraints.dart';
import 'eval_journal_fixture.dart';
import 'eval_runner.dart';
import 'eval_scenario.dart';
import 'eval_test_setup.dart';
import 'eval_variant.dart';

/// End-to-end coverage of the matrix runner against a **scripted** model, so
/// the fan-out, capture and scoring all run in the normal unit-test lane with
/// no provider.
///
/// The load-bearing case is the rejection round trip: production rejects an
/// illegal `draft_day_plan`, hands the failure text back, and the model
/// retries — so the persisted plan is always legal and only the tool-call log
/// preserves the fact that it took two tries.
void main() {
  setUpAll(registerAllFallbackValues);

  // Fixed date so plan dates and the anchored clock are deterministic.
  final today = DateTime(2030, 1, 15);
  final tomorrow = DateTime(2030, 1, 16);

  late AiInteractionCaptureTestBench attribution;

  setUp(() async {
    attribution = AiInteractionCaptureTestBench.create();
    await setUpEvalGetIt(attribution);
  });

  tearDown(tearDownTestGetIt);

  /// A model target that replays [turns], one per `sendMessage`.
  ///
  /// [onOpen] runs inside the cell, after the runner has cleared the
  /// consumption ledger — the only place a test can stand in for a provider
  /// reporting usage.
  EvalModelTarget scriptedTarget({
    required List<List<ChatCompletionMessageToolCall>> turns,
    String id = 'scripted',
    void Function()? onOpen,
    Future<void> Function()? onClose,
    List<ScriptedConversationRepository>? recordInto,
  }) => EvalModelTarget(
    id: id,
    open: (request) async {
      onOpen?.call();
      final repository = ScriptedConversationRepository();
      turns.forEach(repository.script);
      recordInto?.add(repository);
      return EvalLlmLayer(
        conversationRepository: repository,
        cloudInferenceRepository: MockCloudInferenceRepository(),
        profile: testInferenceProfile(
          id: 'profile-eval',
          thinkingModelId: 'models/eval',
        ),
        model: testAiModel(
          id: 'model-eval',
          providerModelId: 'models/eval',
          inferenceProviderId: 'provider-eval',
        ),
        provider: testInferenceProvider(
          id: 'provider-eval',
          apiKey: 'provider-key',
        ),
        close: onClose,
      );
    },
  );

  Map<String, Object?> block({
    required DateTime start,
    required Duration duration,
    String title = 'Focus block',
    String? taskId,
  }) => {
    'title': title,
    'categoryId': evalDefaultCategoryId,
    'start': start.toIso8601String(),
    'end': start.add(duration).toIso8601String(),
    'reason': 'Scripted plan block.',
    'taskId': ?taskId,
  };

  ChatCompletionMessageToolCall draftCall({
    required DateTime planDate,
    required List<Map<String, Object?>> blocks,
    String id = 'draft-call',
  }) => scriptedToolCall(
    id: id,
    name: DayAgentToolNames.draftDayPlan,
    args: {'dayId': dayAgentIdForDate(planDate), 'blocks': blocks},
  );

  /// A single legal morning block for [planDate].
  List<Map<String, Object?>> legalBlocks(DateTime planDate, {String? taskId}) =>
      [
        block(
          start: planDate.add(const Duration(hours: 10)),
          duration: const Duration(hours: 1),
          taskId: taskId,
        ),
      ];

  EvalRunRequest requestFor(
    EvalScenario scenario, {
    EvalVariant variant = evalBaselineVariant,
  }) => EvalRunRequest(
    scenario: scenario,
    variant: variant,
    modelId: 'scripted',
    sample: 1,
    planDate: evalPlanDateFor(scenario, today),
  );

  group('runEvalMatrix', () {
    test(
      'produces one result per scenario x model x variant x sample',
      () async {
        final scenarios = [evalScenarios.first, evalScenarios[1]];
        final results = await runEvalMatrix(
          models: [
            scriptedTarget(
              id: 'model-a',
              turns: [
                [draftCall(planDate: tomorrow, blocks: legalBlocks(tomorrow))],
              ],
            ),
            scriptedTarget(
              id: 'model-b',
              turns: [
                [draftCall(planDate: tomorrow, blocks: legalBlocks(tomorrow))],
              ],
            ),
          ],
          scenarios: scenarios,
          samples: 2,
          today: today,
        );

        expect(results, hasLength(2 * 2 * 1 * 2));
        expect(
          results
              .map(
                (r) =>
                    '${r.request.scenario.id}/${r.request.modelId}/'
                    '${r.request.variant.id}#${r.request.sample}',
              )
              .toSet(),
          hasLength(8),
          reason: 'Every cell must be distinguishable in the report.',
        );
        expect(
          results.map((r) => r.request.sample).toSet(),
          {1, 2},
          reason: 'Samples are 1-based and both must appear.',
        );
      },
    );

    test('drives every shipped scenario end to end', () async {
      // The point is not the scores — a scripted model produces the same
      // block everywhere — but that each fixture can actually be run: its
      // corpus stubs answer, its capture seeds, its wake reaches a plan. A
      // fixture that cannot be driven would otherwise only surface during a
      // paid live run.
      final results = await runEvalMatrix(
        models: [
          EvalModelTarget(
            id: 'scripted',
            // 16:00 is inside the 09:00-17:00 contract for every scenario and
            // after the 15:00 anchor of the same-day one, so a single rule
            // works across the set.
            open: (request) async {
              final repository = ScriptedConversationRepository()
                ..script([
                  draftCall(
                    planDate: request.planDate,
                    blocks: [
                      block(
                        start: request.planDate.add(const Duration(hours: 16)),
                        duration: const Duration(minutes: 30),
                      ),
                    ],
                  ),
                ]);
              return EvalLlmLayer(
                conversationRepository: repository,
                cloudInferenceRepository: MockCloudInferenceRepository(),
                profile: testInferenceProfile(
                  id: 'profile-eval',
                  thinkingModelId: 'models/eval',
                ),
                model: testAiModel(
                  id: 'model-eval',
                  providerModelId: 'models/eval',
                  inferenceProviderId: 'provider-eval',
                ),
                provider: testInferenceProvider(
                  id: 'provider-eval',
                  apiKey: 'provider-key',
                ),
              );
            },
          ),
        ],
        today: today,
      );

      expect(results, hasLength(evalScenarios.length));
      for (final result in results) {
        final id = result.request.scenario.id;
        expect(result.error, isNull, reason: id);
        expect(result.outcome.planPersisted, isTrue, reason: id);
        expect(result.jobStatus, 'succeeded', reason: id);
        expect(
          result.outcome.rejections,
          isEmpty,
          reason: '$id rejected a block that satisfies its own contract',
        );
        expect(
          result.systemPrompt,
          isNotNull,
          reason: '$id produced no system prompt to judge',
        );
        expect(result.userPrompts, hasLength(1), reason: id);
      }
    });

    test('rejects a variant set with no control', () async {
      expect(
        () => runEvalMatrix(
          models: [scriptedTarget(turns: const [])],
          variants: const [
            EvalVariant(id: 'tighter', rationale: 'no control alongside it'),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains(evalBaselineVariantId),
          ),
        ),
      );
    });

    test('rejects a baseline that carries a transform', () async {
      // "An entry named baseline" is not a control. A baseline with a
      // transform makes every A/B a delta against something that was itself
      // changed — the check has to catch its own subject.
      expect(
        () => runEvalMatrix(
          models: [scriptedTarget(turns: const [])],
          variants: const [
            EvalVariant(
              id: evalBaselineVariantId,
              rationale: 'looks like a control, is not one',
              configure: _halfDay,
            ),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('no transform'),
          ),
        ),
      );
    });

    test('rejects two variants claiming to be the control', () async {
      expect(
        () => runEvalMatrix(
          models: [scriptedTarget(turns: const [])],
          variants: const [evalBaselineVariant, evalBaselineVariant],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects duplicate ids in any matrix dimension', () async {
      // Ids are report keys: the model id is the leaderboard row and `label`
      // is scenario/model/variant, so a duplicate silently merges two cells.
      final scenario = evalScenarios.first;
      expect(
        () => runEvalMatrix(
          models: [
            scriptedTarget(id: 'same', turns: const []),
            scriptedTarget(id: 'same', turns: const []),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('unique'),
          ),
        ),
      );
      expect(
        () => runEvalMatrix(
          models: [scriptedTarget(turns: const [])],
          scenarios: [scenario, scenario],
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => runEvalMatrix(
          models: [scriptedTarget(turns: const [])],
          variants: const [
            evalBaselineVariant,
            EvalVariant(id: 'dup', rationale: 'x'),
            EvalVariant(id: 'dup', rationale: 'x'),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a UTC anchor', () async {
      // localDay, the working-hours window and production's same-day guard are
      // all local, so reinterpreting a UTC anchor would plan a different day
      // than the caller asked for.
      expect(
        () => runEvalMatrix(
          models: [scriptedTarget(turns: const [])],
          today: DateTime.utc(2030, 1, 15),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('local DateTime'),
          ),
        ),
      );
    });

    test('rejects an empty matrix or a sample count below one', () async {
      expect(
        () => runEvalMatrix(models: const []),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => runEvalMatrix(
          models: [scriptedTarget(turns: const [])],
          scenarios: const [],
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => runEvalMatrix(
          models: [scriptedTarget(turns: const [])],
          samples: 0,
        ),
        throwsA(isA<RangeError>()),
      );
    });
  });

  group('runEvalCell', () {
    test('captures a rejection, its text, and the forced retry', () async {
      // A future-day scenario so the same-day guard is not what rejects this;
      // the block simply falls outside the plan's day, which the write path
      // rejects outright.
      final scenario = evalScenarios.firstWhere((s) => s.id == 'crowdedDay');
      final planDate = evalPlanDateFor(scenario, today);
      final result = await runEvalCell(
        request: requestFor(scenario),
        model: scriptedTarget(
          turns: [
            [
              draftCall(
                planDate: planDate,
                id: 'illegal-call',
                blocks: [
                  block(
                    start: planDate.add(const Duration(days: 2, hours: 10)),
                    duration: const Duration(hours: 1),
                    title: 'Block on the wrong day',
                  ),
                ],
              ),
            ],
            [draftCall(planDate: planDate, blocks: legalBlocks(planDate))],
          ],
        ),
      );

      expect(result.error, isNull);
      expect(result.outcome.planPersisted, isTrue);
      expect(
        result.outcome.blocks.single.title,
        'Focus block',
        reason: 'Only the corrected block may survive.',
      );

      final rejections = result.outcome.rejections.toList();
      expect(rejections, hasLength(1));
      expect(rejections.single.name, DayAgentToolNames.draftDayPlan);
      expect(
        rejections.single.rejectionMessage,
        isNotEmpty,
        reason:
            'The failure text handed back to the model is the whole signal — '
            'without it the retry is invisible.',
      );
      expect(
        result.outcome.toolCalls.map((c) => c.accepted),
        [false, true],
        reason: 'Order matters: the illegal attempt came first.',
      );
      expect(
        result.forcedDraftRetry,
        isTrue,
        reason: 'The second send is the workflow forcing the artifact.',
      );

      final complied = result.constraints.firstWhere(
        (c) => c.id == EvalConstraintIds.compliedWithoutRejection,
      );
      expect(complied.passed, isFalse);
      expect(complied.detail, contains('1 rejection'));
    });

    test('scores a clean run and reports the job as succeeded', () async {
      final scenario = evalScenarios.firstWhere((s) => s.id == 'crowdedDay');
      final planDate = evalPlanDateFor(scenario, today);
      final result = await runEvalCell(
        request: requestFor(scenario),
        model: scriptedTarget(
          turns: [
            [
              draftCall(
                planDate: planDate,
                blocks: legalBlocks(
                  planDate,
                  taskId: 'task-overdue-invoice',
                ),
              ),
            ],
          ],
        ),
      );

      expect(result.error, isNull);
      expect(result.jobStatus, 'succeeded');
      expect(
        result.jobAttempts,
        0,
        reason:
            'The counter records attempts that were charged for a failure; a '
            'first-time-right job never increments it.',
      );
      expect(result.forcedDraftRetry, isFalse);
      expect(
        result.constraints
            .firstWhere(
              (c) => c.id == EvalConstraintIds.compliedWithoutRejection,
            )
            .passed,
        isTrue,
      );
      expect(
        result.constraints
            .firstWhere(
              (c) => c.id == EvalConstraintIds.noFabricatedTaskIds,
            )
            .passed,
        isTrue,
        reason: 'The placed id is in the scenario corpus.',
      );
      expect(
        result.constraints
            .firstWhere(
              (c) => c.id == EvalConstraintIds.requiredWorkPlaced,
            )
            .passed,
        isFalse,
        reason: 'Two of the three required tasks were never placed.',
      );
    });

    test('records an unreachable model instead of aborting the cell', () async {
      // The live shape of this is a bad model id or missing credentials. One
      // cell must not cost the whole matrix.
      final scenario = evalScenarios.firstWhere((s) => s.id == 'crowdedDay');
      final result = await runEvalCell(
        request: requestFor(scenario),
        model: EvalModelTarget(
          id: 'unreachable',
          open: (_) async => throw StateError('no credentials'),
        ),
      );

      expect(result.error, contains('no credentials'));
      expect(result.failed, isTrue);
      expect(result.outcome.planPersisted, isFalse);
      expect(result.jobStatus, isNull);
      expect(
        result.constraints
            .firstWhere((c) => c.id == EvalConstraintIds.noOverlappingBlocks)
            .isApplicable,
        isFalse,
        reason: 'A run with no plan proves nothing about plan quality.',
      );
      expect(
        result.constraints.map((c) => c.id),
        containsAll(EvalConstraintIds.all),
        reason: 'A failed cell still occupies its slot in the report.',
      );
    });

    test(
      'sends the variant config to the model and scores against it',
      () async {
        final scenario = evalScenarios.firstWhere((s) => s.id == 'crowdedDay');
        final planDate = evalPlanDateFor(scenario, today);
        final repositories = <ScriptedConversationRepository>[];
        const variant = EvalVariant(
          id: 'halfDay',
          rationale: 'Does a tighter contract actually reach the model?',
          configure: _halfDay,
        );

        final result = await runEvalCell(
          request: requestFor(scenario, variant: variant),
          model: scriptedTarget(
            recordInto: repositories,
            turns: [
              [draftCall(planDate: planDate, blocks: legalBlocks(planDate))],
            ],
          ),
        );

        expect(
          result.systemPrompt,
          contains('"capacityMinutes": 240'),
          reason:
              'A variant that never reaches the prompt is inert — this is the '
              'assertion that would catch it.',
        );
        expect(repositories.single.lastSystemMessage, result.systemPrompt);
        expect(
          result.outcome.inputs.capacityMinutes,
          240,
          reason: 'Scoring must use the contract the model was handed.',
        );
        expect(result.outcome.inputs.workingHoursEndHour, 13);
      },
    );

    test(
      'passes the ADR 0043 blocked-work data through to the prompt',
      () async {
        final scenario = evalScenarios.firstWhere(
          (s) => s.id == 'blockedChain',
        );
        final planDate = evalPlanDateFor(scenario, today);
        final result = await runEvalCell(
          request: requestFor(scenario),
          model: scriptedTarget(
            turns: [
              [
                draftCall(
                  planDate: planDate,
                  blocks: legalBlocks(planDate, taskId: 'task-a-root'),
                ),
              ],
            ],
          ),
        );

        expect(
          result.userPrompts.single,
          contains('task-a-root'),
          reason:
              'The corpus must reach the model for the chain to be planned.',
        );
        expect(
          result.userPrompts.single,
          contains('blockedBy'),
          reason:
              'The resolver is what emits the blockedBy annotation; without it '
              'the blocked scenarios measure nothing.',
        );
        expect(
          result.constraints
              .firstWhere((c) => c.id == EvalConstraintIds.requiredWorkPlaced)
              .passed,
          isTrue,
        );
      },
    );

    test('renders the seeded directive into the prompt', () async {
      // The directive is seeded as a real entity and read back through
      // `directiveForDay`, so this asserts the whole path — a scenario whose
      // directive never reached the prompt would score the contract against a
      // model that was never given it.
      final scenario = evalScenarios.firstWhere(
        (s) => s.id == 'bindingDirective',
      );
      final planDate = evalPlanDateFor(scenario, today);
      final result = await runEvalCell(
        request: requestFor(scenario),
        model: scriptedTarget(
          turns: [
            [draftCall(planDate: planDate, blocks: legalBlocks(planDate))],
          ],
        ),
      );

      expect(result.userPrompts.single, contains('<day_directive>'));
      expect(result.userPrompts.single, contains('commit-board-deck'));
      expect(
        result.userPrompts.single,
        contains('Prepare the board deck'),
        reason: 'the commitment title is what a plan block has to name',
      );
      expect(
        result.constraints
            .firstWhere((c) => c.id == EvalConstraintIds.directiveHonoured)
            .passed,
        isFalse,
        reason:
            'the scripted plan names no commitment, so all three were '
            'silently dropped',
      );
    });

    test(
      'drafts a same-day scenario under a clock anchored to its start hour',
      () async {
        final scenario = evalScenarios.firstWhere((s) => s.id == 'lateStart');
        final planDate = evalPlanDateFor(scenario, today);
        expect(planDate, today, reason: 'A same-day scenario plans for today.');

        final result = await runEvalCell(
          request: requestFor(scenario),
          model: scriptedTarget(
            turns: [
              [
                draftCall(
                  planDate: planDate,
                  blocks: [
                    // 08:00 is before the anchored 15:00 clock, so production's
                    // same-day guard must reject it.
                    block(
                      start: planDate.add(const Duration(hours: 8)),
                      duration: const Duration(minutes: 30),
                      title: 'In the past',
                    ),
                  ],
                ),
              ],
              [
                draftCall(
                  planDate: planDate,
                  blocks: [
                    block(
                      start: planDate.add(const Duration(hours: 16)),
                      duration: const Duration(minutes: 30),
                      taskId: 'task-short-invoice',
                    ),
                  ],
                ),
              ],
            ],
          ),
        );

        expect(
          result.outcome.rejections.single.rejectionMessage,
          isNotNull,
          reason:
              'Without the clock anchor the guard is inert and the scenario '
              'silently stops testing a late start.',
        );
        expect(
          result.outcome.inputs.now,
          planDate.add(const Duration(hours: 15)),
        );
        expect(result.outcome.blocks.single.title, 'Focus block');
      },
    );

    test(
      'attributes consumption events to the run that produced them',
      () async {
        final scenario = evalScenarios.firstWhere((s) => s.id == 'crowdedDay');
        final planDate = evalPlanDateFor(scenario, today);
        var opened = 0;
        final model = scriptedTarget(
          onOpen: () {
            opened++;
            if (opened == 1) {
              attribution.service.recordInteraction(
                attributionId: 'attr-1',
                event: makeConsumptionEvent(id: 'evt-run-1'),
              );
            }
          },
          turns: [
            [draftCall(planDate: planDate, blocks: legalBlocks(planDate))],
          ],
        );

        final first = await runEvalCell(
          request: requestFor(scenario),
          model: model,
          attribution: attribution,
        );
        final second = await runEvalCell(
          request: requestFor(scenario),
          model: model,
          attribution: attribution,
        );

        expect(first.consumption.map((e) => e.id), ['evt-run-1']);
        expect(
          second.consumption,
          isEmpty,
          reason: "Run 1's usage must not be billed to run 2.",
        );
      },
    );

    test('refuses a scenario that claims a capture it cannot supply', () {
      const broken = EvalScenario(
        id: 'broken',
        intent: 'includeCapture with nothing to submit',
        tasks: [],
      );

      expect(
        () => runEvalCell(
          request: requestFor(broken),
          model: scriptedTarget(turns: const []),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('captureTranscript'),
          ),
        ),
      );
    });
  });

  group('resource release', () {
    test('releases the model layer after a run', () async {
      // The harness holds a running runtime, a database and a temp directory,
      // and the layer may hold a provider connection. A matrix keeps going
      // after a failure, so anything left open accumulates across cells.
      final scenario = evalScenarios.firstWhere((s) => s.id == 'crowdedDay');
      final planDate = evalPlanDateFor(scenario, today);
      var closed = 0;
      await runEvalCell(
        request: requestFor(scenario),
        model: scriptedTarget(
          turns: [
            [draftCall(planDate: planDate, blocks: legalBlocks(planDate))],
          ],
          onClose: () async => closed++,
        ),
      );

      expect(closed, 1);
    });

    test('a failing release does not cost the cell its result', () async {
      // Teardown noise must not be reported as a model result, and one
      // resource failing to release must not strand the others.
      final scenario = evalScenarios.firstWhere((s) => s.id == 'crowdedDay');
      final planDate = evalPlanDateFor(scenario, today);
      final result = await runEvalCell(
        request: requestFor(scenario),
        model: scriptedTarget(
          turns: [
            [draftCall(planDate: planDate, blocks: legalBlocks(planDate))],
          ],
          onClose: () async => throw StateError('close blew up'),
        ),
      );

      expect(result.error, isNull);
      expect(result.outcome.planPersisted, isTrue);
      expect(result.jobStatus, 'succeeded');
    });
  });

  group('EvalPromptRecorder', () {
    final inferenceRepo = CloudInferenceWrapper(
      cloudRepository: MockCloudInferenceRepository(),
    );

    test('keeps one transcript per conversation', () async {
      final inner = ScriptedConversationRepository();
      final recorder = EvalPromptRecorder(inner);
      final first = recorder.createConversation(systemMessage: 'system A');
      await recorder.sendMessage(
        conversationId: first,
        message: 'user A1',
        model: 'm',
        provider: testInferenceProvider(id: 'p', apiKey: 'k'),
        inferenceRepo: inferenceRepo,
      );
      final second = recorder.createConversation(systemMessage: 'system B');
      await recorder.sendMessage(
        conversationId: second,
        message: 'user B1',
        model: 'm',
        provider: testInferenceProvider(id: 'p', apiKey: 'k'),
        inferenceRepo: inferenceRepo,
      );

      expect(recorder.wakes.map((w) => w.systemPrompt), [
        'system A',
        'system B',
      ]);
      expect(recorder.wakes.map((w) => w.userMessages), [
        ['user A1'],
        ['user B1'],
      ]);
      expect(
        recorder.wakes.every((w) => !w.forcedRetry),
        isTrue,
        reason:
            'Two conversations with one message each is the durable job '
            'retrying, not the model being forced to call the tool.',
      );
    });

    test('a second message in one conversation is a forced retry', () async {
      final inner = ScriptedConversationRepository();
      final recorder = EvalPromptRecorder(inner);
      final id = recorder.createConversation(systemMessage: 'system');
      for (final message in ['first ask', 'forced follow-up']) {
        await recorder.sendMessage(
          conversationId: id,
          message: message,
          model: 'm',
          provider: testInferenceProvider(id: 'p', apiKey: 'k'),
          inferenceRepo: inferenceRepo,
        );
      }

      expect(recorder.wakes.single.forcedRetry, isTrue);
      expect(recorder.wakes.single.userMessages, [
        'first ask',
        'forced follow-up',
      ]);
    });
  });

  group('evalPlanDateFor', () {
    test('plans today for a same-day scenario and tomorrow otherwise', () {
      const sameDay = EvalScenario(
        id: 'same',
        intent: 'x',
        tasks: [],
        startHour: 15,
      );
      const futureDay = EvalScenario(id: 'future', intent: 'x', tasks: []);

      expect(
        evalPlanDateFor(sameDay, DateTime(2030, 1, 15, 23, 30)),
        DateTime(2030, 1, 15),
      );
      expect(
        evalPlanDateFor(futureDay, DateTime(2030, 1, 15, 23, 30)),
        DateTime(2030, 1, 16),
      );
    });

    test('advances by civil date, not by twenty-four hours', () {
      // On a DST boundary a fixed day-long duration lands at 23:00 the same
      // date or 01:00 the next, which would hand the cell the wrong day id and
      // shift every block time by an hour. Month and year ends are the same
      // normalisation question.
      const futureDay = EvalScenario(id: 'future', intent: 'x', tasks: []);

      expect(
        evalPlanDateFor(futureDay, DateTime(2030, 1, 31)),
        // ignore: avoid_redundant_argument_values — the whole date is the point
        DateTime(2030, 2, 1),
      );
      expect(
        evalPlanDateFor(futureDay, DateTime(2030, 12, 31)),
        // ignore: avoid_redundant_argument_values — the whole date is the point
        DateTime(2031, 1, 1),
      );
      for (final anchor in [
        DateTime(2026, 3, 29, 12),
        DateTime(2026, 10, 25, 12),
      ]) {
        final planDate = evalPlanDateFor(futureDay, anchor);
        expect(planDate.hour, 0, reason: anchor.toIso8601String());
        expect(
          planDate.day,
          isNot(anchor.day),
          reason: anchor.toIso8601String(),
        );
      }
    });
  });

  group('evalToolCallsFrom', () {
    AgentMessagePayloadEntity payload(
      String id,
      Map<String, dynamic> content,
    ) =>
        AgentDomainEntity.agentMessagePayload(
              id: id,
              agentId: 'agent-1',
              createdAt: today,
              vectorClock: null,
              content: content,
            )
            as AgentMessagePayloadEntity;

    AgentMessageEntity message({
      required String id,
      required AgentMessageKind kind,
      String? toolName,
      String? errorMessage,
      String? contentEntryId,
    }) =>
        AgentDomainEntity.agentMessage(
              id: id,
              agentId: 'agent-1',
              threadId: 'thread-1',
              kind: kind,
              createdAt: today,
              vectorClock: null,
              contentEntryId: contentEntryId,
              metadata: AgentMessageMetadata(
                runKey: 'run-1',
                toolName: toolName,
                errorMessage: errorMessage,
              ),
            )
            as AgentMessageEntity;

    test('pairs each action with its result and keeps the arguments', () {
      final calls = evalToolCallsFrom([
        payload('payload-1', {'dayId': 'dayplan-2030-01-16'}),
        message(
          id: 'msg-1',
          kind: AgentMessageKind.action,
          toolName: DayAgentToolNames.draftDayPlan,
          contentEntryId: 'payload-1',
        ),
        message(
          id: 'msg-2',
          kind: AgentMessageKind.toolResult,
          toolName: DayAgentToolNames.draftDayPlan,
          errorMessage: 'blocks must stay within the day',
        ),
      ]);

      expect(calls, hasLength(1));
      expect(calls.single.accepted, isFalse);
      expect(calls.single.rejectionMessage, 'blocks must stay within the day');
      expect(calls.single.arguments['dayId'], 'dayplan-2030-01-16');
    });

    test('ignores messages that are not tool traffic', () {
      final calls = evalToolCallsFrom([
        message(id: 'msg-1', kind: AgentMessageKind.thought),
        message(id: 'msg-2', kind: AgentMessageKind.user),
        message(id: 'msg-3', kind: AgentMessageKind.observation),
        message(id: 'msg-4', kind: AgentMessageKind.summary),
        message(id: 'msg-5', kind: AgentMessageKind.system),
      ]);

      expect(calls, isEmpty);
    });

    test(
      'does not attach the previous call arguments to an unpaired result',
      () {
        // A tool call whose arguments fail to parse records a result with no
        // action at all. Pairing blindly would credit it with the last call's
        // arguments and make the log lie about what was sent.
        final calls = evalToolCallsFrom([
          payload('payload-1', {'dayId': 'dayplan-2030-01-16'}),
          message(
            id: 'msg-1',
            kind: AgentMessageKind.action,
            toolName: DayAgentToolNames.draftDayPlan,
            contentEntryId: 'payload-1',
          ),
          message(
            id: 'msg-2',
            kind: AgentMessageKind.toolResult,
            toolName: DayAgentToolNames.draftDayPlan,
          ),
          message(
            id: 'msg-3',
            kind: AgentMessageKind.toolResult,
            toolName: DayAgentToolNames.recordObservations,
            errorMessage: 'Error: invalid arguments format',
          ),
        ]);

        expect(calls, hasLength(2));
        expect(calls.first.arguments, isNotEmpty);
        expect(calls.last.arguments, isEmpty);
        expect(calls.last.accepted, isFalse);
      },
    );

    test('reports an action that never got a result as unaccepted', () {
      final calls = evalToolCallsFrom([
        payload('payload-1', {'dayId': 'dayplan-2030-01-16'}),
        message(
          id: 'msg-1',
          kind: AgentMessageKind.action,
          toolName: DayAgentToolNames.draftDayPlan,
          contentEntryId: 'payload-1',
        ),
      ]);

      expect(calls, hasLength(1));
      expect(calls.single.accepted, isFalse);
      expect(calls.single.rejectionMessage, 'no tool result was recorded');
      expect(calls.single.arguments['dayId'], 'dayplan-2030-01-16');
    });

    test('flushes an orphaned action when the next result is another tool', () {
      final calls = evalToolCallsFrom([
        payload('payload-1', {'dayId': 'dayplan-2030-01-16'}),
        message(
          id: 'msg-1',
          kind: AgentMessageKind.action,
          toolName: DayAgentToolNames.draftDayPlan,
          contentEntryId: 'payload-1',
        ),
        message(
          id: 'msg-2',
          kind: AgentMessageKind.action,
          toolName: DayAgentToolNames.raiseDayStatus,
        ),
        message(
          id: 'msg-3',
          kind: AgentMessageKind.toolResult,
          toolName: DayAgentToolNames.raiseDayStatus,
        ),
      ]);

      expect(calls.map((c) => c.name), [
        DayAgentToolNames.draftDayPlan,
        DayAgentToolNames.raiseDayStatus,
      ]);
      expect(calls.first.accepted, isFalse);
      expect(calls.last.accepted, isTrue);
    });
  });

  group('the eval journal', () {
    test('a task created mid-run becomes findable, as it is in the app', () {
      // DayAgentPlanWriter resolves allowed task references through
      // journalEntityMapForIds, so a created task that is not stored makes the
      // pipeline reject a placement the app would accept — handing the model
      // an id and then denying it exists.
      final scenario = evalScenarios.firstWhere((s) => s.id == 'crowdedDay');
      final journalDb = MockJournalDb();
      seedScenarioCorpus(
        journalDb: journalDb,
        scenario: scenario,
        planDate: evalPlanDateFor(scenario, today),
      );

      expect(currentEvalJournal.byId('task-overdue-invoice'), isNotNull);
      expect(currentEvalJournal.byId('task-made-later'), isNull);

      currentEvalJournal.add(
        Task(
          meta: Metadata(
            id: 'task-made-later',
            createdAt: today,
            updatedAt: today,
            dateFrom: today,
            dateTo: today,
          ),
          data: TaskData(
            status: TaskStatus.open(id: 's', createdAt: today, utcOffset: 0),
            dateFrom: today,
            dateTo: today,
            statusHistory: const [],
            title: 'Made later',
          ),
          entryText: const EntryText(plainText: 'Made later'),
        ),
      );

      final resolved = currentEvalJournal.mapForIds([
        'task-overdue-invoice',
        'task-made-later',
        'task-never-existed',
      ]);

      expect(resolved.keys, ['task-overdue-invoice', 'task-made-later']);
      expect(resolved['task-made-later']?.id, 'task-made-later');
      expect(
        (resolved['task-overdue-invoice']! as Task).data.title,
        'Send the overdue client invoice',
      );
      expect(
        resolved.containsKey('task-never-existed'),
        isFalse,
        reason:
            'an id with nothing behind it must be absent — DayAgentPlanWriter '
            'reads presence in this map as permission to schedule the task',
      );
    });

    test('an update mutates the store instead of only reporting success', () {
      // apply_triage updates a task through this. A stub that answers true
      // without changing anything leaves the model reading stale state after
      // its own write — the harness agreeing out loud and doing nothing.
      final scenario = evalScenarios.firstWhere((s) => s.id == 'crowdedDay');
      final journalDb = MockJournalDb();
      final journalRepository = MockJournalRepository();
      seedScenarioCorpus(
        journalDb: journalDb,
        scenario: scenario,
        planDate: evalPlanDateFor(scenario, today),
        journalRepository: journalRepository,
      );

      final original = currentEvalJournal.byId('task-overdue-invoice')! as Task;
      final renamed = original.copyWith(
        data: original.data.copyWith(title: 'Renamed by triage'),
      );

      expect(
        journalRepository.updateJournalEntity(renamed),
        completion(isTrue),
      );
      expect(
        (currentEvalJournal.byId('task-overdue-invoice')! as Task).data.title,
        'Renamed by triage',
      );
    });

    test('corpus reads reflect a task the run updated', () {
      // A model that runs apply_triage and then rechecks pending work must see
      // what it just changed. Rebuilding the lists from the scenario would
      // show a task it marked in-progress as untouched, and every later
      // decision would rest on state the tool said it had changed.
      final scenario = evalScenarios.firstWhere((s) => s.id == 'crowdedDay');
      final journalDb = MockJournalDb();
      seedScenarioCorpus(
        journalDb: journalDb,
        scenario: scenario,
        planDate: evalPlanDateFor(scenario, today),
      );

      expect(
        journalDb.getInProgressTasks(),
        completion(hasLength(1)),
        reason: 'the fixture seeds exactly one in-progress task',
      );

      final invoice = currentEvalJournal.byId('task-overdue-invoice')! as Task;
      currentEvalJournal.add(
        invoice.copyWith(
          data: invoice.data.copyWith(
            status: TaskStatus.inProgress(
              id: 'moved',
              createdAt: today,
              utcOffset: 0,
            ),
          ),
        ),
      );

      expect(journalDb.getInProgressTasks(), completion(hasLength(2)));
    });

    test('a created task counts even with no capture item behind it', () {
      // create_task_from_phrase only writes a ParsedItemEntity when the model
      // passes the optional captureItemId. Reconstructing created ids from
      // parsed items alone would report legitimate work as fabricated.
      final scenario = evalScenarios.firstWhere((s) => s.id == 'crowdedDay');
      seedScenarioCorpus(
        journalDb: MockJournalDb(),
        scenario: scenario,
        planDate: evalPlanDateFor(scenario, today),
      );

      expect(currentEvalJournal.createdIds, isEmpty);
      currentEvalJournal.addCreated(
        Task(
          meta: Metadata(
            id: 'task-made-no-capture',
            createdAt: today,
            updatedAt: today,
            dateFrom: today,
            dateTo: today,
          ),
          data: TaskData(
            status: TaskStatus.open(id: 's', createdAt: today, utcOffset: 0),
            dateFrom: today,
            dateTo: today,
            statusHistory: const [],
            title: 'Made without a capture item',
          ),
          entryText: const EntryText(plainText: 'x'),
        ),
      );

      expect(currentEvalJournal.createdIds, {'task-made-no-capture'});
      expect(currentEvalJournal.byId('task-made-no-capture'), isNotNull);
    });

    test('seeding a cell forgets the previous cell tasks', () {
      final scenario = evalScenarios.firstWhere((s) => s.id == 'crowdedDay');
      final other = evalScenarios.firstWhere((s) => s.id == 'lateStart');
      final journalDb = MockJournalDb();
      seedScenarioCorpus(
        journalDb: journalDb,
        scenario: scenario,
        planDate: evalPlanDateFor(scenario, today),
      );
      seedScenarioCorpus(
        journalDb: journalDb,
        scenario: other,
        planDate: evalPlanDateFor(other, today),
      );

      expect(
        currentEvalJournal.byId('task-overdue-invoice'),
        isNull,
        reason: 'a cell must not see the previous cell task corpus',
      );
      expect(currentEvalJournal.byId('task-long-migration'), isNotNull);
      expect(
        currentEvalJournal.createdIds,
        isEmpty,
        reason: 'created ids must not leak into the next cell either',
      );
    });
  });

  group('evalCreatedTaskIdsFrom', () {
    test('recovers ids from the parsed items a create tool wrote', () {
      // The created id is only in the tool-result payload, which the agent log
      // does not persist — but `create_task_from_phrase` stamps it onto the
      // parsed item as matchedTaskId, so it is recoverable from real state.
      AgentDomainEntity parsed({
        required String id,
        required ParsedItemKind kind,
        required String title,
        String? matchedTaskId,
      }) => AgentDomainEntity.parsedItem(
        id: id,
        agentId: 'agent-1',
        captureId: 'capture-1',
        kind: kind,
        title: title,
        categoryId: evalDefaultCategoryId,
        confidence: ParsedItemConfidence.high,
        confidenceScore: 0.9,
        createdAt: today,
        vectorClock: null,
        matchedTaskId: matchedTaskId,
      );

      final ids = evalCreatedTaskIdsFrom([
        parsed(
          id: 'parsed-1',
          kind: ParsedItemKind.matched,
          title: 'Book the venue',
          matchedTaskId: 'task-created',
        ),
        parsed(
          id: 'parsed-2',
          kind: ParsedItemKind.newTask,
          title: 'Something unmatched',
        ),
      ]);

      expect(ids, {'task-created'});
    });

    test('is empty when nothing was parsed', () {
      expect(evalCreatedTaskIdsFrom(const []), isEmpty);
    });
  });

  group('evalConfigFor', () {
    test('applies the variant on top of the scenario contract', () {
      final scenario = evalScenarios.firstWhere((s) => s.id == 'crowdedDay');

      expect(
        evalConfigFor(scenario, evalBaselineVariant).capacityMinutes,
        scenario.capacityMinutes,
      );
      expect(
        evalConfigFor(
          scenario,
          const EvalVariant(id: 'x', rationale: 'x', configure: _halfDay),
        ).capacityMinutes,
        240,
      );
    });
  });
}

/// A tighter contract: half the capacity, mornings only.
DayAgentConfig _halfDay(DayAgentConfig base) => DayAgentConfig(
  capacityMinutes: base.capacityMinutes ~/ 2,
  workingHoursStart: base.workingHoursStart,
  workingHoursEnd: '13:00',
  energyBands: base.energyBands,
  maxRefinementRounds: base.maxRefinementRounds,
);
