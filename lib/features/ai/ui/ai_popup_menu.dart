import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/ai_modal_providers.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/audio_transcription/audio_transcription_progress_list_tile.dart';
import 'package:lotti/features/ai/ui/audio_transcription/audio_transcription_progress_view.dart';
import 'package:lotti/features/ai/ui/image_analysis/ai_image_analysis_list_tile.dart';
import 'package:lotti/features/ai/ui/image_analysis/ai_image_analysis_view.dart';
import 'package:lotti/features/ai/ui/task_summary/action_item_suggestions_list_tile.dart';
import 'package:lotti/features/ai/ui/task_summary/action_item_suggestions_view.dart';
import 'package:lotti/features/ai/ui/task_summary/ai_task_summary_list_tile.dart';
import 'package:lotti/features/ai/ui/task_summary/ai_task_summary_view.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class AiPopUpMenu extends ConsumerWidget {
  const AiPopUpMenu({
    required this.journalEntity,
    required this.linkedFromId,
    super.key,
  });

  final JournalEntity journalEntity;
  final String? linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journalEntity = this.journalEntity;
    return IconButton(
      icon: Icon(
        Icons.assistant_rounded,
        color: context.colorScheme.outline,
      ),
      onPressed: () => AiModal.show<void>(
        context: context,
        ref: ref,
        journalEntity: journalEntity,
        linkedFromId: linkedFromId,
      ),
    );
  }
}

class AiModal {
  static Future<void> show<T>({
    required BuildContext context,
    required WidgetRef ref,
    required JournalEntity journalEntity,
    required String? linkedFromId,
  }) async {
    final pageIndexNotifier = ValueNotifier(0);
    final selectedPromptNotifier = ValueNotifier<AiConfigPrompt?>(null);
    final selectedModelIdNotifier = ValueNotifier<String?>(null);

    final initialModalPage = ModalUtils.modalSheetPage(
      context: context,
      title: context.messages.aiAssistantTitle,
      child: Column(
        children: [
          if (journalEntity is Task)
            AiTaskSummaryListTile(
              journalEntity: journalEntity,
              linkedFromId: linkedFromId,
              onTap: () => pageIndexNotifier.value = 1,
            ),
          if (journalEntity is Task)
            ActionItemSuggestionsListTile(
              journalEntity: journalEntity,
              linkedFromId: linkedFromId,
              onTap: () => pageIndexNotifier.value = 4,
            ),
          if (journalEntity is JournalImage)
            AiImageAnalysisListTile(
              journalImage: journalEntity,
              linkedFromId: linkedFromId,
              onTap: () => pageIndexNotifier.value = 5,
            ),
          if (journalEntity is JournalAudio)
            AudioTranscriptionProgressListTile(
              journalAudio: journalEntity,
              linkedFromId: linkedFromId,
              onTap: () => pageIndexNotifier.value = 6,
            ),
          verticalModalSpacer,
        ],
      ),
    );

    final promptSelectionPage = WoltModalSheetPage(
      hasSabGradient: false,
      topBarTitle: Text(
        context.messages.aiAssistantSelectPromptTitle,
        style: context.textTheme.titleMedium,
      ),
      isTopBarLayerAlwaysVisible: true,
      leadingNavBarWidget: IconButton(
        padding: const EdgeInsets.all(16),
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => pageIndexNotifier.value = 0,
      ),
      child: Consumer(
        builder: (context, WidgetRef consumerRef, _) {
          final promptsAsyncValue = consumerRef.watch(
            promptsForAiResponseTypeProvider(AiResponseType.taskSummary),
          );
          return promptsAsyncValue.when(
            data: (prompts) {
              if (prompts.isEmpty) {
                return Center(
                  child: Text(
                    context.messages.aiAssistantNoTaskSummaryPromptsFound,
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                shrinkWrap: true,
                itemCount: prompts.length,
                itemBuilder: (context, index) {
                  final prompt = prompts[index];
                  return ListTile(
                    title: Text(prompt.name),
                    subtitle: Text(
                      prompt.description ?? 'No description',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      selectedPromptNotifier.value = prompt;
                      selectedModelIdNotifier.value = null;
                      if (prompt.modelIds.length > 1) {
                        pageIndexNotifier.value = 2;
                      } else {
                        selectedModelIdNotifier.value = prompt.defaultModelId;
                        pageIndexNotifier.value = 3;
                      }
                    },
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator.adaptive()),
            error: (error, stackTrace) =>
                Center(child: Text(context.messages.aiAssistantNoPromptsFound)),
          );
        },
      ),
    );

    final modelSelectionPage = WoltModalSheetPage(
      hasSabGradient: false,
      topBarTitle: Text(
        context.messages.aiAssistantSelectModelTitle,
        style: context.textTheme.titleMedium,
      ),
      isTopBarLayerAlwaysVisible: true,
      leadingNavBarWidget: IconButton(
        padding: const EdgeInsets.all(16),
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => pageIndexNotifier.value = 5,
      ),
      child: ValueListenableBuilder<AiConfigPrompt?>(
        valueListenable: selectedPromptNotifier,
        builder: (context, selectedPrompt, _) {
          if (selectedPrompt == null || selectedPrompt.modelIds.isEmpty) {
            return Center(
              child: Text(context.messages.aiAssistantNoModelsForPrompt),
            );
          }

          return Consumer(
            builder: (context, WidgetRef consumerRef, child) {
              final modelsAsyncValue = consumerRef
                  .watch(modelsByIdsProvider(selectedPrompt.modelIds));
              return modelsAsyncValue.when(
                data: (models) {
                  if (models.isEmpty && selectedPrompt.modelIds.isNotEmpty) {
                    return Center(
                      child: Text(
                        context.messages.aiAssistantModelsNotFoundForPrompt,
                      ),
                    );
                  }
                  if (models.isEmpty) {
                    return Center(
                      child: Text(
                        context.messages.aiAssistantNoModelsForPrompt,
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 20),
                    shrinkWrap: true,
                    itemCount: models.length,
                    itemBuilder: (context, index) {
                      final model = models[index];
                      return ListTile(
                        title: Text(model.name),
                        subtitle: model.description != null &&
                                model.description!.isNotEmpty
                            ? Text(
                                model.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: model.id == selectedPrompt.defaultModelId
                            ? const Icon(Icons.star)
                            : null,
                        onTap: () {
                          selectedModelIdNotifier.value = model.id;
                          pageIndexNotifier.value = 3;
                        },
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (err, stack) =>
                    Center(child: Text('Error loading models: $err')),
              );
            },
          );
        },
      ),
    );

    final taskSummaryModalPage = WoltModalSheetPage(
      hasSabGradient: false,
      topBarTitle: Text(
        context.messages.aiAssistantSummarizeTask,
        style: context.textTheme.titleMedium,
      ),
      isTopBarLayerAlwaysVisible: true,
      leadingNavBarWidget: IconButton(
        padding: const EdgeInsets.all(16),
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () {
          if (selectedPromptNotifier.value != null &&
              selectedPromptNotifier.value!.modelIds.length > 1) {
            pageIndexNotifier.value = 6;
          } else {
            pageIndexNotifier.value = 5;
          }
        },
      ),
      child: ValueListenableBuilder<AiConfigPrompt?>(
        valueListenable: selectedPromptNotifier,
        builder: (context, selectedPrompt, _) {
          return AiTaskSummaryView(
            id: journalEntity.id,
            promptId: selectedPrompt?.id,
            modelId: selectedModelIdNotifier.value,
          );
        },
      ),
    );

    final actionItemSuggestionsModalPage = ModalUtils.modalSheetPage(
      context: context,
      title: context.messages.aiAssistantActionItemSuggestions,
      child: ActionItemSuggestionsView(id: journalEntity.id),
      onTapBack: () => pageIndexNotifier.value = 0,
    );

    final imageAnalysisModalPage = ModalUtils.modalSheetPage(
      context: context,
      title: context.messages.aiAssistantAnalyzeImage,
      child: AiImageAnalysisView(id: journalEntity.id),
      onTapBack: () => pageIndexNotifier.value = 0,
    );

    final audioTranscriptionModalPage = ModalUtils.modalSheetPage(
      context: context,
      title: context.messages.aiAssistantTranscribeAudio,
      child: AudioTranscriptionProgressView(id: journalEntity.id),
      onTapBack: () => pageIndexNotifier.value = 0,
    );

    return WoltModalSheet.show<void>(
      context: context,
      pageListBuilder: (modalSheetContext) {
        return [
          initialModalPage,
          promptSelectionPage,
          modelSelectionPage,
          taskSummaryModalPage,
          actionItemSuggestionsModalPage,
          imageAnalysisModalPage,
          audioTranscriptionModalPage,
        ];
      },
      modalTypeBuilder: ModalUtils.modalTypeBuilder,
      barrierDismissible: true,
      pageIndexNotifier: pageIndexNotifier,
    );
  }
}
