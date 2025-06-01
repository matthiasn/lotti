import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/latest_summary_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/ai_response_summary.dart';
import 'package:lotti/features/ai/ui/unified_ai_progress_view.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';

/// A wrapper widget for AiResponseSummary that automatically fetches
/// the latest AI response using LatestSummaryController.
class LatestAiResponseSummary extends ConsumerWidget {
  const LatestAiResponseSummary({
    required this.id,
    required this.aiResponseType,
    super.key,
  });

  final String id;
  final AiResponseType aiResponseType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestSummaryAsync = ref.watch(
      latestSummaryControllerProvider(
        id: id,
        aiResponseType: aiResponseType,
      ),
    );

    final inferenceStatus = ref.watch(
      inferenceStatusControllerProvider(
        id: id,
        aiResponseType: aiResponseType,
      ),
    );

    final isRunning = inferenceStatus == InferenceStatus.running;

    void showThoughtsModal(String promptId) {
      // Trigger a new inference run by invalidating the controller
      ref.read(
        triggerNewInferenceProvider(
          entityId: id,
          promptId: promptId,
        ),
      );

      ModalUtils.showSinglePageModal<void>(
        context: context,
        title: context.messages.aiAssistantThinking,
        builder: (_) => UnifiedAiProgressView(
          entityId: id,
          promptId: promptId,
        ),
      );
    }

    // TODO: implement showing if the latest summary is outdated
    const isOutdated = false;

    final dividerColor = context.colorScheme.outline.withAlpha(60);

    return latestSummaryAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Error loading AI summary: $error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
      data: (aiResponse) {
        if (aiResponse == null) {
          return const SizedBox.shrink();
        }

        final promptId = aiResponse.data.promptId;

        return Column(
          children: [
            if (isRunning)
              Row(
                children: [
                  Text(
                    context.messages.aiTaskSummaryRunning,
                    style: context.textTheme.titleSmall?.copyWith(
                      color: context.colorScheme.outline,
                    ),
                  ),
                  IconButton(
                    onPressed: promptId != null
                        ? () => showThoughtsModal(promptId)
                        : null,
                    icon: const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],
              ),
            if (!isRunning)
              Row(
                children: [
                  Text(
                    context.messages.aiTaskSummaryTitle,
                    style: context.textTheme.titleSmall?.copyWith(
                      color: context.colorScheme.outline,
                    ),
                  ),
                  if (promptId != null) ...[
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: context.colorScheme.outline,
                      ),
                      onPressed: () => showThoughtsModal(promptId),
                    ),
                    if (isOutdated)
                      // ignore: dead_code
                      Text(
                        context.messages.checklistSuggestionsOutdated,
                        style: context.textTheme.titleSmall
                            ?.copyWith(color: Colors.red),
                      ),
                  ],
                ],
              ),
            if (!isRunning)
              AiResponseSummary(
                aiResponse,
                linkedFromId: id,
                fadeOut: false,
              ),
            const SizedBox(height: 20),
            Divider(color: dividerColor),
          ],
        );
      },
    );
  }
}
