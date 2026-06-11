import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/refine_controller.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/refine_voice_sync.dart';
import 'package:lotti/features/daily_os_next/ui/text_scale_policy.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/diff_row.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_waveform.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/transcript_editor.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_button.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_orb_zone.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Scaffold-free refine content for the day-planning modal, built on the
/// same anchored skeleton as the Capture step:
///
/// ```text
/// per-phase headline            ← top, copy swaps in place
/// refine zone                   ← Expanded: plan list / live words / diff
/// orb zone (waveform·orb·caption) ← fixed height, fixed position
/// ```
///
/// The host's sticky glass bar carries Start over / Looks good; diff rows
/// keep their inline accept/reject affordances inside the zone.
class RefineModalContent extends ConsumerWidget {
  const RefineModalContent({required this.draft, super.key});

  final DraftPlan draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final state = ref.watch(refineControllerProvider(draft));
    final notifier = ref.read(refineControllerProvider(draft).notifier);
    // Only the phase here — the orb zone below watches the meter fields
    // itself so amplitude ticks don't rebuild the plan list.
    final capturePhase = ref.watch(
      captureControllerProvider.select((s) => s.phase),
    );
    final captureNotifier = ref.read(captureControllerProvider.notifier);

    // Pop only on the edge INTO accepted — later emissions while already
    // accepted must not pop the route a second time.
    ref.listen<RefineState>(refineControllerProvider(draft), (previous, next) {
      if (previous?.phase != RefinePhase.accepted &&
          next.phase == RefinePhase.accepted) {
        Navigator.of(context).pop(next.currentPlan);
      }
    });
    listenCaptureForRefine(ref, draft);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.step5,
            tokens.spacing.step6,
            tokens.spacing.step5,
            tokens.spacing.step5,
          ),
          child: Column(
            children: [
              if (dailyOsTextScaleOf(context) < kDailyOsHideHeaderScale) ...[
                // Reserved eyebrow slot mirrors the capture header anatomy
                // so the headline baseline sits at the same height on
                // every step.
                Text(' ', style: calmGreetingStyle(tokens)),
                SizedBox(height: tokens.spacing.step3),
                _RefineHeadline(phase: state.phase),
                SizedBox(height: tokens.spacing.step4),
              ],
              Expanded(
                child: _RefineZone(draft: draft, state: state),
              ),
              SizedBox(height: tokens.spacing.step4),
              Consumer(
                builder: (context, ref, _) {
                  final (amplitudes, dbfs) = ref.watch(
                    captureControllerProvider.select(
                      (s) => (s.amplitudes, s.dbfs),
                    ),
                  );
                  return VoiceOrbZone(
                    phase: refineOrbPhaseFor(state.phase, capturePhase),
                    caption: _caption(context, state.phase),
                    captionColor: _captionColor(tokens, state.phase),
                    semanticLabel: refineVoiceLabel(context, state.phase),
                    amplitudes: amplitudes,
                    dbfs: dbfs,
                    onTap: () => handleRefineVoiceTap(
                      refineState: state,
                      refineNotifier: notifier,
                      captureNotifier: captureNotifier,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _caption(BuildContext context, RefinePhase phase) {
    final messages = context.messages;
    return switch (phase) {
      // Same platform-aware hint as Capture's orb, so the wording matches
      // across the two voice surfaces.
      RefinePhase.idle => voiceIdleHint(context),
      RefinePhase.listening => messages.dailyOsNextRefineStatusListening,
      RefinePhase.reviewing => messages.dailyOsNextCaptureCaptured,
      RefinePhase.thinking => messages.dailyOsNextRefineStatusThinking,
      // The headline already narrates the diff; keep the caption silent
      // (the empty strut line preserves the orb position).
      RefinePhase.diffReady => '',
      RefinePhase.accepted => messages.dailyOsNextRefineStatusAccepted,
    };
  }

  Color _captionColor(DsTokens tokens, RefinePhase phase) {
    // Captions are status, not actions — they stay muted so accent color
    // keeps meaning "tappable".
    return switch (phase) {
      RefinePhase.listening ||
      RefinePhase.reviewing ||
      RefinePhase.thinking ||
      RefinePhase.accepted => tokens.colors.text.mediumEmphasis,
      RefinePhase.idle ||
      RefinePhase.diffReady => tokens.colors.text.lowEmphasis,
    };
  }
}

/// Per-phase headline for the refine step, cross-fading in place like the
/// capture header.
class _RefineHeadline extends StatelessWidget {
  const _RefineHeadline({required this.phase});

  final RefinePhase phase;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final text = switch (phase) {
      RefinePhase.idle => messages.dailyOsNextRefineHeadlineIdle,
      RefinePhase.listening => messages.dailyOsNextCaptureHeadlineListening,
      RefinePhase.reviewing => messages.dailyOsNextCaptureHeadlineCaptured,
      RefinePhase.thinking => messages.dailyOsNextRefineHeadlineThinking,
      RefinePhase.diffReady ||
      RefinePhase.accepted => messages.dailyOsNextRefineHeadlineDiffReady,
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [...previousChildren, ?currentChild],
      ),
      child: Text(
        text,
        key: ValueKey<String>(text),
        textAlign: TextAlign.center,
        style: calmDisplayStyle(tokens),
      ),
    );
  }
}

/// The flexible middle of the refine step. Idle shows the current plan
/// (what you're about to change); listening/thinking stream the words;
/// reviewing hosts the editable transcript; diffReady lists the proposed
/// changes with inline accept/reject.
class _RefineZone extends ConsumerWidget {
  const _RefineZone({required this.draft, required this.state});

  final DraftPlan draft;
  final RefineState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final notifier = ref.read(refineControllerProvider(draft).notifier);

    final Widget zone;
    switch (state.phase) {
      case RefinePhase.idle:
      case RefinePhase.accepted:
        zone = _CurrentPlanList(plan: state.currentPlan);
      case RefinePhase.listening:
        zone = LiveTranscriptView(
          text: state.transcript,
          color: tokens.colors.text.mediumEmphasis,
        );
      case RefinePhase.thinking:
        zone = AnimatedOpacity(
          opacity: 0.55,
          duration: const Duration(milliseconds: 200),
          child: LiveTranscriptView(
            text: state.transcript,
            color: tokens.colors.text.mediumEmphasis,
          ),
        );
      case RefinePhase.reviewing:
        zone = Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.step6),
            child: _TranscriptReview(
              draft: draft,
              transcript: state.transcript,
            ),
          ),
        );
      case RefinePhase.diffReady:
        final diff = state.diff;
        zone = Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.step6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (diff != null)
                  for (final change in diff.changes) ...[
                    DiffRow(
                      change: change,
                      decision: state.decisionFor(change),
                      resolving: state.resolvingChangeId == change.id,
                      onAccept: () => notifier.acceptChange(change.id),
                      onReject: () => notifier.rejectChange(change.id),
                    ),
                    SizedBox(height: tokens.spacing.step3),
                  ],
              ],
            ),
          ),
        );
    }

    if (state.problem == null) return zone;
    return Column(
      children: [
        Expanded(child: zone),
        SizedBox(height: tokens.spacing.step3),
        _ProblemNotice(problem: state.problem!),
      ],
    );
  }
}

/// Read-only summary of the plan being refined — what the user is about to
/// talk about, sitting directly under the headline that asks about it.
class _CurrentPlanList extends StatelessWidget {
  const _CurrentPlanList({required this.plan});

  final DraftPlan plan;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    if (plan.blocks.isEmpty) return const SizedBox.expand();
    final locale = Localizations.localeOf(context).toString();
    final timeFormat = DateFormat.Hm(locale);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step6),
        // Centered as a block on the panel axis (left-aligned text inside)
        // so wide hosts don't strand the list on the leading edge.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.messages.dailyOsNextRefineCurrentPlan,
                style: calmEyebrowStyle(tokens),
              ),
              SizedBox(height: tokens.spacing.step3),
              for (final block in plan.blocks) ...[
                _PlanRow(block: block, timeFormat: timeFormat),
                SizedBox(height: tokens.spacing.step2),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.block, required this.timeFormat});

  final TimeBlock block;
  final DateFormat timeFormat;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = categoryColorFromHex(block.category.colorHex);
    return Row(
      children: [
        Container(
          width: tokens.spacing.step3,
          height: tokens.spacing.step3,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: tokens.spacing.step3),
        Text(
          '${timeFormat.format(block.start)}–${timeFormat.format(block.end)}',
          // Mono digits so the time column stays aligned across rows.
          style: monoMetaStyle(
            tokens,
            tokens.colors,
            base: tokens.typography.styles.body.bodySmall,
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Text(
            block.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ),
      ],
    );
  }
}

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

    // Pop only on the edge INTO accepted — later emissions while already
    // accepted must not pop the route a second time.
    ref.listen<RefineState>(refineControllerProvider(draft), (previous, next) {
      if (previous?.phase != RefinePhase.accepted &&
          next.phase == RefinePhase.accepted) {
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
  const _RefinementPanel({
    required this.draft,
    required this.state,
  });

  final DraftPlan draft;
  final RefineState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final notifier = ref.read(refineControllerProvider(draft).notifier);
    // Only the phase here — orb and waveform watch the meter fields
    // themselves so amplitude ticks don't rebuild the whole panel.
    final capturePhase = ref.watch(
      captureControllerProvider.select((s) => s.phase),
    );
    final captureNotifier = ref.read(captureControllerProvider.notifier);
    final messages = context.messages;

    listenCaptureForRefine(ref, draft);

    final content = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The side panel has no other title, so it keeps the eyebrow.
          Text(
            messages.dailyOsNextRefineOverline,
            style: calmEyebrowStyle(tokens, color: teal),
          ),
          // step6 clearance: the listening shader spills past the orb's
          // layout field (which no longer reserves the old +128 padding),
          // so the neighbours need room for it to breathe.
          SizedBox(height: tokens.spacing.step6),
          Center(
            child: Consumer(
              builder: (context, ref, _) {
                final dbfs = ref.watch(
                  captureControllerProvider.select((s) => s.dbfs),
                );
                return VoiceButton(
                  phase: refineOrbPhaseFor(state.phase, capturePhase),
                  dbfs: dbfs,
                  semanticLabel: refineVoiceLabel(context, state.phase),
                  size: 88,
                  onTap: () {
                    handleRefineVoiceTap(
                      refineState: state,
                      refineNotifier: notifier,
                      captureNotifier: captureNotifier,
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(height: tokens.spacing.step6),
          _StatusLine(state: state),
          if (state.problem != null) ...[
            SizedBox(height: tokens.spacing.step3),
            _ProblemNotice(
              problem: state.problem!,
            ),
          ],
          if (state.phase == RefinePhase.listening) ...[
            SizedBox(height: tokens.spacing.step3),
            Center(
              child: Consumer(
                builder: (context, ref, _) {
                  final amplitudes = ref.watch(
                    captureControllerProvider.select((s) => s.amplitudes),
                  );
                  return LiveWaveform(
                    amplitudes: amplitudes,
                    width: 180,
                    height: 22,
                  );
                },
              ),
            ),
          ],
          if (state.phase == RefinePhase.reviewing) ...[
            SizedBox(height: tokens.spacing.step3),
            _TranscriptReview(draft: draft, transcript: state.transcript),
          ] else if (state.transcript.isNotEmpty) ...[
            SizedBox(height: tokens.spacing.step3),
            _TranscriptCard(
              transcript: state.transcript,
              listening: state.phase == RefinePhase.listening,
            ),
          ],
          if (state.diff != null) ...[
            SizedBox(height: tokens.spacing.step4),
            for (final change in state.diff!.changes) ...[
              DiffRow(
                change: change,
                decision: state.decisionFor(change),
                resolving: state.resolvingChangeId == change.id,
                onAccept: () => notifier.acceptChange(change.id),
                onReject: () => notifier.rejectChange(change.id),
              ),
              SizedBox(height: tokens.spacing.step3),
            ],
            _ActionRow(draft: draft),
          ],
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: teal.withValues(alpha: 0.04),
        border: Border(
          left: BorderSide(color: teal.withValues(alpha: 0.18)),
        ),
      ),
      padding: EdgeInsets.all(tokens.spacing.step5),
      child: content,
    );
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
      RefinePhase.reviewing => (
        messages.dailyOsNextCaptureCaptured,
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

class _ProblemNotice extends StatelessWidget {
  const _ProblemNotice({
    required this.problem,
  });

  final RefineProblem problem;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final message = switch (problem) {
      RefineProblem.noChanges => context.messages.dailyOsNextRefineNoChanges,
      RefineProblem.proposalFailed => context.messages.dailyOsNextGenericError,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.alert.error.defaultColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(tokens.radii.s),
        border: Border.all(
          color: tokens.colors.alert.error.defaultColor.withValues(alpha: 0.36),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step3),
        child: Text(
          message,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.alert.error.defaultColor,
          ),
        ),
      ),
    );
  }
}

class _TranscriptReview extends ConsumerWidget {
  const _TranscriptReview({required this.draft, required this.transcript});

  final DraftPlan draft;
  final String transcript;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final notifier = ref.read(refineControllerProvider(draft).notifier);
    final canSubmit = transcript.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TranscriptEditor(
          fieldKey: const Key('daily_os_refine_transcript_editor'),
          transcript: transcript,
          onChanged: notifier.updateTranscript,
        ),
        SizedBox(height: tokens.spacing.step3),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: canSubmit
                ? () => unawaited(notifier.submitReviewedTranscript())
                : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: Text(context.messages.dailyOsNextRefineTitle),
            style: FilledButton.styleFrom(
              backgroundColor: tokens.colors.interactive.enabled,
              foregroundColor: tokens.colors.text.onInteractiveAlert,
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step4,
                vertical: tokens.spacing.step2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.radii.m),
              ),
            ),
          ),
        ),
      ],
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
      ],
    );
  }
}
