import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/ai/ai_call_impact.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/ai_attribution.dart';
import 'package:lotti/classes/ai_consumption/ai_consumption_event.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/ai/helpers/entity_state_helper.dart';
import 'package:lotti/features/ai/helpers/prompt_builder_helper.dart';
import 'package:lotti/features/ai/helpers/skill_prompt_builder.dart';
import 'package:lotti/features/ai/model/image_generation_error.dart';
import 'package:lotti/features/ai/model/pull_request_context_source.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_consumption_mapping.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/completion_usage_parser.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/repository/task_summary_resolver.dart';
import 'package:lotti/features/ai/repository/tool_call_accumulator.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/skills/entry_summary_tool.dart';
import 'package:lotti/features/ai/skills/transcript_name_correction_tool.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/image_generation_error_controller.dart';
import 'package:lotti/features/ai/state/inference_error_controller.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/pull_request_context_source_provider.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_identity_resolver.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/transcript_term_corrector.dart';
import 'package:openai_dart/openai_dart.dart' hide Error;

part 'skill_inference_runner_internals.dart';
part 'skill_inference_runner_media_runs.dart';
part 'skill_inference_runner_text_runs.dart';
part 'skill_inference_runner_transcription.dart';

const _logTag = 'SkillInferenceRunner';

/// Shortest transcript worth summarizing, in characters.
///
/// Below this the collapsed card's existing transcript-prefix fallback is
/// already the whole content, so a summary would spend a model call to
/// restate it. Measured on the resolved entry content (an edit if there is
/// one, otherwise the latest transcript), not on the audio duration — a long
/// recording of silence is not worth summarizing either.
const _audioSummaryMinChars = 200;

/// Whether [SkillInferenceRunner.runAudioSummary] would summarize [audio]
/// rather than skip it for being too short.
///
/// Reads the same content the run reads, so a caller deciding whether to
/// offer a summary never offers one the run would decline.
bool hasSummarizableContent(JournalAudio audio) =>
    _resolveEntryContent(audio).length >= _audioSummaryMinChars;

/// How many times a transcript write that did not land is re-read and tried
/// before the run fails. A refusal means a version was stored between the
/// re-read and the write; the next re-read carries it.
const _transcriptSaveAttempts = 3;

/// One kind of run in flight on this device, at most one per entry.
///
/// A second request for an entry whose run is in flight joins that run
/// instead of starting another: it pays for no second inference, and gets
/// the first run's outcome. The registration happens synchronously, before the
/// run's first await, so two requests cannot both find the entry idle. The
/// runner is rebuilt whenever its provider's dependencies change, so each
/// registry lives in a provider of its own.
class EntryRuns {
  final _active = <String, Future<Object?>>{};

  /// Runs [execute] for [entryId], or returns the run already in flight for
  /// it. The result is the run's failure, or null when it succeeded.
  Future<Object?> run(
    String entryId,
    Future<Object?> Function() execute,
  ) => _active.putIfAbsent(
    entryId,
    () => Future<Object?>.microtask(execute).whenComplete(() {
      _active.remove(entryId);
    }),
  );
}

/// The transcriptions in flight, one per recording.
///
/// Every entry point — the automatic trigger, the AI popup and Retry, the
/// synced-audio dispatcher, the check-in service, an accepted backfill
/// suggestion — ends in [SkillInferenceRunner.runTranscription].
final transcriptionRunsProvider = Provider<EntryRuns>(
  (ref) => EntryRuns(),
  name: 'transcriptionRunsProvider',
);

/// The image analyses in flight, one per image.
///
/// The automatic trigger on import, the AI popup and an accepted backfill
/// suggestion all end in [SkillInferenceRunner.runImageAnalysis]; none of
/// them can tell for certain that another is already analysing the picture,
/// because each awaits before the run marks it running. Without this, two of
/// them overlapping called the vision model twice and stored two analyses.
final imageAnalysisRunsProvider = Provider<EntryRuns>(
  (ref) => EntryRuns(),
  name: 'imageAnalysisRunsProvider',
);

/// Service that invokes inference using skill-built prompts and
/// profile-resolved models, bypassing the legacy prompt system entirely.
///
/// Holds the four skill inference paths (transcription, image analysis,
/// prompt generation, image generation) plus the shared model/slot
/// resolution, status-tracking, and content-preparation helpers they depend
/// on. The public `run*` methods are real, mockable class members so
/// `MockSkillInferenceRunner` intercepts the public API.
class SkillInferenceRunner {
  const SkillInferenceRunner({
    required this._ref,
    required this._cloudRepository,
    required this._aiInputRepository,
    required this._journalRepository,
    required this._loggingService,
    required this._promptBuilderHelper,
    required this._taskSummaryResolver,
  });

  final Ref _ref;
  final CloudInferenceRepository _cloudRepository;
  final AiInputRepository _aiInputRepository;
  final JournalRepository _journalRepository;
  final DomainLogger _loggingService;
  final PromptBuilderHelper _promptBuilderHelper;
  final TaskSummaryResolver _taskSummaryResolver;

  /// Whether [skill] gets the task's pull requests: only the coding prompt.
  ///
  /// The design and research prompts share its skill type, but they are not
  /// about code, and the pull request block's guidance — treat that work as
  /// done, list checklist mismatches — would distort them. Every prompt skill
  /// is built in, so the coding prompt's id identifies it completely.
  static bool _carriesPullRequests(AiConfigSkill skill) =>
      skill.id == skillPromptGenId;

  /// The task's pull requests for a coding prompt, refreshed now, or null
  /// when there are none or nothing supplies them. A failure here never
  /// fails the prompt: it is logged, and the prompt goes out without the
  /// section.
  Future<String?> _pullRequestContext(String taskId) async {
    final source = _ref.read(pullRequestContextSourceProvider);
    if (source == null) return null;
    try {
      final text = await source.contextFor(
        taskId,
        audience: PullRequestContextAudience.codingPrompt,
      );
      return text.isEmpty ? null : text;
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.ai,
        error,
        stackTrace: stackTrace,
        subDomain: 'runPromptGeneration.pullRequests',
      );
      return null;
    }
  }

  /// Formats pre-fetched speech dictionary terms into a prompt fragment.
  static String _formatSpeechDictionaryText(List<String> terms) {
    if (terms.isEmpty) return '';

    String escapeForJson(String s) => s
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n');
    final termsJson = terms.map((t) => '"${escapeForJson(t)}"').join(', ');

    return 'IMPORTANT - SPEECH DICTIONARY (MUST USE):\n'
        'The following terms are domain-specific and MUST be spelled exactly '
        'as shown when they appear in the audio.\n'
        'Required spellings: [$termsJson]';
  }

  /// Run skill-based transcription on an audio entry.
  ///
  /// When [overrideModelId] is non-null and resolves to a valid
  /// `AiConfigModel`, the run uses that model and its parent provider
  /// instead of the profile's transcription slot. This is the
  /// per-invocation override path used by the popup-menu picker, so the
  /// user can route a single voice note to a different model without
  /// changing the entire profile. A stale or unresolvable override
  /// falls back to the profile slot (with a warning log) — stranding
  /// the user is worse than ignoring a stale id.
  /// [onError] receives the raw exception when the run fails.
  ///
  /// This method deliberately never throws — `_withStatusTracking` catches
  /// everything, logs it and reports it through
  /// [inferenceStatusControllerProvider] / [inferenceErrorControllerProvider],
  /// which is all a fire-and-forget caller needs. A caller that is *waiting*
  /// on the transcript needs more than that: a failed run writes no
  /// `entryText`, so silence is indistinguishable from a slow model and the
  /// caller sits on a spinner until its own timeout. [onError] is that
  /// signal, and it fires for the same failures the error controller shows —
  /// including a transcript the database would not save
  /// ([_saveTranscript]). A failed run starts no audio summary.
  ///
  /// One run per recording is in flight on a device ([EntryRuns]). A
  /// call for a recording already being transcribed joins that run: it pays
  /// for no second inference, sets no status of its own, and its [onError]
  /// fires with the run's failure. Its own [overrideModelId], [knownTerms]
  /// and [linkedTaskId] are not used.
  ///
  /// [knownTerms] are words the caller knows the recording is likely to
  /// contain — a person's name and the people around them. They lead the
  /// provider's vocabulary hint ahead of the category speech dictionary, and,
  /// because not every provider honours that hint, the finished transcript is
  /// also corrected against both lists with [correctTranscriptTerms]. The
  /// audio's transcript history keeps what the provider actually returned;
  /// only its text carries the correction. Without [knownTerms] the
  /// transcript is stored exactly as returned.
  Future<void> runTranscription({
    required String audioEntryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
    String? overrideModelId,
    GeminiThinkingMode? geminiThinkingMode,
    void Function(Object error)? onError,
    List<String> knownTerms = const [],
  }) async {
    final skill = automationResult.skill;
    final profile = automationResult.resolvedProfile;
    if (skill == null || profile == null) {
      throw StateError(
        'AutomationResult missing skill or profile for $audioEntryId: '
        'skill=${skill != null}, profile=${profile != null}',
      );
    }
    // One run per recording at a time: a request while one is in flight
    // joins it and gets its outcome, rather than paying for a second
    // inference that would append a second transcript and summary. The
    // model is resolved inside the run, so the request that registers first
    // is the one whose model is used, however long its lookup takes.
    final failure = await _ref.read(transcriptionRunsProvider).run(
      audioEntryId,
      () async {
        final target = await _resolveTranscriptionTarget(
          profile: profile,
          overrideModelId: overrideModelId,
        );
        final provider = target.provider;
        final modelId = target.modelId;
        if (provider == null || modelId == null) {
          _loggingService.log(
            LogDomain.ai,
            'Profile missing transcription provider/model for $audioEntryId',
            subDomain: _logTag,
            level: InsightLevel.warn,
          );
          return null;
        }
        return _transcribeAndSummarize(
          audioEntryId: audioEntryId,
          automationResult: automationResult,
          skill: skill,
          profile: profile,
          provider: provider,
          modelId: modelId,
          effectiveThinkingMode: _geminiThinkingModeForTarget(
            target,
            geminiThinkingMode,
          ),
          linkedTaskId: linkedTaskId,
          knownTerms: knownTerms,
        );
      },
    );
    if (failure != null) onError?.call(failure);
  }

  /// Run skill-based image analysis on an image entry.
  ///
  /// When [overrideModelId] is non-null and resolves to a valid
  /// `AiConfigModel`, the run uses that model and its parent provider
  /// instead of the profile's image-recognition slot. This is the
  /// per-invocation override path used by the popup-menu picker, so
  /// the user can route a single photo to a different model without
  /// changing the entire profile. A stale or unresolvable override
  /// falls back to the profile slot (with a warning log) — stranding
  /// the user is worse than ignoring a stale id.
  ///
  /// One analysis per image is in flight on a device
  /// ([imageAnalysisRunsProvider]). A call for an image already being
  /// analysed joins that run: it pays for no second inference and stores no
  /// second analysis. Its own [automationResult], [overrideModelId],
  /// [geminiThinkingMode] and [linkedTaskId] are not used.
  ///
  /// After the attributed path stores the analysis, every parent **task** of
  /// the image (all tasks linking to it, plus [linkedTaskId] when present —
  /// non-task parents are skipped) is marked dirty via the standard
  /// child-changed notification pairs, so each parent task's agent picks the
  /// new analysis up on its normal subscription wake.
  Future<void> runImageAnalysis({
    required String imageEntryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
    String? overrideModelId,
    GeminiThinkingMode? geminiThinkingMode,
  }) => _runImageAnalysis(
    imageEntryId: imageEntryId,
    automationResult: automationResult,
    linkedTaskId: linkedTaskId,
    overrideModelId: overrideModelId,
    geminiThinkingMode: geminiThinkingMode,
  );

  /// Run skill-based summarization of an audio recording's transcript.
  ///
  /// Produces a three-tier summary — one-liner, TLDR, full markdown — as an
  /// [AiResponseEntry] linked to the audio entry, mirroring how an image
  /// analysis hangs off its image. The one-liner is what the collapsed audio
  /// card shows in place of the raw transcript's first line.
  ///
  /// The summary is a **point-in-time snapshot**: the task context is built
  /// here, at run time, and frozen into the prompt. Re-running later against a
  /// changed task produces a different summary, and both are kept — readers
  /// take the newest.
  ///
  /// Runs on the profile's thinking slot (see [_resolveAudioSummaryTarget])
  /// and publishes through a pinned tool call, so the tiers arrive as typed
  /// arguments rather than prose anyone has to parse. A model that ends its
  /// turn without calling the tool gets exactly one forced retry before the
  /// run gives up.
  ///
  /// Returns silently without persisting anything when the transcript is
  /// shorter than [_audioSummaryMinChars] — a one-liner of a one-sentence note
  /// is pure cost, and the collapsed card's transcript-prefix fallback already
  /// reads fine at that length.
  Future<void> runAudioSummary({
    required String audioEntryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
    String? overrideModelId,
    GeminiThinkingMode? geminiThinkingMode,
  }) => _runAudioSummary(
    audioEntryId: audioEntryId,
    automationResult: automationResult,
    linkedTaskId: linkedTaskId,
    overrideModelId: overrideModelId,
    geminiThinkingMode: geminiThinkingMode,
  );

  /// Run skill-based prompt generation on a [JournalAudio] or [JournalEntry].
  ///
  /// Uses the profile's high-end thinking model (falling back to the regular
  /// thinking model) to transform the entry's content (audio transcript or
  /// typed text) plus task context into a detailed prompt. The result is
  /// saved as an [AiResponseEntry] linked to the source entry.
  /// When [referenceImages] is non-empty and the resolved target model still
  /// supports image input, they are forwarded with the text as a multimodal
  /// prompt-generation request.
  Future<void> runPromptGeneration({
    required String entryId,
    required AutomationResult automationResult,
    String? linkedTaskId,
    List<ProcessedReferenceImage>? referenceImages,
    String? overrideModelId,
    GeminiThinkingMode? geminiThinkingMode,
  }) => _runPromptGeneration(
    entryId: entryId,
    automationResult: automationResult,
    linkedTaskId: linkedTaskId,
    referenceImages: referenceImages,
    overrideModelId: overrideModelId,
    geminiThinkingMode: geminiThinkingMode,
  );

  /// Run skill-based image generation on a [JournalAudio] or [JournalEntry].
  ///
  /// Generates a cover art image using the task context, the entry's content
  /// (audio transcript or typed text), and optional reference images. The
  /// generated image is automatically imported as a [JournalImage] and set
  /// as the task's cover art.
  Future<void> runImageGeneration({
    required String entryId,
    required AutomationResult automationResult,
    required String linkedTaskId,
    List<ProcessedReferenceImage>? referenceImages,
    String? overrideModelId,
  }) => _runImageGeneration(
    entryId: entryId,
    automationResult: automationResult,
    linkedTaskId: linkedTaskId,
    referenceImages: referenceImages,
    overrideModelId: overrideModelId,
  );

  /// Sums the billable and environmental impact of two attempts at the same
  /// logical call.
  ///
  /// The counterpart to [_mergeUsage], and needed for the same reason: both
  /// provider calls really happened, so reporting only the retry's cost would
  /// understate spend. Only the additive quantities are summed. The
  /// descriptive fields (data centre, provider id, PUE, renewable share) are
  /// taken from whichever attempt reported them — both attempts hit the same
  /// provider and model, so they describe one place, not two.
  ///
  /// `costCreditsDecimal` is a provider-formatted string rather than a number.
  /// It is deliberately dropped once two attempts are merged: guessing at
  /// decimal arithmetic on someone else's formatting would report a precise
  /// figure that is not the provider's, and `costCredits` already carries the
  /// summed value.
  static MeliousCallImpact? _mergeImpact(
    MeliousCallImpact? a,
    MeliousCallImpact? b,
  ) => MeliousCallImpact.combine(a, b);

  /// Sums the token usage of two attempts at the same logical call.
  ///
  /// The audio-summary retry issues a second request, and both are real spend.
  /// Reporting only the second would understate the cost of a model that
  /// needed prompting twice — exactly the model whose cost the user most needs
  /// to see. Null operands pass through so a provider that reports usage on
  /// only one attempt still contributes what it did report.
  static CompletionUsage? _mergeUsage(CompletionUsage? a, CompletionUsage? b) =>
      combineCompletionUsage(a, b);

  /// Marks every parent task of [sourceEntryId] stale after an
  /// [AiResponseEntry] was linked beneath it.
  ///
  /// A response entry linked FROM its source only notifies the source and
  /// response ids — notification propagation is one hop, so the parent tasks
  /// never hear about it. This emits the same child-changed pairs
  /// `updateDbEntity` produces when the source entry itself is edited, for
  /// EVERY parent task rather than just the resolved [linkedTaskId]: one
  /// recording or image can be linked from several tasks, and each parent's
  /// agent needs its normal subscription wake (its cadence's coalescing,
  /// automatic-updates opt-in / stale-marking) to pick the new content up.
  /// With [imageAnalysis] set the batch also carries
  /// `imageAnalysisNotification`, which brings that wake to within a minute.
  ///
  /// Non-task parents are skipped — only task contexts render nested AI
  /// responses, so waking their agents would burn inference on content the
  /// user cannot see. [linkedTaskId] is unioned in because task resolution
  /// may have matched an outgoing entry→task link that the incoming-parents
  /// query does not cover.
  ///
  /// Never throws: the response is already persisted by the time this runs,
  /// so a failed parent lookup degrades to notifying the resolved task alone
  /// rather than failing the whole run.
  Future<void> _notifyParentTasksOfNestedResponse({
    required String sourceEntryId,
    required String subDomain,
    String? linkedTaskId,
    bool imageAnalysis = false,
  }) async {
    final staleIds = <String>{?linkedTaskId};
    try {
      final parents = await _journalRepository.getLinkedToEntities(
        linkedTo: sourceEntryId,
      );
      staleIds.addAll(
        parents.whereType<Task>().map((parent) => parent.meta.id),
      );
    } catch (e, stackTrace) {
      _loggingService.error(
        LogDomain.ai,
        e,
        stackTrace: stackTrace,
        subDomain: subDomain,
        message: 'parent lookup for stale notification failed',
      );
    }
    if (staleIds.isNotEmpty) {
      getIt<UpdateNotifications>().notify({
        for (final id in staleIds) ...{
          id,
          propagatedNotification(id),
          // Lets the task agent run within a minute instead of at its
          // cadence (see `AgentWakeCadence.respondsToImageAnalysis`).
          if (imageAnalysis) imageAnalysisNotification(id),
        },
      });
    }
  }

  /// Drains a chat-completion stream, concatenating content deltas, capturing
  /// the last reported [CompletionUsage] (providers emit usage on the final
  /// chunk), and reassembling any streamed tool calls. Shared by the
  /// transcription, image-analysis, prompt-generation and audio-summary paths
  /// so the accumulation logic lives in one place.
  ///
  /// Tool-call deltas arrive fragmented — a name in one chunk, its JSON
  /// arguments spread across many more, sometimes without ids — so they go
  /// through [ToolCallAccumulator] rather than being read off a single chunk.
  /// Paths that send no `tools` simply get an empty `toolCalls` list; the
  /// collector stays one method because a skill either reads structured
  /// output or does not, and both need identical content/usage handling.
  Future<
    ({
      String content,
      CompletionUsage? usage,
      List<ChatCompletionMessageToolCall> toolCalls,
    })
  >
  _collectStream(
    Stream<CreateChatCompletionStreamResponse> stream,
  ) async {
    final buffer = StringBuffer();
    final toolCallAccumulator = ToolCallAccumulator();
    CompletionUsage? usage;
    await for (final chunk in stream) {
      if (chunk.usage != null) usage = chunk.usage;
      final delta = chunk.choices?.firstOrNull?.delta;
      final content = delta?.content;
      if (content != null) {
        buffer.write(content);
      }
      toolCallAccumulator.processChunk(delta);
    }
    return (
      content: buffer.toString(),
      usage: usage,
      toolCalls: toolCallAccumulator.toToolCalls(),
    );
  }

  Future<AiAttributionSession?> _beginAttribution({
    required AiWorkType workType,
    required JournalEntity source,
    required AiArtifactReference output,
    required AiConfigSkill skill,
    required AutomationResult automationResult,
    required String? taskId,
  }) async {
    if (!getIt.isRegistered<AiAttributionService>() ||
        !getIt.isRegistered<AiAttributionIdentityResolver>()) {
      return null;
    }
    final identity = getIt<AiAttributionIdentityResolver>();
    final human = await identity.humanInitiator();
    final automatic = automationResult.skillAssignment?.automate ?? false;
    final actor = automatic
        ? AiActorSnapshot(
            type: AiActorType.automation,
            id: 'automation:${skill.id}',
            displayName: skill.name,
            humanPrincipalId: human.humanPrincipalId,
          )
        : human;
    return getIt<AiAttributionService>().begin(
      AiAttributionStart(
        workType: workType,
        initiator: actor,
        trigger: AiTriggerSnapshot(
          type: automatic ? AiTriggerType.automatic : AiTriggerType.manual,
          skillId: skill.id,
        ),
        intendedOutputs: [output],
        taskId: taskId,
        categoryId: source.meta.categoryId,
      ),
    );
  }

  /// Asks the profile's thinking model which names in [transcript] were
  /// misheard, against [terms], and applies the proposals a check in code
  /// accepts ([applyTranscriptNameCorrections]). Returns the corrected text
  /// and the call's consumption event, or null when the call fails — a
  /// failed correction leaves the transcript as the phonetic pass left it.
  Future<({String text, AiConsumptionEvent event})?>
  _correctNamesWithThinkingModel({
    required ResolvedProfile profile,
    required String transcript,
    required List<String> terms,
    required JournalAudio entity,
    required String? taskId,
    required String skillId,
  }) async {
    final provider = profile.thinkingProvider;
    final modelId = profile.thinkingModelId;
    final messages = transcriptNameCorrectionMessages(
      transcript: transcript,
      terms: terms,
    );
    final start = DateTime.now();
    try {
      final collector = InferenceImpactCollector();
      final result = await _collectStream(
        _cloudRepository.generate(
          messages.user,
          model: modelId,
          temperature: null,
          baseUrl: provider.baseUrl,
          apiKey: provider.apiKey,
          provider: provider,
          systemMessage: messages.system,
          tools: [transcriptNameCorrectionTool],
          toolChoice: transcriptNameCorrectionToolChoiceFor(modelId),
          impactCollector: collector,
        ),
      );
      final corrected = applyTranscriptNameCorrections(
        transcript,
        parseTranscriptNameCorrections(result.toolCalls),
        terms,
      );
      _loggingService.log(
        LogDomain.ai,
        'Name correction for ${entity.meta.id}: '
        '${corrected.corrections.length} applied',
        subDomain: 'runTranscription.nameCorrection',
      );
      final completedAt = DateTime.now();
      final responseText = result.toolCalls
          .map((call) => call.function.arguments)
          .join('\n');
      return (
        text: corrected.text,
        event: _consumptionEvent(
          id: uuid.v4(),
          entryId: entity.meta.id,
          taskId: taskId,
          categoryId: entity.meta.categoryId,
          skillId: skillId,
          provider: provider,
          modelId: modelId,
          responseType: AiResponseType.audioTranscription,
          usage: result.usage,
          impact: collector.impact,
          start: start,
          completedAt: completedAt,
          interactionKind: AiInteractionKind.textGeneration,
          requestDigest: sha256
              .convert(utf8.encode('${messages.system}\n${messages.user}'))
              .toString(),
          responseDigest: sha256.convert(utf8.encode(responseText)).toString(),
        ),
      );
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.ai,
        error,
        stackTrace: stackTrace,
        subDomain: 'runTranscription.nameCorrection',
      );
      return null;
    }
  }

  Future<AiWorkAttribution?> _recordAttributedConsumption({
    required AiAttributionSession? attribution,
    required String entryId,
    required String? taskId,
    required String? categoryId,
    required String skillId,
    required AiConfigInferenceProvider provider,
    required String modelId,
    required AiResponseType responseType,
    required CompletionUsage? usage,
    required MeliousCallImpact? impact,
    required DateTime start,
    required AiInteractionKind interactionKind,
    required String requestText,
    required String responseText,
    AiWorkStatus status = AiWorkStatus.succeeded,
    String? errorCode,
    String? errorSummary,
    List<AiConsumptionEvent> additionalEvents = const [],
  }) async {
    if (attribution == null) {
      return null;
    }

    final interactionId = uuid.v4();
    final completedAt = DateTime.now();
    final requestDigest = sha256.convert(utf8.encode(requestText)).toString();
    final responseDigest = sha256.convert(utf8.encode(responseText)).toString();
    final event = _consumptionEvent(
      id: interactionId,
      entryId: entryId,
      taskId: taskId,
      categoryId: categoryId,
      skillId: skillId,
      provider: provider,
      modelId: modelId,
      responseType: responseType,
      usage: usage,
      impact: impact,
      start: start,
      completedAt: completedAt,
      interactionKind: interactionKind,
      requestDigest: requestDigest,
      responseDigest: responseDigest,
    );
    for (final interaction in [event, ...additionalEvents]) {
      await getIt<AiAttributionService>().recordInteraction(
        attributionId: attribution.id,
        event: interaction,
      );
    }
    return getIt<AiAttributionService>().prepareCompletion(
      attributionId: attribution.id,
      outputs: attribution.intendedOutputs,
      status: status,
      errorCode: errorCode,
      errorSummary: errorSummary,
    );
  }

  Future<void> _finalizeAttribution(
    AiWorkAttribution? envelope,
  ) async {
    if (envelope == null || !getIt.isRegistered<AiAttributionService>()) {
      return;
    }
    await getIt<AiAttributionService>().finalize(envelope);
  }

  AiConsumptionEvent _consumptionEvent({
    required String id,
    required String entryId,
    required String? taskId,
    required String? categoryId,
    required String skillId,
    required AiConfigInferenceProvider provider,
    required String modelId,
    required AiResponseType responseType,
    required CompletionUsage? usage,
    required MeliousCallImpact? impact,
    required DateTime start,
    required DateTime completedAt,
    AiInteractionKind? interactionKind,
    String? requestDigest,
    String? responseDigest,
  }) => AiConsumptionEvent(
    id: id,
    createdAt: start,
    providerType: provider.inferenceProviderType,
    responseType: responseType.consumptionResponseType,
    vectorClock: null,
    interactionKind: interactionKind,
    completedAt: completedAt,
    requestDigest: requestDigest,
    responseDigest: responseDigest,
    interactionParameters: {
      'model': modelId,
      'providerType': provider.inferenceProviderType.name,
    },
    entryId: entryId,
    taskId: taskId,
    categoryId: categoryId,
    skillId: skillId,
    providerModelId: modelId,
    durationMs: completedAt.difference(start).inMilliseconds,
    inputTokens: usage?.promptTokens,
    outputTokens: usage?.completionTokens,
    cachedInputTokens: usage?.promptTokensDetails?.cachedTokens,
    thoughtsTokens: usage?.completionTokensDetails?.reasoningTokens,
    totalTokens: usage?.totalTokens,
    credits: impact?.costCredits,
    costCreditsDecimal: impact?.costCreditsDecimal,
    energyKwh: impact?.energyKwh,
    carbonGCo2: impact?.carbonGCo2,
    waterLiters: impact?.waterLiters,
    renewablePercent: impact?.renewablePercent,
    pue: impact?.pue,
    dataCenter: impact?.dataCenter,
    upstreamProviderId: impact?.providerId,
  );
}

/// Resolved (provider, modelId, model) tuple returned by the per-slot
/// resolver helpers. Fields may be null when the override is unresolvable and
/// the profile slot is also empty — the caller short-circuits with a "missing
/// provider/model" log in that case. The `model` field carries the resolved
/// `AiConfigModel` row so per-model settings (e.g. Gemini thinking mode)
/// survive resolution.
typedef _InferenceTarget = ({
  AiConfigInferenceProvider? provider,
  String? modelId,
  AiConfigModel? model,
});

/// Identifier for which profile slot a per-invocation override is targeting.
/// The [label] is interpolated into warning logs so a future slot kind only
/// needs a new enum value, not a new magic-string literal that could
/// typo-drift across the codebase.
enum _OverrideSlotKind {
  transcription('transcription'),
  imageAnalysis('image analysis'),
  promptGeneration('prompt generation'),
  imageGeneration('image generation'),
  audioSummary('audio summary');

  const _OverrideSlotKind(this.label);

  /// Human-readable form used in log messages.
  final String label;
}

final skillInferenceRunnerProvider = Provider<SkillInferenceRunner>(
  skillInferenceRunner,
  name: 'skillInferenceRunnerProvider',
);
SkillInferenceRunner skillInferenceRunner(Ref ref) {
  final taskSummaryResolver = TaskSummaryResolver.fromRegisteredAgentDatabase(
    domainLogger: ref.watch(domainLoggerProvider),
  );

  return SkillInferenceRunner(
    ref: ref,
    cloudRepository: ref.watch(cloudInferenceRepositoryProvider),
    aiInputRepository: ref.watch(aiInputRepositoryProvider),
    journalRepository: ref.watch(journalRepositoryProvider),
    loggingService: ref.watch(domainLoggerProvider),
    taskSummaryResolver: taskSummaryResolver,
    promptBuilderHelper: PromptBuilderHelper(
      aiInputRepository: ref.watch(aiInputRepositoryProvider),
      journalRepository: ref.watch(journalRepositoryProvider),
      taskSummaryResolver: taskSummaryResolver,
      domainLogger: ref.watch(domainLoggerProvider),
    ),
  );
}
