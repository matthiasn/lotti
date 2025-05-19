import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/latest_summary_controller.dart';
import 'package:lotti/features/ai/ui/ai_response_summary.dart';
import 'package:lotti/features/ai/ui/task_summary/ai_task_summary_view.dart';
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
        aiResponseType: AiResponseType.taskSummary,
      ),
    );

    final isRunning = inferenceStatus == InferenceStatus.running;

    void showThoughtsModal() {
      ModalUtils.showSinglePageModal<void>(
        context: context,
        title: context.messages.aiAssistantThinking,
        builder: (_) => AiTaskSummaryView(id: id),
      );
    }

    final isOutdated = ref
            .watch(
              isLatestSummaryOutdatedControllerProvider(
                id: id,
                aiResponseType: aiResponseType,
              ),
            )
            .valueOrNull ??
        false;

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
                    onPressed: showThoughtsModal,
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
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: context.colorScheme.outline,
                    ),
                    onPressed: showThoughtsModal,
                  ),
                  if (isOutdated)
                    Text(
                      context.messages.checklistSuggestionsOutdated,
                      style: context.textTheme.titleSmall?.copyWith(
                        color: Colors.red,
                      ),
                    ),
                ],
              ),
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
