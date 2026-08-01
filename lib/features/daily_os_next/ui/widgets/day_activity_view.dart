import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/services/day_activity_repository.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/state/day_activity_provider.dart';
import 'package:lotti/features/daily_os_next/state/day_processing_runtime_provider.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/time_spent_card.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;

class DayActivityView extends ConsumerWidget {
  const DayActivityView({
    required this.date,
    required this.hasPlan,
    required this.onUseEntry,
    required this.actualBlocks,
    super.key,
  });

  final DateTime date;
  final bool hasPlan;
  final ValueChanged<DayActivityEntry> onUseEntry;
  final List<TimeBlock> actualBlocks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(dayActivityProvider(date));
    return activity.when(
      skipLoadingOnReload: true,
      skipError: true,
      data: (entries) => entries.isEmpty && actualBlocks.isEmpty
          ? const _ActivityEmptyState()
          : ListView.separated(
              reverse: true,
              padding: EdgeInsets.all(context.designTokens.spacing.step5),
              itemCount: entries.length + (actualBlocks.isEmpty ? 0 : 1),
              separatorBuilder: (_, _) => SizedBox(
                height: context.designTokens.spacing.step4,
              ),
              itemBuilder: (context, index) {
                if (index == entries.length) {
                  return TimeSpentCard(blocks: actualBlocks, compact: true);
                }
                final entry = entries[entries.length - 1 - index];
                return _ActivityCard(
                  entry: entry,
                  hasPlan: hasPlan,
                  onUse: () => onUseEntry(entry),
                  onRetry: entry.processingJob == null
                      ? null
                      : () => _retry(ref, entry.processingJob!.id),
                  onDelete:
                      entry.kind != DayActivityEntryKind.recording ||
                          entry.isSubmitted
                      ? null
                      : () => _delete(context, ref, entry),
                );
              },
            ),
      error: (_, _) => _ActivityErrorState(
        onRetry: () => ref.invalidate(dayActivityProvider(date)),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Future<void> _retry(WidgetRef ref, String jobId) async {
    await ref.read(dayProcessingOutboxRepositoryProvider).retryNow(jobId);
    await ref.read(dayProcessingRuntimeProvider).nudge();
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    DayActivityEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          dialogContext.messages.dailyOsNextActivityDeleteDialogTitle,
        ),
        content: Text(
          dialogContext.messages.dailyOsNextActivityDeleteDialogBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              dialogContext.messages.dailyOsNextDayDeleteDialogCancel,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(
                dialogContext,
              ).colorScheme.errorContainer,
              foregroundColor: Theme.of(
                dialogContext,
              ).colorScheme.onErrorContainer,
            ),
            child: Text(
              dialogContext.messages.dailyOsNextDayDeleteDialogConfirm,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // Cancel first so a background worker cannot attach a transcript to an
    // entry that is about to disappear; the journal soft delete then hides
    // the recording from every day projection.
    final jobId = entry.processingJob?.id;
    if (jobId != null) {
      await ref.read(dayProcessingOutboxRepositoryProvider).cancel(jobId);
    }
    final audioId = entry.audio?.meta.id ?? entry.processingJob?.audioId;
    if (audioId != null) {
      await ref.read(journalRepositoryProvider).deleteJournalEntity(audioId);
    }
    ref.invalidate(dayActivityProvider);
  }
}

class _ActivityErrorState extends StatelessWidget {
  const _ActivityErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.messages.dailyOsNextActivityLoadFailed,
              textAlign: TextAlign.center,
              style: tokens.typography.styles.body.bodyMedium,
            ),
            SizedBox(height: tokens.spacing.step4),
            DesignSystemButton(
              label: context.messages.dailyOsNextActivityRetryLoad,
              onPressed: onRetry,
              variant: DesignSystemButtonVariant.secondary,
              leadingIcon: Icons.refresh_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityEmptyState extends StatelessWidget {
  const _ActivityEmptyState();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timeline_rounded,
              color: tokens.colors.text.lowEmphasis,
            ),
            SizedBox(height: tokens.spacing.step3),
            Text(
              context.messages.dailyOsNextActivityEmpty,
              textAlign: TextAlign.center,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.entry,
    required this.hasPlan,
    required this.onUse,
    this.onRetry,
    this.onDelete,
  });

  final DayActivityEntry entry;
  final bool hasPlan;
  final VoidCallback onUse;
  final Future<void> Function()? onRetry;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final transcript = entry.transcript;
    final status = _status(context, entry);
    // Unsubmitted recordings edit their text in place through the shared
    // journal editor; the editor renders the saved wording itself, so the
    // plain transcript line only appears while there is nothing to edit yet.
    final inlineEditorEntryId =
        entry.kind == DayActivityEntryKind.recording && !entry.isSubmitted
        ? entry.audio?.meta.id
        : null;
    final editorShowsText =
        inlineEditorEntryId != null &&
        (entry.audio?.entryText?.plainText.trim().isNotEmpty ?? false);
    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      padding: EdgeInsets.all(tokens.spacing.step5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                switch (entry.kind) {
                  DayActivityEntryKind.plan => Icons.auto_awesome_rounded,
                  DayActivityEntryKind.summary => Icons.summarize_rounded,
                  DayActivityEntryKind.checkIn => Icons.notes_rounded,
                  DayActivityEntryKind.recording => Icons.mic_none_rounded,
                  DayActivityEntryKind.agentJob => Icons.error_outline_rounded,
                },
                color: entry.kind == DayActivityEntryKind.agentJob
                    ? tokens.colors.text.lowEmphasis
                    : tokens.colors.interactive.enabled,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Text(
                  _formatTime(context, entry.createdAt),
                  style: calmEyebrowStyle(tokens),
                ),
              ),
              Text(
                status,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ],
          ),
          if (!editorShowsText) ...[
            SizedBox(height: tokens.spacing.step3),
            Text(
              _body(context, entry, transcript),
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: transcript == null
                    ? tokens.colors.text.lowEmphasis
                    : tokens.colors.text.highEmphasis,
              ),
            ),
          ],
          if (entry.kind == DayActivityEntryKind.agentJob) ...[
            SizedBox(height: tokens.spacing.step2),
            Text(
              '${_agentFailureDetail(context, entry)} '
              '${context.messages.dailyOsNextActivityAgentJobRetryHint}',
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ],
          // Agent rows deliberately omit the raw provider string: it is
          // hard-coded English written for a log, and this card is fully
          // localized everywhere else. The durable text stays on the job for
          // diagnostics.
          if (entry.processingJob case final job?
              when entry.kind != DayActivityEntryKind.agentJob &&
                  job.lastError != null &&
                  job.status != DayProcessingJobStatus.succeeded) ...[
            SizedBox(height: tokens.spacing.step2),
            Text(
              job.lastError!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ],
          if (entry.audio case final audio?
              when entry.audioAvailableLocally != false) ...[
            SizedBox(height: tokens.spacing.step4),
            AudioPlayerWidget(audio),
          ],
          if (inlineEditorEntryId != null) ...[
            SizedBox(height: tokens.spacing.step3),
            EditorWidget(
              entryId: inlineEditorEntryId,
              margin: EdgeInsets.zero,
            ),
          ],
          if (onDelete != null ||
              entry.processingJob?.lastFailureClass ==
                  DayProcessingFailureClass.setupRequired ||
              _canRetry(entry) ||
              transcript != null) ...[
            SizedBox(height: tokens.spacing.step4),
            Wrap(
              spacing: tokens.spacing.step3,
              runSpacing: tokens.spacing.step3,
              children: [
                if (_canRetry(entry))
                  _AsyncActivityButton(
                    label: context.messages.dailyOsNextActivityRetry,
                    action: onRetry!,
                    // A draft job has no recording to reassure the user about.
                    failureMessage: entry.kind == DayActivityEntryKind.agentJob
                        ? context.messages.dailyOsNextActivityAgentActionFailed
                        : null,
                    variant: DesignSystemButtonVariant.secondary,
                    leadingIcon: Icons.refresh_rounded,
                  ),
                if (entry.processingJob?.lastFailureClass ==
                    DayProcessingFailureClass.setupRequired)
                  DesignSystemButton(
                    // A planning job blocked on setup needs the Daily OS
                    // profile binding, which lives in Daily OS settings — the
                    // generic AI list can create a profile but never assigns
                    // one, so it would leave the job just as blocked.
                    label: entry.kind == DayActivityEntryKind.agentJob
                        ? context.messages.dailyOsNextActivityOpenAiSetup
                        : context.messages.dailyOsNextActivityOpenSetup,
                    onPressed: () => nav_service.beamToNamed(
                      entry.kind == DayActivityEntryKind.agentJob
                          ? '/settings/daily-os'
                          : '/settings/ai',
                    ),
                    variant: DesignSystemButtonVariant.secondary,
                    leadingIcon: Icons.settings_rounded,
                  ),
                if (transcript != null)
                  DesignSystemButton(
                    label: hasPlan
                        ? context.messages.dailyOsNextActivityUseToRefine
                        : context.messages.dailyOsNextActivityUseToPlan,
                    onPressed: onUse,
                    leadingIcon: Icons.auto_awesome_rounded,
                  ),
                if (onDelete != null)
                  _AsyncActivityButton(
                    label: context.messages.dailyOsNextActivityDeleteRecording,
                    action: onDelete!,
                    variant: DesignSystemButtonVariant.secondary,
                    leadingIcon: Icons.delete_outline_rounded,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// The card's main line: the entity's own wording when it has one, else an
  /// explanation of what this row is waiting on, in the user's language.
  String _body(
    BuildContext context,
    DayActivityEntry entry,
    String? transcript,
  ) {
    final dayLabel = entry.plan?.data.dayLabel;
    if (dayLabel != null) return dayLabel;
    final summary = entry.summary?.text;
    if (summary != null) return summary;
    if (entry.kind == DayActivityEntryKind.agentJob) {
      // Named by what the user asked for, not by the job kind's identifier —
      // "refinePlan failed" is a log line, not an explanation.
      return switch (entry.processingJob?.kind) {
        DayProcessingJobKind.draftPlan =>
          context.messages.dailyOsNextActivityAgentJobDraft,
        DayProcessingJobKind.refinePlan =>
          context.messages.dailyOsNextActivityAgentJobRefine,
        _ => context.messages.dailyOsNextActivityAgentJobParse,
      };
    }
    if (entry.kind == DayActivityEntryKind.plan) {
      return context.messages.dailyOsNextActivityPlanAvailable;
    }
    return switch (entry.processingJob?.lastFailureClass) {
      DayProcessingFailureClass.missingAsset =>
        context.messages.dailyOsNextActivityMissingAudio,
      DayProcessingFailureClass.setupRequired =>
        context.messages.dailyOsNextActivitySetupRequired,
      _ => transcript ?? context.messages.dailyOsNextActivityTranscriptPending,
    };
  }

  /// Why a stalled agent job stopped, in the user's language.
  ///
  /// Mapped from the durable failure class rather than from the provider's
  /// own message, which is hard-coded English meant for a log.
  String _agentFailureDetail(BuildContext context, DayActivityEntry entry) =>
      switch (entry.processingJob?.lastFailureClass) {
        DayProcessingFailureClass.setupRequired =>
          context.messages.dailyOsNextActivityAgentJobSetupRequired,
        DayProcessingFailureClass.network ||
        DayProcessingFailureClass.timeout ||
        DayProcessingFailureClass.providerBusy =>
          context.messages.dailyOsNextActivityAgentJobTemporary,
        _ => context.messages.dailyOsNextActivityAgentJobModelFailed,
      };

  bool _canRetry(DayActivityEntry entry) {
    // Queued jobs sit under exponential backoff; the user must always be
    // able to force the next attempt instead of waiting it out.
    return switch (entry.processingJob?.status) {
      DayProcessingJobStatus.queued ||
      DayProcessingJobStatus.waitingForNetwork ||
      DayProcessingJobStatus.waitingForUser ||
      DayProcessingJobStatus.failed => true,
      _ => false,
    };
  }

  String _status(BuildContext context, DayActivityEntry entry) {
    if (entry.kind == DayActivityEntryKind.plan) {
      return context.messages.dailyOsNextActivityPlanCreated;
    }
    if (entry.kind == DayActivityEntryKind.summary) {
      return context.messages.dailyOsNextActivityDaySummary;
    }
    if (entry.isSubmitted) {
      return context.messages.dailyOsNextActivitySubmitted;
    }
    // An agent row exists only because its work stalled, so it never reports
    // the "Saved" resting state a recording falls back to.
    if (entry.kind == DayActivityEntryKind.agentJob &&
        entry.processingJob?.status ==
            DayProcessingJobStatus.waitingForNetwork) {
      return context.messages.dailyOsNextActivityWaitingForNetwork;
    }
    if (entry.kind == DayActivityEntryKind.agentJob) {
      return context.messages.dailyOsNextActivityNeedsAttention;
    }
    return switch (entry.processingJob?.status) {
      DayProcessingJobStatus.running =>
        context.messages.dailyOsNextActivityTranscribing,
      DayProcessingJobStatus.waitingForNetwork =>
        context.messages.dailyOsNextActivityWaitingForNetwork,
      DayProcessingJobStatus.waitingForUser || DayProcessingJobStatus.failed =>
        context.messages.dailyOsNextActivityNeedsAttention,
      DayProcessingJobStatus.succeeded =>
        context.messages.dailyOsNextActivityReady,
      _ => context.messages.dailyOsNextActivitySaved,
    };
  }

  String _formatTime(BuildContext context, DateTime value) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(value.toLocal()),
      );
}

class _AsyncActivityButton extends StatefulWidget {
  const _AsyncActivityButton({
    required this.label,
    required this.action,
    required this.variant,
    required this.leadingIcon,
    this.failureMessage,
  });

  final String label;
  final Future<void> Function() action;
  final DesignSystemButtonVariant variant;
  final IconData leadingIcon;

  /// Snackbar shown when [action] throws. Defaults to the recording-oriented
  /// copy, which is wrong on a row that has no recording behind it.
  final String? failureMessage;

  @override
  State<_AsyncActivityButton> createState() => _AsyncActivityButtonState();
}

class _AsyncActivityButtonState extends State<_AsyncActivityButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => DesignSystemButton(
    label: widget.label,
    onPressed: _run,
    isLoading: _busy,
    variant: widget.variant,
    leadingIcon: widget.leadingIcon,
  );

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.failureMessage ??
                  context.messages.dailyOsNextActivityActionFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
