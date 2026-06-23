import 'dart:async';
import 'dart:developer' as developer;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
import 'package:lotti/features/ai/ui/image_generation/cover_art_skill_modal.dart';
import 'package:lotti/features/ai/ui/widgets/gemini_thinking_mode_picker_modal.dart';
import 'package:lotti/features/ai/ui/widgets/inference_provider_model_picker_modal.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/modal/index.dart';

/// (configId, modelId, providerId) tuple pulled from a [ResolvedProfile]
/// for one per-invocation override slot. `configId` is the resolved
/// `AiConfigModel.id` row, `modelId` the wire-level `providerModelId`.
/// All fields are nullable because a freshly-installed profile may not
/// have populated the slot yet.
typedef _ProfileSlotValue = ({
  String? configId,
  String? modelId,
  String? providerId,
});

/// Per-skill configuration for the model-override popup flow. Each
/// entry plugs in a modality filter, profile-slot accessor, and the
/// localised title + default-badge strings used by the picker. Adding
/// a new override slot is a one-line entry in
/// [_modelOverrideConfigs] plus a corresponding dispatch branch in
/// the skill inference runner.
class _SkillModelOverrideConfig {
  const _SkillModelOverrideConfig({
    required this.modality,
    required this.slotAccessor,
    required this.titleSelector,
    required this.defaultBadgeSelector,
  });

  /// Modality the model must accept to appear in the picker. Filters
  /// the raw `AiConfigModel` list down to the relevant capability set
  /// (e.g. `Modality.audio` for transcription, `Modality.image` for
  /// image analysis).
  final Modality modality;

  /// Pulls the `(configId, providerModelId, providerId)` tuple for the
  /// override slot out of the resolved profile.
  final _ProfileSlotValue Function(ResolvedProfile) slotAccessor;

  /// Returns the picker modal title for this slot. Resolved against
  /// the live [AppLocalizations] at handler time.
  final String Function(AppLocalizations) titleSelector;

  /// Returns the "(default)" badge label for this slot. Same
  /// resolution timing as [titleSelector].
  final String Function(AppLocalizations) defaultBadgeSelector;
}

_ProfileSlotValue _transcriptionSlot(ResolvedProfile p) => (
  configId: p.transcriptionModel?.id,
  modelId: p.transcriptionModelId,
  providerId: p.transcriptionProvider?.id,
);

_ProfileSlotValue _imageAnalysisSlot(ResolvedProfile p) => (
  configId: p.imageRecognitionModel?.id,
  modelId: p.imageRecognitionModelId,
  providerId: p.imageRecognitionProvider?.id,
);

_ProfileSlotValue _highEndThinkingSlot(ResolvedProfile p) => (
  configId: p.effectiveHighEndModel?.id,
  modelId: p.effectiveHighEndModelId,
  providerId: p.effectiveHighEndProvider.id,
);

/// Skill types that open a model-override picker on tap, keyed by
/// [SkillType]. Skill types not in this map fall through to the
/// straight `triggerSkillProvider` call in [UnifiedAiModal.show].
const _modelOverrideConfigs = <SkillType, _SkillModelOverrideConfig>{
  SkillType.transcription: _SkillModelOverrideConfig(
    modality: Modality.audio,
    slotAccessor: _transcriptionSlot,
    titleSelector: _transcriptionTitleSelector,
    defaultBadgeSelector: _transcriptionBadgeSelector,
  ),
  SkillType.imageAnalysis: _SkillModelOverrideConfig(
    modality: Modality.image,
    slotAccessor: _imageAnalysisSlot,
    titleSelector: _imageAnalysisTitleSelector,
    defaultBadgeSelector: _imageAnalysisBadgeSelector,
  ),
  SkillType.promptGeneration: _SkillModelOverrideConfig(
    modality: Modality.text,
    slotAccessor: _highEndThinkingSlot,
    titleSelector: _promptGenerationTitleSelector,
    defaultBadgeSelector: _promptGenerationBadgeSelector,
  ),
  SkillType.imagePromptGeneration: _SkillModelOverrideConfig(
    modality: Modality.text,
    slotAccessor: _highEndThinkingSlot,
    titleSelector: _promptGenerationTitleSelector,
    defaultBadgeSelector: _promptGenerationBadgeSelector,
  ),
};

String _transcriptionTitleSelector(AppLocalizations m) =>
    m.aiTranscriptionPickerTitle;
String _transcriptionBadgeSelector(AppLocalizations m) =>
    m.aiTranscriptionPickerDefaultBadge;
String _imageAnalysisTitleSelector(AppLocalizations m) =>
    m.aiImageAnalysisPickerTitle;
String _imageAnalysisBadgeSelector(AppLocalizations m) =>
    m.aiImageAnalysisPickerDefaultBadge;
String _promptGenerationTitleSelector(AppLocalizations m) =>
    m.aiPromptGenerationPickerTitle;
String _promptGenerationBadgeSelector(AppLocalizations m) =>
    m.designSystemDefaultLabel;

class UnifiedAiModal {
  static Future<void> show<T>({
    required BuildContext context,
    required JournalEntity journalEntity,
    required String? linkedFromId,
    required WidgetRef ref,
    ScrollController? scrollController,
  }) async {
    return ModalUtils.showSinglePageModal<void>(
      context: context,
      builder: (modalSheetContext) => UnifiedAiSkillsList(
        journalEntity: journalEntity,
        linkedFromId: linkedFromId,
        onSkillSelected: (skill) async {
          // Close the modal first
          Navigator.of(modalSheetContext).pop();

          developer.log(
            'AI popup menu skill trigger: entity=${journalEntity.id}, '
            'skill=${skill.id}, linkedFrom=$linkedFromId',
            name: 'UnifiedAiPopUpMenu',
          );

          // Determine the linked task ID for profile resolution
          final linkedTaskId = journalEntity is Task
              ? journalEntity.id
              : linkedFromId;

          // Image generation skills need reference image selection first
          if (skill.skillType == SkillType.imageGeneration) {
            await _handleImageGenerationSkill(
              context: context,
              journalEntity: journalEntity,
              preferredTaskId: linkedTaskId,
              skill: skill,
              ref: ref,
            );
            return;
          }

          // Skill types with a per-invocation model override (today:
          // transcription + image analysis) open the model-override
          // picker before firing the trigger. Each skill type plugs
          // in its own modality filter, profile slot accessor, and
          // l10n strings via _modelOverrideConfigs — adding a new
          // override slot is a one-line entry in that map.
          final overrideConfig = _modelOverrideConfigs[skill.skillType];
          if (overrideConfig != null) {
            await _handleSkillWithModelOverride(
              context: context,
              journalEntity: journalEntity,
              linkedTaskId: linkedTaskId,
              skill: skill,
              ref: ref,
              config: overrideConfig,
            );
            return;
          }

          // Trigger the skill inference in the background
          unawaited(
            ref.read(
              triggerSkillProvider((
                entityId: journalEntity.id,
                skillId: skill.id,
                linkedTaskId: linkedTaskId,
                referenceImages: null,
                overrideModelId: null,
                geminiThinkingMode: null,
              )).future,
            ),
          );
        },
      ),
      title: context.messages.aiAssistantTitle,
      padding: const EdgeInsets.symmetric(vertical: 20),
    );
  }

  /// Handles image generation skills by letting the user pick which image
  /// model runs (provider-first, like the other skills), then opening the
  /// cover art skill modal for reference image selection and triggering
  /// generation in the background.
  ///
  /// The picker is filtered to models that *output* images. When fewer than
  /// two are configured there is no choice to offer, so generation falls
  /// straight through to the profile's image-generation slot (preserving the
  /// prior behaviour, including its in-modal error when none is set).
  static Future<void> _handleImageGenerationSkill({
    required BuildContext context,
    required JournalEntity journalEntity,
    required String? preferredTaskId,
    required AiConfigSkill skill,
    required WidgetRef ref,
  }) async {
    final journalRepo = ref.read(journalRepositoryProvider);
    final linkedTask = await _resolveLinkedTask(
      journalEntity: journalEntity,
      preferredTaskId: preferredTaskId,
      journalRepo: journalRepo,
    );

    if (linkedTask == null) {
      developer.log(
        'No linked task found for entity: ${journalEntity.id}',
        name: 'UnifiedAiPopUpMenu',
      );
      return;
    }

    final repo = ref.read(aiConfigRepositoryProvider);
    final imageModels = (await repo.getConfigsByType(AiConfigType.model))
        .whereType<AiConfigModel>()
        .where((model) => model.outputModalities.contains(Modality.image))
        .toList();

    String? overrideModelId;
    if (imageModels.isNotEmpty) {
      final resolver = ref.read(profileAutomationResolverProvider);
      final resolvedProfile = await resolver.resolveForTask(linkedTask.id);
      final providerConfigs = await repo.getConfigsByType(
        AiConfigType.inferenceProvider,
      );

      final defaultModelId = resolvedProfile == null
          ? null
          : _matchDefaultModelId(
              models: imageModels,
              configId: resolvedProfile.imageGenerationModel?.id,
              providerModelId: resolvedProfile.imageGenerationModelId,
              providerId: resolvedProfile.imageGenerationProvider?.id,
            );

      if (!context.mounted) return;
      final messages = context.messages;
      final picked = await InferenceProviderModelPickerModal.show(
        context: context,
        defaultModelId: defaultModelId,
        models: imageModels,
        providers: providerConfigs
            .whereType<AiConfigInferenceProvider>()
            .toList(),
        title: messages.aiImageGenerationPickerTitle,
        defaultBadgeLabel: messages.designSystemDefaultLabel,
      );

      // A null result is a dismissal only when a choice was actually shown
      // (2+ models). With one model the picker resolves to it without a modal.
      if (picked == null && imageModels.length > 1) return;
      overrideModelId = picked == defaultModelId ? null : picked;
    }

    if (!context.mounted) return;

    await CoverArtSkillModal.show(
      context: context,
      entityId: journalEntity.id,
      skillId: skill.id,
      linkedTaskId: linkedTask.id,
      overrideModelId: overrideModelId,
      ref: ref,
    );
  }

  /// Opens the model-override picker for any skill type that has a
  /// per-invocation override slot (configured in
  /// [_modelOverrideConfigs]), then fires the trigger with the user's
  /// selection threaded as `overrideModelId`.
  ///
  /// Profile resolution mirrors [triggerSkillProvider]'s logic: linked
  /// task uses the task's profile, standalone entries fall back to
  /// the entry category's `defaultProfileId`. The resolved profile's
  /// per-slot `AiConfigModel.id` is matched exactly against the loaded
  /// model list so the picker can highlight that row as the default;
  /// the wire-level `(providerModelId, providerId)` pair is only a
  /// legacy fallback, since several rows can share the same provider
  /// model while differing in settings such as thinking mode.
  ///
  /// When the picker resolves with the same id as the default we
  /// pass `null` as the override — same semantic as "no override" so
  /// the runner reads from the profile slot, and a deleted model
  /// between picker and runner falls back gracefully.
  static Future<void> _handleSkillWithModelOverride({
    required BuildContext context,
    required JournalEntity journalEntity,
    required String? linkedTaskId,
    required AiConfigSkill skill,
    required WidgetRef ref,
    required _SkillModelOverrideConfig config,
  }) async {
    final resolver = ref.read(profileAutomationResolverProvider);
    final resolvedProfile = linkedTaskId != null
        ? await resolver.resolveForTask(linkedTaskId)
        : (journalEntity.meta.categoryId != null
              ? await resolver.resolveForCategory(
                  journalEntity.meta.categoryId!,
                )
              : null);

    // Read models via the repository's one-shot `getConfigsByType`
    // rather than the auto-dispose stream-backed controller. The
    // controller would dispose mid-await when no widget is watching
    // it (the popup modal has already popped by the time this
    // handler runs), starving the picker of its model list. The
    // repository call is a single Drift query, fast enough for an
    // on-tap UI gesture.
    final repo = ref.read(aiConfigRepositoryProvider);
    final allConfigs = await repo.getConfigsByType(AiConfigType.model);
    final modalityCapable = allConfigs
        .whereType<AiConfigModel>()
        .where((m) => m.inputModalities.contains(config.modality))
        .toList();
    final providerConfigs = await repo.getConfigsByType(
      AiConfigType.inferenceProvider,
    );
    final providersById = <String, AiConfigInferenceProvider>{
      for (final provider
          in providerConfigs.whereType<AiConfigInferenceProvider>())
        provider.id: provider,
    };

    // Match the profile's resolved slot to one of the offered models so the
    // picker can mark it default (exact AiConfigModel.id first, wire-level
    // providerModelId+providerId as a legacy fallback). A missing match
    // (deleted model, empty slot) leaves defaultModelId null; the picker
    // renders the list without a default row.
    String? defaultModelId;
    if (resolvedProfile != null) {
      final slot = config.slotAccessor(resolvedProfile);
      defaultModelId = _matchDefaultModelId(
        models: modalityCapable,
        configId: slot.configId,
        providerModelId: slot.modelId,
        providerId: slot.providerId,
      );
    }

    if (!context.mounted) return;
    // Cache l10n on the still-mounted context before awaiting the
    // picker — the surrounding widget may be disposed while the
    // picker is open, after which `context.messages` would throw.
    final messages = context.messages;
    final picked = await InferenceProviderModelPickerModal.show(
      context: context,
      defaultModelId: defaultModelId,
      models: modalityCapable,
      providers: providerConfigs
          .whereType<AiConfigInferenceProvider>()
          .toList(),
      title: config.titleSelector(messages),
      defaultBadgeLabel: config.defaultBadgeSelector(messages),
    );
    if (picked == null) return;
    // Second mounted check: the picker `await` can resolve after the
    // surrounding widget has been deactivated (user navigated away,
    // entry deleted). Reading `ref` on a deactivated element throws,
    // so we bail before firing the trigger.
    if (!context.mounted) return;

    final selectedModel = modalityCapable.firstWhereOrNull(
      (model) => model.id == picked,
    );
    final selectedProvider = selectedModel != null
        ? providersById[selectedModel.inferenceProviderId]
        : null;

    GeminiThinkingMode? geminiThinkingMode;
    if (selectedProvider?.inferenceProviderType ==
            InferenceProviderType.gemini &&
        selectedModel != null &&
        GeminiThinkingConfig.isGemini3(selectedModel.providerModelId)) {
      final pickedMode = await GeminiThinkingModePickerModal.show(
        context: context,
        selectedMode: selectedModel.geminiThinkingMode,
      );
      if (pickedMode == null) return;
      geminiThinkingMode = pickedMode;
      if (!context.mounted) return;
    }

    // Same id as default → no override semantic — the runner reads
    // the profile slot. Different id → forward as override.
    final overrideId = picked == defaultModelId ? null : picked;

    unawaited(
      ref.read(
        triggerSkillProvider((
          entityId: journalEntity.id,
          skillId: skill.id,
          linkedTaskId: linkedTaskId,
          referenceImages: null,
          overrideModelId: overrideId,
          geminiThinkingMode: geminiThinkingMode,
        )).future,
      ),
    );
  }

  /// Resolves which of [models] the profile slot points at, so the picker can
  /// mark it as the default. Matches the resolved `AiConfigModel.id` exactly
  /// first, then falls back to the wire-level `providerModelId` + `providerId`
  /// pair for slots that resolved without a model row. Returns `null` when
  /// nothing matches (deleted model or empty slot).
  static String? _matchDefaultModelId({
    required List<AiConfigModel> models,
    required String? configId,
    required String? providerModelId,
    required String? providerId,
  }) {
    if (configId != null) {
      final byId = models.firstWhereOrNull((m) => m.id == configId);
      if (byId != null) return byId.id;
    }
    if (providerModelId != null && providerId != null) {
      return models
          .firstWhereOrNull(
            (m) =>
                m.providerModelId == providerModelId &&
                m.inferenceProviderId == providerId,
          )
          ?.id;
    }
    return null;
  }

  /// Resolves the linked task for an entity.
  ///
  /// Priority:
  /// 1. If the entity itself is a Task, return it directly.
  /// 2. If [preferredTaskId] is provided (from the caller's context), look it
  ///    up and return it if it's a Task.
  /// 3. Fallback: search outgoing links (entity → task) then incoming links
  ///    (task → entity) via the link graph.
  @visibleForTesting
  static Future<Task?> resolveLinkedTask({
    required JournalEntity journalEntity,
    required JournalRepository journalRepo,
    String? preferredTaskId,
  }) => _resolveLinkedTask(
    journalEntity: journalEntity,
    preferredTaskId: preferredTaskId,
    journalRepo: journalRepo,
  );

  static Future<Task?> _resolveLinkedTask({
    required JournalEntity journalEntity,
    required JournalRepository journalRepo,
    String? preferredTaskId,
  }) async {
    // If the entity itself is a Task, use it directly.
    if (journalEntity is Task) return journalEntity;

    // If the caller already knows the target task, prefer it.
    if (preferredTaskId != null) {
      final preferred = await journalRepo.getJournalEntityById(
        preferredTaskId,
      );
      if (preferred is Task) return preferred;
    }

    // Outgoing links: entities this entry links TO (entry → task).
    final linkedEntities = await journalRepo.getLinkedEntities(
      linkedTo: journalEntity.id,
    );
    final linkedTask = linkedEntities.whereType<Task>().firstOrNull;
    if (linkedTask != null) return linkedTask;

    // Incoming links: entities that link TO this entry (task → entry).
    final fallbackEntities = await journalRepo.getLinkedToEntities(
      linkedTo: journalEntity.id,
    );
    return fallbackEntities.whereType<Task>().firstOrNull;
  }
}

/// List of available AI skills for the current entity.
class UnifiedAiSkillsList extends ConsumerStatefulWidget {
  const UnifiedAiSkillsList({
    required this.journalEntity,
    required this.onSkillSelected,
    this.linkedFromId,
    super.key,
  });

  final JournalEntity journalEntity;
  final String? linkedFromId;

  /// Called when a skill is tapped.
  final Future<void> Function(AiConfigSkill skill) onSkillSelected;

  @override
  ConsumerState<UnifiedAiSkillsList> createState() =>
      _UnifiedAiSkillsListState();
}

class _UnifiedAiSkillsListState extends ConsumerState<UnifiedAiSkillsList> {
  String? _hoveredSkillId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    final params = (
      entityId: widget.journalEntity.id,
      linkedFromId: widget.linkedFromId,
    );

    // React to provider changes via ref.listen so the build method stays
    // pure: drop hover state when the hovered skill is no longer in the
    // refreshed list (e.g., flag toggle removes a skill while hovered).
    ref.listen(availableSkillsForEntityProvider(params), (previous, next) {
      final skills = next.value ?? const <AiConfigSkill>[];
      if (_hoveredSkillId != null &&
          !skills.any((skill) => skill.id == _hoveredSkillId) &&
          mounted) {
        setState(() => _hoveredSkillId = null);
      }
    });

    final skills =
        ref.watch(availableSkillsForEntityProvider(params)).value ?? [];

    if (skills.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title: context.messages.skillsSectionTitle),
        for (final (index, skill) in skills.indexed)
          DesignSystemListItem(
            key: ValueKey(skill.id),
            title: skill.name,
            subtitle: skill.description ?? '',
            subtitleMaxLines: 3,
            leading: Icon(
              skill.skillType.toResponseType.icon,
              size: 20,
              color: tokens.colors.interactive.enabled,
            ),
            showDivider: index < skills.length - 1,
            dividerColor:
                index < skills.length - 1 &&
                    (_hoveredSkillId == skill.id ||
                        _hoveredSkillId == skills[index + 1].id)
                ? Colors.transparent
                : null,
            onTap: () => widget.onSkillSelected(skill),
            onHoverChanged: (hovered) {
              setState(() {
                if (hovered) {
                  _hoveredSkillId = skill.id;
                } else if (_hoveredSkillId == skill.id) {
                  _hoveredSkillId = null;
                }
              });
            },
          ),
        SizedBox(height: tokens.spacing.step5),
      ],
    );
  }
}

/// Subtle section header for the AI popup menu, aligned with the design
/// system caption typography.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step4,
        tokens.spacing.step5,
        tokens.spacing.step2,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
      ),
    );
  }
}
