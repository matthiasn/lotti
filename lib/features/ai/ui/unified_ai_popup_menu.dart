import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/unified_ai_progress_view.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/index.dart';

/// Unified AI popup menu that shows available prompts for the current entity
class UnifiedAiPopUpMenu extends ConsumerWidget {
  const UnifiedAiPopUpMenu({
    required this.journalEntity,
    required this.linkedFromId,
    super.key,
  });

  final JournalEntity journalEntity;
  final String? linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPromptsAsync = ref.watch(
      hasAvailablePromptsProvider(journalEntity.id),
    );

    // Use hasValue to preserve the icon during refresh states.
    // Since the provider is now keyed by entityId (stable), updates to
    // the same entry will reuse the provider and maintain previous value.
    if (hasPromptsAsync.hasValue && hasPromptsAsync.value!) {
      return IconButton(
        icon: Icon(
          Icons.assistant_rounded,
          color: context.colorScheme.outline,
        ),
        onPressed: () => UnifiedAiModal.show<void>(
          context: context,
          journalEntity: journalEntity,
          linkedFromId: linkedFromId,
          ref: ref,
        ),
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
        onPromptSelected: (prompt, index) async {
          // Close the current modal first
          Navigator.of(modalSheetContext).pop();

          developer.log(
            'AI popup menu trigger: entity=${journalEntity.id}, prompt=${prompt.id}, linkedFrom=$linkedFromId, index=$index',
            name: 'UnifiedAiPopUpMenu',
          );

          final targetLinkedEntityId =
              journalEntity is Task ? linkedFromId : journalEntity.id;

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
}

/// List of available AI prompts for the current entity
class UnifiedAiPromptsList extends ConsumerWidget {
  const UnifiedAiPromptsList({
    required this.journalEntity,
    required this.onPromptSelected,
    this.linkedFromId,
    super.key,
  });

  final JournalEntity journalEntity;
  final String? linkedFromId;
  final Future<void> Function(AiConfigPrompt prompt, int index)
      onPromptSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prompts = ref
            .watch(
              availablePromptsProvider(journalEntity.id),
            )
            .valueOrNull ??
        [];

    // Get category to check for automatic prompts
    final categoryId = journalEntity.meta.categoryId;
    if (categoryId != null) {
      // This watch will rebuild the widget when the category changes.
      ref.watch(categoryChangesProvider(categoryId));
    }
    return _buildPromptList(
      context,
      ref,
      prompts,
      categoryId,
    );
  }

  Widget _buildPromptList(
    BuildContext context,
    WidgetRef ref,
    List<AiConfigPrompt> prompts,
    String? categoryId,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...prompts.asMap().entries.map((entry) {
          final index = entry.key;
          final prompt = entry.value;

          // Check if this prompt is a default automatic prompt
          final isDefault = _isDefaultPromptSync(
            ref,
            categoryId,
            prompt,
          );

          return ModernModalPromptItem(
            title: prompt.name,
            description: prompt.description ?? '',
            icon: _getIconForPrompt(prompt),
            onTap: () => onPromptSelected(prompt, index),
            isDefault: isDefault,
            iconColor: isDefault ? const Color(0xFFD4AF37) : null,
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Check if a prompt is configured as an automatic default for the category
  /// This is a synchronous version that uses the category cache
  bool _isDefaultPromptSync(
    WidgetRef ref,
    String? categoryId,
    AiConfigPrompt prompt,
  ) {
    return isDefaultPromptSync(categoryId, prompt);
  }

  IconData _getIconForPrompt(AiConfigPrompt prompt) {
    // Map prompt types to appropriate icons
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
