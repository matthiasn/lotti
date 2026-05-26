import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/reconcile_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/tasks_corpus_page.dart';
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
  const CapturePage({this.forDate, this.dateStrip, super.key});

  /// Day this capture is for. Defaults to `DateTime.now()`, which
  /// routes the capture to today's day-agent. When the route-level
  /// root mounts CapturePage for a different selected date it passes
  /// the local midnight of that day so the resulting day-agent is
  /// keyed on the chosen day instead of today.
  final DateTime? forDate;

  /// Optional widget rendered in the AppBar title slot — used by the
  /// route-level root to expose a date strip while Capture is open
  /// for a non-today date.
  final Widget? dateStrip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final state = ref.watch(captureControllerProvider);

    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      appBar: AppBar(
        backgroundColor: tokens.colors.background.level01,
        elevation: 0,
        toolbarHeight: 48,
        title: dateStrip,
        actions: [
          IconButton(
            icon: const Icon(Icons.checklist_rounded),
            tooltip: context.messages.dailyOsNextCaptureOpenTasks,
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const TasksCorpusPage(),
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step5,
                  vertical: tokens.spacing.step6,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _GreetingBlock(),
                    SizedBox(height: tokens.spacing.step6),
                    _Headline(forDate: forDate),
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
                    _ReconcileCta(state: state, forDate: forDate),
                  ],
                ),
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
      case CapturePhase.error:
        return context.messages.dailyOsNextCaptureVoiceButtonStart;
      case CapturePhase.listening:
        return context.messages.dailyOsNextCaptureVoiceButtonStop;
      case CapturePhase.transcribing:
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
    final hour = clock.now().hour;
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
  const _Headline({this.forDate});

  /// When Capture is mounted for a non-today date, the trailing
  /// "for today?" copy is swapped for `for <formatted date>?` so the
  /// headline doesn't mislead.
  final DateTime? forDate;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final tail = _resolveTail(messages.dailyOsNextCaptureHeadlineTail);
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: tokens.typography.styles.heading.heading1.copyWith(
          color: tokens.colors.text.highEmphasis,
        ),
        children: [
          TextSpan(text: '${messages.dailyOsNextCaptureHeadlineLead} '),
          TextSpan(
            text: tail,
            style: TextStyle(color: tokens.colors.text.lowEmphasis),
          ),
        ],
      ),
    );
  }

  String _resolveTail(String defaultTail) {
    final date = forDate;
    if (date == null) return defaultTail;
    final now = clock.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final picked = DateTime.utc(date.year, date.month, date.day);
    if (picked.isAtSameMomentAs(today)) return defaultTail;
    final delta = picked.difference(today).inDays;
    if (delta == 1) return 'for tomorrow?';
    if (delta == -1) return 'for yesterday?';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return 'for ${months[picked.month - 1]} ${picked.day}?';
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
            LiveWaveform(amplitudes: state.amplitudes),
            if (state.partialTranscript.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step3),
              _TranscriptText(
                text: state.partialTranscript,
                italic: true,
                color: tokens.colors.text.lowEmphasis,
              ),
            ],
          ],
        );
      case CapturePhase.transcribing:
        return Column(
          children: [
            Text(
              messages.dailyOsNextCaptureListening,
              style: tokens.typography.styles.others.overline.copyWith(
                color: tokens.colors.interactive.enabled,
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  tokens.colors.interactive.enabled,
                ),
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            Text(
              messages.dailyOsNextCaptureIdleHint,
              textAlign: TextAlign.center,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
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
            _TranscriptEditor(transcript: state.transcript),
          ],
        );
      case CapturePhase.error:
        return Text(
          state.errorMessage ?? messages.dailyOsNextCaptureIdleHint,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.alert.error.defaultColor,
          ),
        );
    }
  }
}

class _TranscriptEditor extends ConsumerWidget {
  const _TranscriptEditor({required this.transcript});

  final String transcript;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    return TextFormField(
      key: const Key('daily_os_capture_transcript_editor'),
      initialValue: transcript,
      minLines: 3,
      maxLines: 5,
      textInputAction: TextInputAction.newline,
      style: tokens.typography.styles.body.bodyMedium.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
      decoration: InputDecoration(
        labelText: context.messages.dailyOsNextCaptureTranscriptLabel,
        hintText: context.messages.dailyOsNextCaptureTranscriptHint,
        alignLabelWithHint: true,
        filled: true,
        fillColor: tokens.colors.background.level02,
        contentPadding: EdgeInsets.all(tokens.spacing.step4),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radii.m),
          borderSide: BorderSide(color: tokens.colors.decorative.level01),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radii.m),
          borderSide: BorderSide(color: tokens.colors.interactive.enabled),
        ),
      ),
      onChanged: ref.read(captureControllerProvider.notifier).updateTranscript,
    );
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
  const _ReconcileCta({required this.state, this.forDate});

  final CaptureState state;
  final DateTime? forDate;

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
    final hasTranscript = widget.state.transcript.trim().isNotEmpty;
    return FilledButton(
      onPressed: _submitting || !hasTranscript ? null : _onSubmit,
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
    final transcript = widget.state.transcript.trim();
    if (transcript.isEmpty) return;
    setState(() => _submitting = true);
    final agent = ref.read(dayAgentProvider);
    final navigator = Navigator.of(context);
    try {
      final captureId = await agent.submitCapture(
        transcript: transcript,
        // `capturedAt` routes the capture to the day-agent for that
        // day. When the route-level root mounts CapturePage for a
        // non-today selected date, pass that date so the resulting
        // plan lands on the chosen day instead of today.
        capturedAt: _capturedAtForSelectedDate(widget.forDate),
        audioId: widget.state.audioId,
      );
      if (!mounted) return;
      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ReconcilePage(
            captureId: captureId,
            dayDate: widget.forDate ?? DateTime.now(),
          ),
        ),
      );
      if (mounted) {
        ref.read(captureControllerProvider.notifier).reset();
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  DateTime _capturedAtForSelectedDate(DateTime? selectedDate) {
    final now = clock.now();
    if (selectedDate == null) return now;
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
  }
}
