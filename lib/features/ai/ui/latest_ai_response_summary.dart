import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/latest_summary_controller.dart';
import 'package:lotti/features/ai/ui/ai_response_summary.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';

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
    extends ConsumerState<LatestAiResponseSummary> {
  AiResponseEntry? _previousResponse;

  @override
  Widget build(BuildContext context) {
    final latestSummaryAsync = ref.watch(
      latestSummaryControllerProvider((
        id: widget.id,
        aiResponseType: widget.aiResponseType,
      )),
    );

    final inferenceStatus = ref.watch(
      inferenceStatusControllerProvider(
        id: widget.id,
        aiResponseType: widget.aiResponseType,
      ),
    );

    final isRunning = inferenceStatus == InferenceStatus.running;

    return latestSummaryAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) {
        // Log the actual error for debugging
        DevLogger.error(
          name: 'LatestAiResponseSummary',
          message: 'Error loading AI summary',
          error: error,
        );

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
        // Update previous response when we get a new one and it's not running.
        // Clear it when the response is null and not running (e.g. after
        // bulk deletion) so we don't keep showing a stale summary.
        if (!isRunning) {
          if (aiResponse != null && aiResponse != _previousResponse) {
            _previousResponse = aiResponse;
          } else if (aiResponse == null) {
            _previousResponse = null;
          }
        }

        // Use the current response if available, otherwise use the previous one
        final displayResponse = aiResponse ?? _previousResponse;

        if (displayResponse == null) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            // Header with title and spinner/delete button
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.messages.aiTaskSummaryTitle,
                    style: context.textTheme.titleSmall?.copyWith(
                      color: context.colorScheme.outline,
                    ),
                  ),
                ),
                if (isRunning)
                  const IconButton(
                    onPressed: null,
                    icon: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (!isRunning)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: context.colorScheme.outline,
                    ),
                    tooltip: context.messages.aiTaskSummaryDeleteTooltip,
                    onPressed: () => _showDeleteConfirmation(
                      context,
                      ref,
                      widget.id,
                      widget.aiResponseType,
                    ),
                  ),
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

Future<void> _showDeleteConfirmation(
  BuildContext context,
  WidgetRef ref,
  String taskId,
  AiResponseType aiResponseType,
) async {
  final summaries = await allAiResponses(
    ref,
    id: taskId,
    aiResponseType: aiResponseType,
  );

  final count = summaries.length;
  if (count == 0 || !context.mounted) return;

  // Read provider before the async gap to avoid accessing after unmount.
  final journalRepository = ref.read(journalRepositoryProvider);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.messages.aiTaskSummaryDeleteConfirmTitle),
      content: Text(
        context.messages.aiTaskSummaryDeleteConfirmMessage(count),
      ),
      actions: [
        LottiTertiaryButton(
          onPressed: () => Navigator.of(context).pop(false),
          label: context.messages.cancelButton,
        ),
        LottiPrimaryButton(
          onPressed: () => Navigator.of(context).pop(true),
          label: context.messages.deleteButton,
          icon: Icons.delete_forever_outlined,
          isDestructive: true,
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await Future.wait(
      summaries.map(
        (summary) => journalRepository.deleteJournalEntity(summary.meta.id),
      ),
    );
  }
}
