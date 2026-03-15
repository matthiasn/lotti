import 'dart:async';
import 'dart:developer' as developer;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/image_generation/cover_art_skill_modal.dart';
import 'package:lotti/features/ai/ui/image_generation/image_generation_review_modal.dart';
import 'package:lotti/features/ai/ui/unified_ai_progress_view.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/glass_action_button.dart';
import 'package:lotti/widgets/modal/index.dart';

/// Unified AI popup menu that shows available prompts for the current entity
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
      hasAvailablePromptsProvider(journalEntity.id),
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
      builder: (modalSheetContext) => UnifiedAiPromptsList(
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
              )).future,
            ),
          );
        },
        onPromptSelected: (prompt, index) async {
          // Close the current modal first
          Navigator.of(modalSheetContext).pop();

          developer.log(
            'AI popup menu trigger: entity=${journalEntity.id}, prompt=${prompt.id}, linkedFrom=$linkedFromId, index=$index',
            name: 'UnifiedAiPopUpMenu',
          );

          // Handle image generation separately
          if (prompt.aiResponseType == AiResponseType.imageGeneration) {
            await _handleImageGeneration(
              context: context,
              journalEntity: journalEntity,
              ref: ref,
            );
            return;
          }

          final targetLinkedEntityId = journalEntity is Task
              ? linkedFromId
              : journalEntity.id;

          // Trigger inference in the background
          unawaited(
            ref.read(
              triggerNewInferenceProvider((
                entityId: journalEntity.id,
                promptId: prompt.id,
                linkedEntityId: targetLinkedEntityId,
              )).future,
            ),
          );

          // Show the progress modal immediately
          await ModalUtils.showSingleSliverPageModal<void>(
            context: context,
            builder: (ctx) => UnifiedAiProgressUtils.progressPage(
              context: ctx,
              prompt: prompt,
              entityId: journalEntity.id,
              onTapBack: () => Navigator.of(ctx).pop(),
              triggerOnOpen: false,
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
    required AiConfigSkill skill,
    required WidgetRef ref,
  }) async {
    final journalRepo = ref.read(journalRepositoryProvider);
    final linkedTask = await _resolveLinkedTask(
      journalEntity: journalEntity,
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

  /// Handles image generation prompts separately from the unified inference
  /// flow (legacy path).
  static Future<void> _handleImageGeneration({
    required BuildContext context,
    required JournalEntity journalEntity,
    required WidgetRef ref,
  }) async {
    final journalRepo = ref.read(journalRepositoryProvider);
    final linkedTask = await _resolveLinkedTask(
      journalEntity: journalEntity,
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

    await ImageGenerationReviewModal.show(
      context: context,
      entityId: journalEntity.id,
      linkedTaskId: linkedTask.id,
      categoryId: linkedTask.meta.categoryId,
    );
  }

  /// Resolves the linked task for an entity, checking both link directions.
  static Future<Task?> _resolveLinkedTask({
    required JournalEntity journalEntity,
    required JournalRepository journalRepo,
  }) async {
    // First try: find tasks that this entry links TO (entry → task)
    final linkedEntities = await journalRepo.getLinkedEntities(
      linkedTo: journalEntity.id,
    );
    final linkedTask = linkedEntities.whereType<Task>().firstOrNull;
    if (linkedTask != null) return linkedTask;

    // Fallback: find tasks that link TO this entry (task → entry)
    final fallbackEntities = await journalRepo.getLinkedToEntities(
      linkedTo: journalEntity.id,
    );
    return fallbackEntities.whereType<Task>().firstOrNull;
  }
}

/// List of available AI actions (skills + legacy prompts) for the current
/// entity, split into two labelled sections.
class UnifiedAiPromptsList extends ConsumerWidget {
  const UnifiedAiPromptsList({
    required this.journalEntity,
    required this.onPromptSelected,
    this.linkedFromId,
    this.onSkillSelected,
    super.key,
  });

  final JournalEntity journalEntity;
  final String? linkedFromId;
  final Future<void> Function(AiConfigPrompt prompt, int index)
  onPromptSelected;

  /// Called when a skill is tapped. If null, tapping a skill is a no-op.
  final Future<void> Function(AiConfigSkill skill)? onSkillSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skills =
        ref.watch(availableSkillsForEntityProvider(journalEntity.id)).value ??
        [];

    final prompts =
        ref.watch(availablePromptsProvider(journalEntity.id)).value ?? [];

    final categoryId = journalEntity.meta.categoryId;
    if (categoryId != null) {
      ref.watch(categoryChangesProvider(categoryId));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Skills section
        if (skills.isNotEmpty) ...[
          _SectionHeader(title: context.messages.skillsSectionTitle),
          ...skills.map(
            (skill) => ModernModalPromptItem(
              title: skill.name,
              description: skill.description ?? '',
              icon: skill.skillType.toResponseType.icon,
              onTap: () => onSkillSelected?.call(skill),
            ),
          ),
        ],

        // Legacy prompts section
        if (prompts.isNotEmpty) ...[
          if (skills.isNotEmpty)
            _SectionHeader(title: context.messages.legacyPromptsSectionTitle),
          ...prompts.asMap().entries.map((entry) {
            final index = entry.key;
            final prompt = entry.value;
            final isDefault = isDefaultPromptSync(categoryId, prompt);

            return ModernModalPromptItem(
              title: prompt.name,
              description: prompt.description ?? '',
              icon: _getIconForPrompt(prompt),
              onTap: () => onPromptSelected(prompt, index),
              isDefault: isDefault,
              iconColor: isDefault ? const Color(0xFFD4AF37) : null,
            );
          }),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  IconData _getIconForPrompt(AiConfigPrompt prompt) {
    if (prompt.requiredInputData.contains(InputDataType.images)) {
      return Icons.image;
    } else if (prompt.requiredInputData.contains(InputDataType.audioFiles)) {
      return Icons.mic;
    } else if (prompt.requiredInputData.contains(InputDataType.tasksList)) {
      return Icons.checklist;
    } else {
      return Icons.chat_rounded;
    }
  }
}

/// Subtle section header for the AI popup menu.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Check if a prompt is configured as an automatic default for the category
/// This is a synchronous version that uses the category cache
@visibleForTesting
bool isDefaultPromptSync(
  String? categoryId,
  AiConfigPrompt prompt,
) {
  if (categoryId == null) return false;

  try {
    final cacheService = getIt<EntitiesCacheService>();
    final category = cacheService.getCategoryById(categoryId);

    if (category?.automaticPrompts == null) return false;

    // Check if this prompt is the first in any automatic prompt list
    for (final entry in category!.automaticPrompts!.entries) {
      final promptIds = entry.value;
      if (promptIds.isNotEmpty && promptIds.first == prompt.id) {
        return true;
      }
    }
  } catch (e) {
    // If we can't get the category, just return false
    return false;
  }

  return false;
}
