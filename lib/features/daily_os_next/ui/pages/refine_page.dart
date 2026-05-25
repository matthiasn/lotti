import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/refine_controller.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/diff_row.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_waveform.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Conversational refinement screen. Reuses the [DayTimeline] on the
/// left with diff applied in place, and a teal-tinted panel on the
/// right with voice input + DiffRow list + action row.
class RefinePage extends ConsumerWidget {
  const RefinePage({required this.draft, super.key});

  final DraftPlan draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final state = ref.watch(refineControllerProvider(draft));

    ref.listen<RefineState>(refineControllerProvider(draft), (previous, next) {
      if (next.phase == RefinePhase.accepted) {
        Navigator.of(context).pop(next.currentPlan);
      }
    });

    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      appBar: AppBar(
        backgroundColor: tokens.colors.background.level01,
        elevation: 0,
        title: Text(
          context.messages.dailyOsNextRefineTitle,
          style: tokens.typography.styles.subtitle.subtitle1.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: context.messages.dailyOsNextDayBack,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: DayTimeline(draft: state.currentPlan)),
                  SizedBox(
                    width: 380,
                    child: _RefinementPanel(draft: draft, state: state),
                  ),
                ],
              )
            : Column(
                children: [
                  Expanded(
                    child: _RefinementPanel(draft: draft, state: state),
                  ),
                  SizedBox(
                    height: 280,
                    child: DayTimeline(draft: state.currentPlan),
                  ),
                ],
              ),
      ),
    );
  }
}

class _RefinementPanel extends ConsumerWidget {
  const _RefinementPanel({required this.draft, required this.state});

  final DraftPlan draft;
  final RefineState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final notifier = ref.read(refineControllerProvider(draft).notifier);
    final messages = context.messages;

    return Container(
      decoration: BoxDecoration(
        color: teal.withValues(alpha: 0.04),
        border: Border(
          left: BorderSide(color: teal.withValues(alpha: 0.18)),
        ),
      ),
      padding: EdgeInsets.all(tokens.spacing.step5),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              messages.dailyOsNextRefineOverline,
              style: tokens.typography.styles.others.overline.copyWith(
                color: teal,
              ),
            ),
            SizedBox(height: tokens.spacing.step4),
            Center(
              child: VoiceButton(
                phase: _capturePhaseFor(state.phase),
                semanticLabel: _voiceLabel(context, state.phase),
                size: 88,
                onTap: notifier.toggleListening,
              ),
            ),
            SizedBox(height: tokens.spacing.step4),
            _StatusLine(state: state),
            if (state.phase == RefinePhase.listening) ...[
              SizedBox(height: tokens.spacing.step3),
              const Center(child: LiveWaveform(width: 180, height: 22)),
            ],
            if (state.transcript.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step3),
              _TranscriptCard(
                transcript: state.transcript,
                listening: state.phase == RefinePhase.listening,
              ),
            ],
            if (state.diff != null) ...[
              SizedBox(height: tokens.spacing.step4),
              for (final change in state.diff!.changes) ...[
                DiffRow(change: change),
                SizedBox(height: tokens.spacing.step3),
              ],
              _ActionRow(draft: draft),
            ],
          ],
        ),
      ),
    );
  }

  CapturePhase _capturePhaseFor(RefinePhase phase) {
    switch (phase) {
      case RefinePhase.idle:
      case RefinePhase.thinking:
      case RefinePhase.accepted:
        return CapturePhase.idle;
      case RefinePhase.listening:
        return CapturePhase.listening;
      case RefinePhase.diffReady:
        return CapturePhase.captured;
    }
  }

  String _voiceLabel(BuildContext context, RefinePhase phase) {
    switch (phase) {
      case RefinePhase.idle:
      case RefinePhase.diffReady:
        return context.messages.dailyOsNextCaptureVoiceButtonStart;
      case RefinePhase.listening:
        return context.messages.dailyOsNextCaptureVoiceButtonStop;
      case RefinePhase.thinking:
      case RefinePhase.accepted:
        return context.messages.dailyOsNextCaptureVoiceButtonReset;
    }
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});

  final RefineState state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final (text, color) = switch (state.phase) {
      RefinePhase.idle => (
        messages.dailyOsNextRefineStatusIdle,
        tokens.colors.text.mediumEmphasis,
      ),
      RefinePhase.listening => (
        messages.dailyOsNextRefineStatusListening,
        tokens.colors.interactive.enabled,
      ),
      RefinePhase.thinking => (
        messages.dailyOsNextRefineStatusThinking,
        tokens.colors.interactive.enabled,
      ),
      RefinePhase.diffReady => (
        messages.dailyOsNextRefineStatusDiffReady,
        tokens.colors.alert.success.defaultColor,
      ),
      RefinePhase.accepted => (
        messages.dailyOsNextRefineStatusAccepted,
        tokens.colors.alert.success.defaultColor,
      ),
    };
    return Text(
      text,
      textAlign: TextAlign.center,
      style: tokens.typography.styles.body.bodySmall.copyWith(color: color),
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({required this.transcript, required this.listening});

  final String transcript;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      padding: EdgeInsets.all(tokens.spacing.step4),
      child: Text(
        transcript,
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.highEmphasis,
          fontStyle: listening ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.draft});

  final DraftPlan draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final messages = context.messages;
    final notifier = ref.read(refineControllerProvider(draft).notifier);
    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      alignment: WrapAlignment.end,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.undo_rounded, size: 14),
          label: Text(messages.dailyOsNextRefineRevert),
          style: TextButton.styleFrom(
            foregroundColor: tokens.colors.text.mediumEmphasis,
          ),
          onPressed: notifier.revert,
        ),
        TextButton.icon(
          icon: Icon(Icons.mic_rounded, size: 14, color: teal),
          label: Text(messages.dailyOsNextRefineKeepTalking),
          style: TextButton.styleFrom(foregroundColor: teal),
          onPressed: notifier.keepTalking,
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check_rounded, size: 14),
          label: Text(messages.dailyOsNextRefineAccept),
          style: FilledButton.styleFrom(
            backgroundColor: teal,
            foregroundColor: tokens.colors.text.onInteractiveAlert,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step4,
              vertical: tokens.spacing.step2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radii.m),
            ),
          ),
          onPressed: notifier.accept,
        ),
      ],
    );
  }
}
