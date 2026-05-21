import 'dart:async';
import 'dart:developer' as developer;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/image_generation/cover_art_skill_modal.dart';
import 'package:lotti/features/ai/ui/widgets/transcription_model_picker_modal.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/themes/theme.dart';

import 'package:lotti/widgets/app_bar/glass_action_button.dart';
import 'package:lotti/widgets/modal/index.dart';

/// Unified AI popup menu that shows available skills for the current entity
class UnifiedAiPopUpMenu extends ConsumerWidget {
  const UnifiedAiPopUpMenu({
    required this.journalEntity,
    required this.linkedFromId,
    this.iconColor,
    super.key,
  });

  final JournalEntity journalEntity;
  final String? linkedFromId;

  /// Optional icon color. Defaults to the theme's outline color.
  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPromptsAsync = ref.watch(
      hasAvailableSkillsProvider((
        entityId: journalEntity.id,
        linkedFromId: linkedFromId,
      )),
    );

    // Use hasValue to preserve the icon during refresh states.
    // Since the provider is now keyed by entityId (stable), updates to
    // the same entry will reuse the provider and maintain previous value.
    if (hasPromptsAsync.hasValue && hasPromptsAsync.value!) {
      final icon = Icon(
        Icons.assistant_rounded,
        color: iconColor ?? context.colorScheme.outline,
      );

      void onTap() => UnifiedAiModal.show<void>(
        context: context,
        journalEntity: journalEntity,
        linkedFromId: linkedFromId,
        ref: ref,
      );

      // Use GlassActionButton for proper clipped splash effect when iconColor
      // is specified (used over images), otherwise use standard IconButton
      if (iconColor != null) {
        return GlassActionButton(
          onTap: onTap,
          child: icon,
        );
      }

      return IconButton(
        icon: icon,
        onPressed: onTap,
      );
    }

    return const SizedBox.shrink();
  }
}

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

          // Transcription opens the model-override picker so the user
          // can route this single voice note to any speech-capable
          // model (default surfaced first). The picker short-circuits
          // when only one such model is configured, preserving the
          // one-tap flow for the common case.
          if (skill.skillType == SkillType.transcription) {
            await _handleTranscriptionSkill(
              context: context,
              journalEntity: journalEntity,
              linkedTaskId: linkedTaskId,
              skill: skill,
              ref: ref,
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
                overrideTranscriptionModelId: null,
              )).future,
            ),
          );
        },
      ),
      title: context.messages.aiAssistantTitle,
      padding: const EdgeInsets.symmetric(vertical: 20),
    );
  }

  /// Handles image generation skills by opening the cover art skill modal
  /// for reference image selection, then triggering generation in the
  /// background.
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

    if (!context.mounted) return;

    await CoverArtSkillModal.show(
      context: context,
      entityId: journalEntity.id,
      skillId: skill.id,
      linkedTaskId: linkedTask.id,
      categoryId: linkedTask.meta.categoryId,
      ref: ref,
    );
  }

  /// Opens the transcription-model picker, then fires the trigger
  /// with the user's selection threaded as `overrideTranscriptionModelId`.
  ///
  /// Profile resolution mirrors [triggerSkillProvider]'s logic: linked
  /// task uses the task's profile, standalone audio falls back to the
  /// entry category's `defaultProfileId`. The resolved profile's
  /// transcription slot (a wire-level `providerModelId` string) is
  /// translated to an `AiConfigModel.id` by matching against the
  /// loaded model list, so the picker can highlight that row as the
  /// default.
  ///
  /// When the picker resolves with the same id as the default we
  /// pass `null` as the override — same semantic as "no override" so
  /// the runner reads from the profile slot, and a deleted model
  /// between picker and runner falls back gracefully.
  static Future<void> _handleTranscriptionSkill({
    required BuildContext context,
    required JournalEntity journalEntity,
    required String? linkedTaskId,
    required AiConfigSkill skill,
    required WidgetRef ref,
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
    final speechCapable = allConfigs
        .whereType<AiConfigModel>()
        .where((m) => m.inputModalities.contains(Modality.audio))
        .toList();

    // Translate the profile's wire-level providerModelId to the
    // AiConfigModel.id so the picker can compare rows. A missing
    // match (deleted model, empty slot) leaves defaultModelId null;
    // the picker renders the list without a default row.
    String? defaultModelId;
    if (resolvedProfile != null) {
      final providerModelId = resolvedProfile.transcriptionModelId;
      final providerId = resolvedProfile.transcriptionProvider?.id;
      if (providerModelId != null && providerId != null) {
        defaultModelId = speechCapable
            .where(
              (m) =>
                  m.providerModelId == providerModelId &&
                  m.inferenceProviderId == providerId,
            )
            .firstOrNull
            ?.id;
      }
    }

    if (!context.mounted) return;
    final picked = await TranscriptionModelPickerModal.show(
      context: context,
      defaultModelId: defaultModelId,
      speechCapableModels: speechCapable,
    );
    if (picked == null) return;
    // The widget could have been disposed while the picker was open
    // (user navigated away, entry deleted). Reading ref on a
    // deactivated element throws — bail before the trigger fires.
    if (!context.mounted) return;

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
          overrideTranscriptionModelId: overrideId,
        )).future,
      ),
    );
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
