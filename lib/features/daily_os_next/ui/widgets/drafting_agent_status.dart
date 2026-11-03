import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_wake_progress.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// What the drafting wake is actually doing, read from the day agent's live
/// progress — the step it is in and for how long, the model, token counts,
/// per-step timings, tool calls, and any failed attempt the outbox is
/// retrying.
///
/// A finished wake or a settled job outcome older than [requestedAt] belongs
/// to an earlier request and is ignored, so a re-draft never shows the last
/// run's numbers. A wake still running, or an attempt still waiting to retry,
/// is shown whenever it began: reopening drafting attaches to that in-flight
/// work. While [active], the elapsed times tick once a second.
class DraftingAgentStatus extends ConsumerStatefulWidget {
  const DraftingAgentStatus({
    required this.dayId,
    required this.requestedAt,
    required this.active,
    super.key,
  });

  final String dayId;
  final DateTime requestedAt;
  final bool active;

  /// The four coarse stages the chips show, in order.
  static List<String> stagesOf(AppLocalizations messages) => [
    messages.dailyOsNextDraftingProgressQueued,
    messages.dailyOsNextDraftingProgressReading,
    messages.dailyOsNextDraftingProgressBlocks,
    messages.dailyOsNextDraftingProgressSaving,
  ];

  /// The chip index [wake] is in: 0 before any wake started, one past the
  /// last chip once the wake completed.
  static int stageIndexOf(DayAgentWakeProgress? wake) {
    if (wake == null) return 0;
    // A failed wake stays on the stage it failed in: the step closed by the
    // move to `failed` is the last completed one.
    final step = wake.step == DayAgentWakeStep.failed
        ? (wake.completedSteps.isEmpty
              ? DayAgentWakeStep.preparingContext
              : wake.completedSteps.last.step)
        : wake.step;
    return switch (step) {
      DayAgentWakeStep.preparingContext ||
      DayAgentWakeStep.compactingMemory ||
      DayAgentWakeStep.assemblingPrompt => 1,
      DayAgentWakeStep.callingModel || DayAgentWakeStep.runningTool => 2,
      DayAgentWakeStep.saving || DayAgentWakeStep.failed => 3,
      DayAgentWakeStep.completed => 4,
    };
  }

  /// Stable keys for tests.
  @visibleForTesting
  static const Key statusLineKey = ValueKey('drafting-agent-status-line');
  @visibleForTesting
  static const Key internalsKey = ValueKey('drafting-agent-internals');

  @override
  ConsumerState<DraftingAgentStatus> createState() =>
      _DraftingAgentStatusState();
}

class _DraftingAgentStatusState extends ConsumerState<DraftingAgentStatus> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(DraftingAgentStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && _ticker == null) {
      _start();
    } else if (!widget.active) {
      _stop();
    }
  }

  void _start() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final live = ref.watch(dayAgentLiveStatusProvider(widget.dayId)).value;
    final wake = live?.wake;
    final attempt = live?.lastAttempt;
    // Only settled progress from before this request is stale. A wake still
    // running, or an attempt still waiting to retry, is the work this screen
    // waits on even when it began earlier — reopening drafting attaches to the
    // in-flight job rather than starting a new one.
    final currentWake =
        wake != null &&
            (!wake.isFinished || !wake.startedAt.isBefore(widget.requestedAt))
        ? wake
        : null;
    final currentAttempt =
        attempt != null &&
            (attempt.willRetry ||
                !attempt.updatedAt.isBefore(widget.requestedAt))
        ? attempt
        : null;
    final now = clock.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _statusLine(context, currentWake, currentAttempt, now),
          key: DraftingAgentStatus.statusLineKey,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
        _StageChips(activeIndex: DraftingAgentStatus.stageIndexOf(currentWake)),
        if (currentWake != null || currentAttempt != null) ...[
          SizedBox(height: tokens.spacing.step5),
          _AgentInternals(wake: currentWake, attempt: currentAttempt, now: now),
        ],
      ],
    );
  }

  String _statusLine(
    BuildContext context,
    DayAgentWakeProgress? wake,
    DayAgentJobAttempt? attempt,
    DateTime now,
  ) {
    final messages = context.messages;
    final retryAt = attempt?.nextAttemptAt;
    final awaitingRetry =
        attempt != null &&
        attempt.willRetry &&
        retryAt != null &&
        (wake == null || wake.isFinished);
    if (awaitingRetry) {
      final remaining = retryAt.isAfter(now)
          ? retryAt.difference(now)
          : Duration.zero;
      return messages.dailyOsNextDraftingStepRetrying(
        _wholeSeconds(context, remaining),
      );
    }
    if (wake == null) {
      return _withElapsed(
        context,
        messages.dailyOsNextDraftingStepWaiting,
        now.difference(widget.requestedAt),
      );
    }
    final label = switch (wake.step) {
      DayAgentWakeStep.preparingContext =>
        messages.dailyOsNextDraftingStepContext,
      DayAgentWakeStep.compactingMemory =>
        messages.dailyOsNextDraftingStepMemory,
      DayAgentWakeStep.assemblingPrompt =>
        messages.dailyOsNextDraftingStepPrompt,
      DayAgentWakeStep.callingModel => messages.dailyOsNextDraftingStepModel(
        wake.turns.length,
      ),
      DayAgentWakeStep.runningTool => messages.dailyOsNextDraftingStepTool(
        wake.toolCalls.isEmpty ? '' : wake.toolCalls.last.name,
      ),
      DayAgentWakeStep.saving => messages.dailyOsNextDraftingStepSaving,
      DayAgentWakeStep.completed => messages.dailyOsNextDraftingStepDone,
      DayAgentWakeStep.failed => messages.dailyOsNextDraftingStepFailed,
    };
    if (wake.isFinished) return label;
    return _withElapsed(context, label, now.difference(wake.stepStartedAt));
  }

  String _withElapsed(BuildContext context, String label, Duration elapsed) =>
      '$label · ${context.messages.dailyOsNextDraftingSeconds(_wholeSeconds(context, elapsed))}';
}

String _wholeSeconds(BuildContext context, Duration duration) =>
    NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    ).format(duration.inSeconds);

String _tenthsOfSeconds(BuildContext context, Duration duration) =>
    context.messages.dailyOsNextDraftingSeconds(
      NumberFormat(
        '0.0',
        Localizations.localeOf(context).toString(),
      ).format(duration.inMilliseconds / 1000),
    );

/// The agent internals readout: model, tokens, per-step time, tool calls and
/// the attempt counter. Low emphasis — the status line above stays the
/// element the eye lands on.
class _AgentInternals extends StatelessWidget {
  const _AgentInternals({
    required this.wake,
    required this.attempt,
    required this.now,
  });

  final DayAgentWakeProgress? wake;
  final DayAgentJobAttempt? attempt;
  final DateTime now;

  static const List<DayAgentWakeStep> _timedSteps = [
    DayAgentWakeStep.preparingContext,
    DayAgentWakeStep.compactingMemory,
    DayAgentWakeStep.assemblingPrompt,
    DayAgentWakeStep.callingModel,
    DayAgentWakeStep.runningTool,
    DayAgentWakeStep.saving,
  ];

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final locale = Localizations.localeOf(context).toString();
    final count = NumberFormat.decimalPattern(locale);
    final wake = this.wake;
    final attempt = this.attempt;

    String stepName(DayAgentWakeStep step) => switch (step) {
      DayAgentWakeStep.preparingContext =>
        messages.dailyOsNextDraftingTimingContext,
      DayAgentWakeStep.compactingMemory =>
        messages.dailyOsNextDraftingTimingMemory,
      DayAgentWakeStep.assemblingPrompt =>
        messages.dailyOsNextDraftingTimingPrompt,
      DayAgentWakeStep.callingModel => messages.dailyOsNextDraftingTimingModel,
      DayAgentWakeStep.runningTool => messages.dailyOsNextDraftingTimingTools,
      _ => messages.dailyOsNextDraftingTimingSaving,
    };

    String timing(DayAgentWakeProgress wake, DayAgentWakeStep step) {
      final elapsed = _tenthsOfSeconds(context, wake.timeIn(step, now: now));
      return '${stepName(step)} $elapsed';
    }

    String toolCall(DayAgentToolCallTiming call) {
      final elapsed = call.elapsed;
      if (elapsed == null) return '${call.name} …';
      final failed = call.succeeded == false ? ' ✕' : '';
      return '${call.name} ${_tenthsOfSeconds(context, elapsed)}$failed';
    }

    final rows = <(String, String)>[
      if (wake?.modelId case final model?)
        (messages.dailyOsNextDraftingInternalsModel, model),
      if (wake != null && (wake.inputTokens > 0 || wake.outputTokens > 0))
        (
          messages.dailyOsNextDraftingInternalsTokens,
          messages.dailyOsNextDraftingInternalsTokensValue(
            count.format(wake.inputTokens),
            count.format(wake.outputTokens),
          ),
        ),
      if (wake != null)
        (
          messages.dailyOsNextDraftingInternalsTime,
          [
            for (final step in _timedSteps)
              if (wake.timeIn(step, now: now) > Duration.zero ||
                  wake.step == step)
                timing(wake, step),
          ].join(' · '),
        ),
      if (wake != null && wake.toolCalls.isNotEmpty)
        (
          messages.dailyOsNextDraftingInternalsTools,
          [
            for (final call in wake.toolCalls) toolCall(call),
          ].join(', '),
        ),
      if (attempt != null && attempt.attempts > 0)
        (
          messages.dailyOsNextDraftingInternalsAttempt(
            (attempt.willRetry ? attempt.attempts + 1 : attempt.attempts).clamp(
              1,
              attempt.maxAttempts,
            ),
            attempt.maxAttempts,
          ),
          attempt.lastError == null
              ? ''
              : messages.dailyOsNextDraftingInternalsLastError(
                  _shorten(attempt.lastError!),
                ),
        ),
    ];

    final tokens = context.designTokens;
    final labelStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final valueStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    return Column(
      key: DraftingAgentStatus.internalsKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.step1),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: label, style: labelStyle),
                  if (value.isNotEmpty) ...[
                    const TextSpan(text: '  '),
                    TextSpan(text: value, style: valueStyle),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _shorten(String text) {
    const limit = 160;
    final singleLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return singleLine.length <= limit
        ? singleLine
        : '${singleLine.substring(0, limit)}…';
  }
}

class _StageChips extends StatelessWidget {
  const _StageChips({required this.activeIndex});

  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final stages = DraftingAgentStatus.stagesOf(context.messages);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      children: [
        for (var i = 0; i < stages.length; i++)
          _StageChip(
            label: stages[i],
            state: i < activeIndex
                ? _StageChipState.done
                : i == activeIndex
                ? _StageChipState.active
                : _StageChipState.pending,
          ),
      ],
    );
  }
}

enum _StageChipState { done, active, pending }

class _StageChip extends StatelessWidget {
  const _StageChip({required this.label, required this.state});

  final String label;
  final _StageChipState state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final active = state == _StageChipState.active;
    final done = state == _StageChipState.done;
    final color = active || done
        ? tokens.colors.interactive.enabled
        : tokens.colors.text.lowEmphasis;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? tokens.colors.interactive.enabled.withValues(alpha: 0.12)
            : tokens.colors.surface.enabled,
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        border: Border.all(
          color: active
              ? tokens.colors.interactive.enabled.withValues(alpha: 0.36)
              : tokens.colors.decorative.level01,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step3,
          vertical: tokens.spacing.step2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              done ? LottiIcons.confirm : LottiIcons.radioUnselected,
              size: tokens.spacing.step3,
              color: color,
            ),
            SizedBox(width: tokens.spacing.step2),
            Text(
              label,
              style: tokens.typography.styles.others.caption.copyWith(
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
