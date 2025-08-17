import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/latest_summary_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/ai_response_summary.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// A wrapper widget for AiResponseSummary that automatically fetches
/// the latest AI response using LatestSummaryController.
class LatestAiResponseSummary extends ConsumerStatefulWidget {
  const LatestAiResponseSummary({
    required this.id,
    required this.aiResponseType,
    super.key,
  });

  final String id;
  final AiResponseType aiResponseType;

  @override
  ConsumerState<LatestAiResponseSummary> createState() =>
      _LatestAiResponseSummaryState();
}

class _LatestAiResponseSummaryState
    extends ConsumerState<LatestAiResponseSummary>
    with SingleTickerProviderStateMixin {
  AiResponseEntry? _previousResponse;

  @override
  Widget build(BuildContext context) {
    final latestSummaryAsync = ref.watch(
      latestSummaryControllerProvider(
        id: widget.id,
        aiResponseType: widget.aiResponseType,
      ),
    );

    final inferenceStatus = ref.watch(
      inferenceStatusControllerProvider(
        id: widget.id,
        aiResponseType: widget.aiResponseType,
      ),
    );

    final isRunning = inferenceStatus == InferenceStatus.running;

    Future<void> triggerRefresh(String? promptId) async {
      if (promptId == null) return;

      // Just trigger the inference without showing a modal
      // The animation at the bottom will be shown automatically
      await ref.read(
        triggerNewInferenceProvider(
          entityId: widget.id,
          promptId: promptId,
        ).future,
      );
    }

    // TODO: implement showing if the latest summary is outdated
    const isOutdated = false;

    return latestSummaryAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) {
        // Log the actual error for debugging (without stack trace to avoid cluttering test output)
        debugPrint('Error loading AI summary: $error');

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Failed to load AI summary. Please try again.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        );
      },
      data: (aiResponse) {
        // Update previous response when we get a new one and it's not running
        if (!isRunning &&
            aiResponse != null &&
            aiResponse != _previousResponse) {
          _previousResponse = aiResponse;
        }

        // Use the current response if available, otherwise use the previous one
        final displayResponse = aiResponse ?? _previousResponse;

        if (displayResponse == null) {
          return const SizedBox.shrink();
        }

        final promptId = displayResponse.data.promptId;

        return Column(
          children: [
            // Header with title and spinner/refresh button
            Row(
              children: [
                Text(
                  isRunning
                      ? context.messages.aiTaskSummaryRunning
                      : context.messages.aiTaskSummaryTitle,
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.outline,
                  ),
                ),
                if (isRunning)
                  IconButton(
                    onPressed: promptId != null
                        ? () => triggerRefresh(promptId)
                        : null,
                    icon: const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (!isRunning && promptId != null) ...[
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: context.colorScheme.outline,
                    ),
                    onPressed: () => triggerRefresh(promptId),
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
            // Animated content with fade transition and size animation
            AnimatedSize(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: AiResponseSummary(
                  displayResponse,
                  key: ValueKey(displayResponse.meta.id),
                  linkedFromId: widget.id,
                  fadeOut: false,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }
}
