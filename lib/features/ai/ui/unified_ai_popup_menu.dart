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
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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
      hasAvailableSkillsProvider(journalEntity.id),
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
class UnifiedAiSkillsList extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final skills =
        ref.watch(availableSkillsForEntityProvider(journalEntity.id)).value ??
        [];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (skills.isNotEmpty) ...[
          _SectionHeader(title: context.messages.skillsSectionTitle),
          ...skills.map(
            (skill) => ModernModalPromptItem(
              title: skill.name,
              description: skill.description ?? '',
              icon: skill.skillType.toResponseType.icon,
              onTap: () => onSkillSelected(skill),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
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
