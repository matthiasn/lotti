import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/reconcile_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_waveform.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Entry surface of the agentic Daily OS — voice-first check-in.
///
/// Layout: vertically centred greeting → headline → voice button →
/// state row (idle hint / waveform + transcript / "Got it." +
/// Reconcile CTA). Plain, calm, no calendar or task list visible.
/// Mirrors `prototype/screens/capture.jsx` variant A.
class CapturePage extends ConsumerWidget {
  const CapturePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final state = ref.watch(captureControllerProvider);

    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step5,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _GreetingBlock(),
                  SizedBox(height: tokens.spacing.step6),
                  const _Headline(),
                  SizedBox(height: tokens.spacing.step8),
                  VoiceButton(
                    phase: state.phase,
                    semanticLabel: _voiceButtonLabel(context, state.phase),
                    onTap: () =>
                        ref.read(captureControllerProvider.notifier).toggle(),
                  ),
                  SizedBox(height: tokens.spacing.step5),
                  _StateRow(state: state),
                  SizedBox(height: tokens.spacing.step6),
                  _ReconcileCta(state: state),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _voiceButtonLabel(BuildContext context, CapturePhase phase) {
    switch (phase) {
      case CapturePhase.idle:
        return context.messages.dailyOsNextCaptureVoiceButtonStart;
      case CapturePhase.listening:
        return context.messages.dailyOsNextCaptureVoiceButtonStop;
      case CapturePhase.captured:
        return context.messages.dailyOsNextCaptureVoiceButtonReset;
    }
  }
}

class _GreetingBlock extends StatelessWidget {
  const _GreetingBlock();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final hour = DateTime.now().hour;
    final greetingWord = hour < 12
        ? context.messages.dailyOsNextGreetingMorning
        : hour < 18
        ? context.messages.dailyOsNextGreetingAfternoon
        : context.messages.dailyOsNextGreetingEvening;
    return Column(
      children: [
        Text(
          context.messages.dailyOsNextGreetingHi,
          style: tokens.typography.styles.subtitle.subtitle1.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        Text(
          greetingWord,
          style: tokens.typography.styles.heading.heading3.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: tokens.typography.styles.heading.heading1.copyWith(
          color: tokens.colors.text.highEmphasis,
        ),
        children: [
          TextSpan(text: '${messages.dailyOsNextCaptureHeadlineLead} '),
          TextSpan(
            text: messages.dailyOsNextCaptureHeadlineTail,
            style: TextStyle(color: tokens.colors.text.lowEmphasis),
          ),
        ],
      ),
    );
  }
}

class _StateRow extends StatelessWidget {
  const _StateRow({required this.state});

  final CaptureState state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    switch (state.phase) {
      case CapturePhase.idle:
        return Text(
          messages.dailyOsNextCaptureIdleHint,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        );
      case CapturePhase.listening:
        return Column(
          children: [
            Text(
              messages.dailyOsNextCaptureListening,
              style: tokens.typography.styles.others.overline.copyWith(
                color: tokens.colors.interactive.enabled,
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            const LiveWaveform(),
            SizedBox(height: tokens.spacing.step3),
            _TranscriptText(
              text: state.transcript,
              italic: true,
              color: tokens.colors.text.lowEmphasis,
            ),
          ],
        );
      case CapturePhase.captured:
        return Column(
          children: [
            Text(
              messages.dailyOsNextCaptureCaptured,
              style: tokens.typography.styles.others.overline.copyWith(
                color: tokens.colors.interactive.enabled,
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            _TranscriptText(
              text: state.transcript,
              italic: false,
              color: tokens.colors.text.mediumEmphasis,
            ),
          ],
        );
    }
  }
}

class _TranscriptText extends StatelessWidget {
  const _TranscriptText({
    required this.text,
    required this.italic,
    required this.color,
  });

  final String text;
  final bool italic;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      textAlign: TextAlign.center,
      style: tokens.typography.styles.body.bodyMedium.copyWith(
        color: color,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      ),
    );
  }
}

class _ReconcileCta extends ConsumerStatefulWidget {
  const _ReconcileCta({required this.state});

  final CaptureState state;

  @override
  ConsumerState<_ReconcileCta> createState() => _ReconcileCtaState();
}

class _ReconcileCtaState extends ConsumerState<_ReconcileCta> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    if (widget.state.phase != CapturePhase.captured) {
      // Reserve roughly the same vertical space so the surrounding
      // layout does not jump when the CTA appears.
      return SizedBox(height: tokens.spacing.step9);
    }
    return FilledButton(
      onPressed: _submitting ? null : _onSubmit,
      style: FilledButton.styleFrom(
        backgroundColor: tokens.colors.interactive.enabled,
        foregroundColor: tokens.colors.text.onInteractiveAlert,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step6,
          vertical: tokens.spacing.step4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radii.m),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.messages.dailyOsNextCaptureReconcileCta,
            style: tokens.typography.styles.subtitle.subtitle1,
          ),
          SizedBox(width: tokens.spacing.step2),
          const Icon(Icons.arrow_forward_rounded, size: 18),
        ],
      ),
    );
  }

  Future<void> _onSubmit() async {
    setState(() => _submitting = true);
    final agent = ref.read(dayAgentProvider);
    final navigator = Navigator.of(context);
    try {
      final captureId = await agent.submitCapture(
        transcript: widget.state.transcript,
        capturedAt: DateTime.now(),
      );
      if (!mounted) return;
      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ReconcilePage(captureId: captureId),
        ),
      );
      if (mounted) {
        ref.read(captureControllerProvider.notifier).reset();
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
