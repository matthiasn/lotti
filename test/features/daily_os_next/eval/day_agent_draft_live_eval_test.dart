@Tags(['eval-live'])
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/time_service.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../ai_consumption/test_utils.dart';
import '../integration/day_agent_pipeline_harness.dart';

/// Live end-to-end eval of the ADR 0032 durable drafting pipeline against a
/// real inference provider — the same chain the "Drafting your day" UI path
/// runs (outbox → runtime → executor → orchestrator → workflow → real
/// [ConversationRepository]/[CloudInferenceRepository] → plan writer),
/// drafting **today's** plan with the real clock. That deliberately
/// exercises the same-day "blocks must not start before current time"
/// guard against a real model, which is the suspected trigger of the
/// stuck-drafting hang observed live.
///
/// Wall-clock time and real `clock.now()` are intentional here (exempt from
/// the fake-time policy in `test/README.md`): the interaction between the
/// real current time and the model's proposed block times is the thing
/// under test.
///
/// Run with:
/// ```bash
/// set -a; source .env; set +a   # provides MELIOUS_API_KEY / MELIOUS_BASE_URL
/// LOTTI_DAY_AGENT_DRAFT_EVAL_LIVE=1 fvm flutter test \
///   test/features/daily_os_next/eval/day_agent_draft_live_eval_test.dart
/// ```
/// Override the model list via `DAY_AGENT_DRAFT_EVAL_MODELS` (comma-separated
/// Melious model ids).
void main() {
  setUpAll(registerAllFallbackValues);

  final live = Platform.environment['LOTTI_DAY_AGENT_DRAFT_EVAL_LIVE'] == '1';
  final modelIds =
      (Platform.environment['DAY_AGENT_DRAFT_EVAL_MODELS'] ??
              'qwen3.5-397b-a17b,glm-5.2')
          .split(',')
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toList();

  for (final modelId in modelIds) {
    test(
      "drafts today's plan through the durable pipeline against $modelId",
      () async {
        final attribution = AiInteractionCaptureTestBench.create();
        await setUpTestGetIt(
          additionalSetup: () {
            getIt
              ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
              ..registerSingleton<TimeService>(TimeService());
            attribution.register();
          },
        );
        addTearDown(tearDownTestGetIt);
        // The test binding installs a mock HttpOverrides whose client
        // instantly fails every request with HTTP 400 — clear it so the
        // eval can reach the real provider.
        HttpOverrides.global = null;

        final container = ProviderContainer();
        addTearDown(container.dispose);
        final conversationSubscription = container.listen(
          conversationRepositoryProvider,
          (_, _) {},
        );
        addTearDown(conversationSubscription.close);
        final cloudRepositorySubscription = container.listen(
          cloudInferenceRepositoryProvider,
          (_, _) {},
        );
        addTearDown(cloudRepositorySubscription.close);

        final apiKey = Platform.environment['MELIOUS_API_KEY'];
        if (apiKey == null || apiKey.isEmpty) {
          fail(
            'MELIOUS_API_KEY is not set — source .env before running the '
            'live day-agent draft eval.',
          );
        }
        final provider =
            AiConfig.inferenceProvider(
                  id: 'provider-day-eval',
                  name: 'Melious (day-agent draft eval)',
                  baseUrl:
                      Platform.environment['MELIOUS_BASE_URL'] ??
                      ProviderConfig.defaultBaseUrls[InferenceProviderType
                          .melious]!,
                  apiKey: apiKey,
                  inferenceProviderType: InferenceProviderType.melious,
                  createdAt: DateTime(2026, 7, 22),
                )
                as AiConfigInferenceProvider;
        final model =
            AiConfig.model(
                  id: 'model-day-eval',
                  name: 'Day-agent draft eval model',
                  providerModelId: modelId,
                  inferenceProviderId: provider.id,
                  createdAt: DateTime(2026, 7, 22),
                  inputModalities: const [Modality.text],
                  outputModalities: const [Modality.text],
                  isReasoningModel: true,
                  supportsFunctionCalling: true,
                  description: 'Live model under day-agent draft eval.',
                )
                as AiConfigModel;
        final profile = AiConfigInferenceProfile(
          id: 'profile-day-eval',
          name: 'Day-agent draft eval',
          thinkingModelId: modelId,
          createdAt: DateTime(2026, 7, 22),
        );

        // Real clock on purpose: today's date + the actual current time is
        // the exact live scenario that hung.
        final startedAt = clock.now();
        final dayDate = DateTime(
          startedAt.year,
          startedAt.month,
          startedAt.day,
        );
        final dayId = dayAgentIdForDate(dayDate);

        final harness = DayAgentPipelineHarness.create(
          now: startedAt,
          conversationRepository: container.read(
            conversationRepositoryProvider.notifier,
          ),
          cloudInferenceRepository: container.read(
            cloudInferenceRepositoryProvider,
          ),
          profile: profile,
          model: model,
          provider: provider,
          logToStdout: true,
        );
        addTearDown(harness.dispose);

        debugPrint(
          'day-agent draft eval: model=$modelId dayDate=$dayDate '
          'startedAt=$startedAt',
        );
        final stopwatch = Stopwatch()..start();
        final draft = await harness.realDayAgent.draftDayPlan(
          captureId: const CaptureId(''),
          decidedTaskIds: const [],
          dayDate: dayDate,
        );
        stopwatch.stop();

        final draftJob = await harness.outbox.getById(
          DayProcessingOutboxRepository.draftJobId(dayId),
        );
        debugPrint(
          'day-agent draft eval: model=$modelId '
          'latency=${stopwatch.elapsed} '
          'jobStatus=${draftJob?.status.name} '
          'attempts=${draftJob?.attempts} '
          'blocks=${[for (final block in draft.blocks) _formatBlock(block)]}',
        );

        expect(draft.state, DayState.drafted);
        expect(
          draft.blocks,
          isNotEmpty,
          reason: 'The model must place at least one block.',
        );
        // The same-day persist guard rejects *drafted AI/manual* blocks
        // starting before "now" (`parsePlannedBlock`); buffer/cal blocks and
        // non-drafted states are exempt by design. Assert exactly that
        // contract (small tolerance for the moment the guard sampled the
        // clock). Observed live: qwen3.5-397b-a17b labels a past-starting
        // block `buffer` and sails through the exemption.
        final earliestAllowed = startedAt.subtract(const Duration(minutes: 1));
        for (final block in draft.blocks) {
          final guarded =
              (block.type == TimeBlockType.ai ||
                  block.type == TimeBlockType.manual) &&
              block.state == TimeBlockState.drafted;
          if (!guarded) continue;
          expect(
            block.start.isBefore(earliestAllowed),
            isFalse,
            reason:
                'Drafted ${block.type.name} block "${block.title}" starts at '
                '${block.start}, before the draft began at $startedAt — the '
                'same-day guard should have rejected it.',
          );
        }
        expect(draftJob, isNotNull);
        expect(draftJob!.isTerminal, isTrue);
        expect(draftJob.status.name, 'succeeded');
      },
      skip: live
          ? null
          : 'Set LOTTI_DAY_AGENT_DRAFT_EVAL_LIVE=1 (plus MELIOUS_API_KEY / '
                'MELIOUS_BASE_URL) to run the live day-agent draft eval.',
      // Longer than RealDayAgent's 10-minute job-await soft cap so a hang
      // surfaces as the soft cap's DayAgentInteractionException (the real
      // diagnostic) rather than an opaque test timeout.
      timeout: const Timeout(Duration(minutes: 12)),
    );
  }
}

String _formatBlock(TimeBlock block) {
  String hhmm(DateTime t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
  return '${block.title} [${block.type.name}/${block.state.name}] '
      '${hhmm(block.start)}-${hhmm(block.end)}';
}
