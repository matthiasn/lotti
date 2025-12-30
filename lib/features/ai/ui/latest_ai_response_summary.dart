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
import 'package:lotti/services/dev_logger.dart';
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

    final scheduledTime = ref.watch(
      scheduledTaskSummaryRefreshProvider(taskId: widget.id),
    );

    final isRunning = inferenceStatus == InferenceStatus.running;
    final isScheduled = scheduledTime != null;

    Future<void> triggerRefresh(String? promptId) async {
      if (promptId == null) return;

      // Just trigger the inference without showing a modal
      // The animation at the bottom will be shown automatically
      await ref.read(
        triggerNewInferenceProvider((
          entityId: widget.id,
          promptId: promptId,
          linkedEntityId: null,
        )).future,
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
                Expanded(
                  child: _HeaderText(
                    isRunning: isRunning,
                    scheduledTime: scheduledTime,
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
}

/// Separate widget for the header text that uses StreamBuilder
/// to update the countdown display without rebuilding the parent widget.
///
/// Design decisions (based on code review feedback):
/// - Uses StreamBuilder instead of setState to scope rebuilds to just this widget
/// - Timer managed in initState/didUpdateWidget/dispose, not in build method
/// - Stream emits every second only when a refresh is scheduled
/// - No side effects in build method - just pure widget construction
class _HeaderText extends StatefulWidget {
  const _HeaderText({
    required this.isRunning,
    required this.scheduledTime,
  });

  /// Whether inference is currently running (shows "Thinking..." text)
  final bool isRunning;

  /// The scheduled refresh time, or null if no refresh is scheduled.
  /// When non-null, shows countdown like "Summary in 4:32"
  final DateTime? scheduledTime;

  @override
  State<_HeaderText> createState() => _HeaderTextState();
}

class _HeaderTextState extends State<_HeaderText> {
  /// Stream controller that emits a tick every second for countdown updates
  StreamController<void>? _tickController;

  /// Timer that fires every second to update the countdown display
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _setupTimerIfNeeded();
  }

  @override
  void didUpdateWidget(_HeaderText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update timer when scheduled state changes (not on every rebuild)
    if (oldWidget.scheduledTime != widget.scheduledTime) {
      _setupTimerIfNeeded();
    }
  }

  /// Sets up or tears down the countdown timer based on scheduled state.
  /// Called from initState and didUpdateWidget to keep timer lifecycle
  /// properly managed outside of the build method.
  void _setupTimerIfNeeded() {
    // Clean up any existing timer/stream
    _timer?.cancel();
    _tickController?.close();

    // Only create timer when we have a scheduled refresh to display
    if (widget.scheduledTime != null) {
      _tickController = StreamController<void>.broadcast();
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          if (mounted) {
            _tickController?.add(null);
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tickController?.close();
    super.dispose();
  }

  String _formatCountdown(Duration remaining) {
    if (remaining.isNegative) return '0:00';
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // If running, show running text (no stream needed)
    if (widget.isRunning) {
      return Text(
        context.messages.aiTaskSummaryRunning,
        style: context.textTheme.titleSmall?.copyWith(
          color: context.colorScheme.outline,
        ),
      );
    }

    // If scheduled, use StreamBuilder to update countdown only
    if (widget.scheduledTime != null && _tickController != null) {
      return StreamBuilder<void>(
        stream: _tickController!.stream,
        builder: (context, _) {
          final remaining = widget.scheduledTime!.difference(DateTime.now());
          return Text(
            context.messages
                .aiTaskSummaryScheduled(_formatCountdown(remaining)),
            style: context.textTheme.titleSmall?.copyWith(
              color: context.colorScheme.outline,
            ),
          );
        },
      );
    }

    // Default: show title text
    return Text(
      context.messages.aiTaskSummaryTitle,
      style: context.textTheme.titleSmall?.copyWith(
        color: context.colorScheme.outline,
      ),
    );
  }
}
