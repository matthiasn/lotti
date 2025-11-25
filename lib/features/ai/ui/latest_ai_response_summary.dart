import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/direct_task_summary_refresh_controller.dart';
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
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  void _stopCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  String _formatCountdown(Duration remaining) {
    if (remaining.isNegative) return '0:00';
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

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

    final scheduledTime = ref.watch(
      scheduledTaskSummaryRefreshProvider(taskId: widget.id),
    );

    final isRunning = inferenceStatus == InferenceStatus.running;
    final isScheduled = scheduledTime != null;

    // Manage countdown timer based on scheduled state
    if (isScheduled && _countdownTimer == null) {
      _startCountdownTimer();
    } else if (!isScheduled && _countdownTimer != null) {
      _stopCountdownTimer();
    }

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

    void cancelScheduledRefresh() {
      ref
          .read(directTaskSummaryRefreshControllerProvider.notifier)
          .cancelScheduledRefresh(widget.id);
    }

    Future<void> triggerImmediately() async {
      await ref
          .read(directTaskSummaryRefreshControllerProvider.notifier)
          .triggerImmediately(widget.id);
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

        // Calculate remaining time for countdown
        final remaining = isScheduled
            ? scheduledTime.difference(DateTime.now())
            : Duration.zero;

        return Column(
          children: [
            // Header with title and spinner/refresh button
            Row(
              children: [
                Expanded(
                  child: Text(
                    _getHeaderText(
                      context,
                      isRunning: isRunning,
                      isScheduled: isScheduled,
                      remaining: remaining,
                    ),
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
                if (isScheduled && !isRunning) ...[
                  // Cancel button
                  IconButton(
                    onPressed: cancelScheduledRefresh,
                    tooltip: context.messages.aiTaskSummaryCancelScheduled,
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: context.colorScheme.outline,
                    ),
                  ),
                  // Trigger now button
                  IconButton(
                    onPressed: triggerImmediately,
                    tooltip: context.messages.aiTaskSummaryTriggerNow,
                    icon: Icon(
                      Icons.play_arrow,
                      size: 18,
                      color: context.colorScheme.outline,
                    ),
                  ),
                ],
                if (!isRunning && !isScheduled && promptId != null) ...[
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

  String _getHeaderText(
    BuildContext context, {
    required bool isRunning,
    required bool isScheduled,
    required Duration remaining,
  }) {
    if (isRunning) {
      return context.messages.aiTaskSummaryRunning;
    }
    if (isScheduled) {
      return context.messages
          .aiTaskSummaryScheduled(_formatCountdown(remaining));
    }
    return context.messages.aiTaskSummaryTitle;
  }
}
