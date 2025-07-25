import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/unified_ai_progress_view.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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
      hasAvailablePromptsProvider(entity: journalEntity),
    );

    return hasPromptsAsync.when(
      data: (hasPrompts) {
        if (!hasPrompts) return const SizedBox.shrink();

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
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
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
    final pageIndexNotifier = ValueNotifier(0);

    final promptsAsync = await ref.read(
      availablePromptsProvider(entity: journalEntity).future,
    );

    if (!context.mounted) {
      return;
    }

    final initialModalPage = ModalUtils.modalSheetPage(
      context: context,
      title: context.messages.aiAssistantTitle,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: UnifiedAiPromptsList(
        journalEntity: journalEntity,
        linkedFromId: linkedFromId,
        onPromptSelected: (prompt, index) {
          pageIndexNotifier.value = index + 1;
        },
      ),
    );

    final promptSliverPages = promptsAsync.asMap().entries.map((entry) {
      final prompt = entry.value;

      return UnifiedAiProgressUtils.progressPage(
        context: context,
        prompt: prompt,
        entityId: journalEntity.id,
        onTapBack: () => pageIndexNotifier.value = 0,
        scrollController: scrollController,
      );
    }).toList();

    return ModalUtils.showMultiPageModal<void>(
      context: context,
      pageListBuilder: (modalSheetContext) {
        return [
          initialModalPage,
          ...promptSliverPages,
        ];
      },
      pageIndexNotifier: pageIndexNotifier,
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
  final void Function(AiConfigPrompt prompt, int index) onPromptSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prompts = ref
            .watch(
              availablePromptsProvider(entity: journalEntity),
            )
            .valueOrNull ??
        [];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...prompts.asMap().entries.map((entry) {
          final index = entry.key;
          final prompt = entry.value;

          return ModernModalPromptItem(
            title: prompt.name,
            description: prompt.description ?? '',
            icon: _getIconForPrompt(prompt),
            onTap: () => onPromptSelected(prompt, index),
          );
        }),
        const SizedBox(height: 24),
      ],
    );
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
