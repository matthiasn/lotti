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
                  onRecover: entry.kind != DayActivityEntryKind.recovery
                      ? null
                      : () => _recover(
                          ref,
                          entry.recoveryManifest!.context.recordingSessionId,
                        ),
                  onEditText:
                      (entry.audio?.meta.id ?? entry.processingJob?.audioId) ==
                              null ||
                          entry.isSubmitted
                      ? null
                      : () => _editText(context, ref, entry),
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

  Future<void> _recover(WidgetRef ref, String recordingSessionId) async {
    await ref
        .read(dayAudioSpoolRecoveryServiceProvider)
        .recoverSession(recordingSessionId);
    await ref.read(dayProcessingRuntimeProvider).nudge();
  }

  Future<void> _editText(
    BuildContext context,
    WidgetRef ref,
    DayActivityEntry entry,
  ) async {
    final controller = TextEditingController(text: entry.transcript);
    final transcript = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.messages.dailyOsNextActivityTextDialogTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          decoration: InputDecoration(
            hintText: dialogContext.messages.dailyOsNextActivityTextHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.messages.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(dialogContext.messages.saveButton),
          ),
        ],
      ),
    );
    controller.dispose();
    if (transcript == null || transcript.trim().isEmpty || !context.mounted) {
      return;
    }
    final saved = await ref
        .read(dayAudioTranscriptWriterProvider)
        .attachManual(
          audioId: entry.audio?.meta.id ?? entry.processingJob!.audioId,
          transcript: transcript,
        );
    if (saved && entry.processingJob != null) {
      await ref
          .read(dayProcessingOutboxRepositoryProvider)
          .satisfyWithReviewedText(entry.processingJob!.id, transcript);
    }
    if (!saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.messages.dailyOsNextActivityTextSaveFailed),
        ),
      );
    }
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
    this.onRecover,
    this.onEditText,
  });

  final DayActivityEntry entry;
  final bool hasPlan;
  final VoidCallback onUse;
  final Future<void> Function()? onRetry;
  final Future<void> Function()? onRecover;
  final Future<void> Function()? onEditText;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final transcript = entry.transcript;
    final status = _status(context, entry);
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
                  DayActivityEntryKind.recovery =>
                    Icons.settings_backup_restore_rounded,
                  DayActivityEntryKind.plan => Icons.auto_awesome_rounded,
                  DayActivityEntryKind.summary => Icons.summarize_rounded,
                  DayActivityEntryKind.checkIn => Icons.notes_rounded,
                  DayActivityEntryKind.recording => Icons.mic_none_rounded,
                },
                color: tokens.colors.interactive.enabled,
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
          SizedBox(height: tokens.spacing.step3),
          Text(
            entry.plan?.data.dayLabel ??
                entry.summary?.text ??
                (entry.kind == DayActivityEntryKind.plan
                    ? context.messages.dailyOsNextActivityPlanAvailable
                    : entry.kind == DayActivityEntryKind.recovery
                    ? context.messages.dailyOsNextActivityRecoveryDescription
                    : entry.processingJob?.lastFailureClass ==
                          DayProcessingFailureClass.missingAsset
                    ? context.messages.dailyOsNextActivityMissingAudio
                    : entry.processingJob?.lastFailureClass ==
                          DayProcessingFailureClass.setupRequired
                    ? context.messages.dailyOsNextActivitySetupRequired
                    : transcript ??
                          context
                              .messages
                              .dailyOsNextActivityTranscriptPending),
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: transcript == null
                  ? tokens.colors.text.lowEmphasis
                  : tokens.colors.text.highEmphasis,
            ),
          ),
          if (entry.audio case final audio?
              when entry.audioAvailableLocally != false) ...[
            SizedBox(height: tokens.spacing.step4),
            AudioPlayerWidget(audio),
          ],
          if (onRecover != null ||
              onEditText != null ||
              entry.processingJob?.lastFailureClass ==
                  DayProcessingFailureClass.setupRequired ||
              _canRetry(entry) ||
              transcript != null) ...[
            SizedBox(height: tokens.spacing.step4),
            Wrap(
              spacing: tokens.spacing.step3,
              runSpacing: tokens.spacing.step3,
              children: [
                if (onRecover != null)
                  _AsyncActivityButton(
                    label: context.messages.dailyOsNextActivityRecover,
                    action: onRecover!,
                    variant: DesignSystemButtonVariant.secondary,
                    leadingIcon: Icons.settings_backup_restore_rounded,
                  ),
                if (_canRetry(entry))
                  _AsyncActivityButton(
                    label: context.messages.dailyOsNextActivityRetry,
                    action: onRetry!,
                    variant: DesignSystemButtonVariant.secondary,
                    leadingIcon: Icons.refresh_rounded,
                  ),
                if (entry.processingJob?.lastFailureClass ==
                    DayProcessingFailureClass.setupRequired)
                  DesignSystemButton(
                    label: context.messages.dailyOsNextActivityOpenSetup,
                    onPressed: () => nav_service.beamToNamed('/settings/ai'),
                    variant: DesignSystemButtonVariant.secondary,
                    leadingIcon: Icons.settings_rounded,
                  ),
                if (onEditText != null)
                  _AsyncActivityButton(
                    label: context.messages.dailyOsNextActivityAddOrEditText,
                    action: onEditText!,
                    variant: DesignSystemButtonVariant.secondary,
                    leadingIcon: Icons.edit_note_rounded,
                  ),
                if (transcript != null)
                  DesignSystemButton(
                    label: hasPlan
                        ? context.messages.dailyOsNextActivityUseToRefine
                        : context.messages.dailyOsNextActivityUseToPlan,
                    onPressed: onUse,
                    leadingIcon: Icons.auto_awesome_rounded,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _canRetry(DayActivityEntry entry) {
    if (entry.processingJob?.lastFailureClass ==
        DayProcessingFailureClass.setupRequired) {
      return false;
    }
    return switch (entry.processingJob?.status) {
      DayProcessingJobStatus.waitingForNetwork ||
      DayProcessingJobStatus.waitingForUser ||
      DayProcessingJobStatus.failed => true,
      _ => false,
    };
  }

  String _status(BuildContext context, DayActivityEntry entry) {
    if (entry.kind == DayActivityEntryKind.recovery) {
      return context.messages.dailyOsNextActivityRecoveryNeeded;
    }
    if (entry.kind == DayActivityEntryKind.plan) {
      return context.messages.dailyOsNextActivityPlanCreated;
    }
    if (entry.kind == DayActivityEntryKind.summary) {
      return context.messages.dailyOsNextActivityDaySummary;
    }
    if (entry.isSubmitted) {
      return context.messages.dailyOsNextActivitySubmitted;
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
  });

  final String label;
  final Future<void> Function() action;
  final DesignSystemButtonVariant variant;
  final IconData leadingIcon;

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
            content: Text(context.messages.dailyOsNextActivityActionFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
