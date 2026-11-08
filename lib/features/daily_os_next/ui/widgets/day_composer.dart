import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/ui/pages/capture_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_composer_bar.dart';
import 'package:lotti/features/design_system/components/chat_input/design_system_chat_input.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart'
    show intervalMs;
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Hands finished words to the host, with the recording behind them when
/// they were spoken.
typedef DayComposerSubmitter =
    Future<void> Function(String transcript, {String? audioId});

/// Talks to the day's planner from the bottom of the Day surface, spoken or
/// typed in one place: the empty day's check-in, and on a planned day what
/// should change. The composer is the capture, so no separate Capture screen
/// stands in front of it.
///
/// The mic records through the Daily OS [captureControllerProvider], the same
/// recorder the Capture screen uses, so the recording is saved as a journal
/// entry and shows on Activity like any other take. While it runs, the
/// input's row shows the voice across its whole width; Done ends it, the
/// words land in the field — after anything already typed — for review, and
/// the capture returns to rest. Sending
/// hands them to [onSubmit], with the recording's id while the words came
/// from one.
///
/// A capture failure reads under the field, in the Capture screen's words.
///
/// It acts only on takes it started. The recorder is shared with the
/// planning sheet's Capture step, which the onboarding spotlight opens over
/// this page, and that sheet's typing, recordings and failures are left to it.
class DayComposer extends ConsumerStatefulWidget {
  const DayComposer({
    required this.day,
    required this.onSubmit,
    this.hintText,
    this.intent = AudioCaptureIntent.dayPlan,
    this.clearOnSubmit = false,
    this.header,
    this.nextStep,
    this.enabled = true,
    this.barKey = const Key('daily_os_day_check_in_cta'),
    super.key,
  });

  final DateTime day;
  final DayComposerSubmitter onSubmit;

  /// The field's hint; the check-in's by default.
  final String? hintText;

  /// What a take records for: a check-in, or a refine pass.
  final AudioCaptureIntent intent;

  /// Empties the field once [onSubmit] has handled the words — for a
  /// request that is done once sent. A check-in keeps them, so backing out of
  /// the sheet it opens loses nothing.
  final bool clearOnSubmit;

  /// Shown above the field, inside the bar (quick refinements).
  final Widget? header;

  /// See [DayComposerBar.nextStep].
  final Widget? nextStep;

  /// The bar's key, for finders and the onboarding spotlight.
  final Key barKey;

  /// See [DayComposerBar.enabled].
  final bool enabled;

  @override
  ConsumerState<DayComposer> createState() => _DayComposerState();
}

class _DayComposerState extends ConsumerState<DayComposer> {
  final _controller = TextEditingController();
  final _elapsed = Stopwatch();

  /// The recording behind the words in the field. Cleared when the field is
  /// emptied, so typed words alone never claim someone else's audio.
  String? _audioId;

  /// True while [DayComposer.onSubmit] runs — a second send would
  /// submit the same check-in twice.
  bool _submitting = false;

  /// True from this composer's own mic tap until that take ends. The capture
  /// controller is shared with the planning sheet's Capture step, which the
  /// onboarding spotlight opens over this page; its typing, recording and
  /// transcripts are not this composer's to show, take over or reset.
  bool _ownsCapture = false;

  /// Why this composer's last take failed, until the next one starts. Kept
  /// here rather than read from the shared state, so a failure in the sheet
  /// never shows under the composer.
  CaptureError? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_dropAudioWhenCleared);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_dropAudioWhenCleared)
      ..dispose();
    super.dispose();
  }

  void _dropAudioWhenCleared() {
    if (_controller.text.trim().isEmpty) _audioId = null;
  }

  Future<void> _startVoice() async {
    setState(() {
      _ownsCapture = true;
      _error = null;
    });
    await ref
        .read(captureControllerProvider.notifier)
        .toggle(forDate: widget.day, intent: widget.intent);
  }

  void _onCaptureChanged(CaptureState? previous, CaptureState next) {
    if (!_ownsCapture) return;
    final entered = previous?.phase != next.phase;
    if (!entered) return;
    switch (next.phase) {
      case CapturePhase.listening:
        _elapsed
          ..reset()
          ..start();
      case CapturePhase.transcribing:
        _elapsed.stop();
      case CapturePhase.error:
        _elapsed.stop();
        setState(() {
          _ownsCapture = false;
          _error = next.error;
        });
      case CapturePhase.idle:
        // Cancelled.
        _elapsed.stop();
        setState(() => _ownsCapture = false);
      case CapturePhase.captured:
        _elapsed.stop();
        setState(() => _ownsCapture = false);
        final words = next.transcript.trim();
        // What was said lands after anything already in the field, to be
        // read before sending; the field keeps the latest take's audio.
        if (words.isNotEmpty) {
          final before = _controller.text.trimRight();
          final text = before.isEmpty ? words : '$before $words';
          _controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
          _audioId = next.audioId;
        }
        // The words now live in the field; the recorder goes back to rest
        // so the mic is ready for another take.
        ref.read(captureControllerProvider.notifier).reset();
    }
  }

  Future<void> _submit(String words) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(words, audioId: _audioId);
      if (widget.clearOnSubmit && mounted) _controller.clear();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      captureControllerProvider.select((s) => s.withoutMeter),
      _onCaptureChanged,
    );
    // The pill draws the live levels, so this watch takes the meter ticks;
    // they rebuild only this footer.
    final capture = ref.watch(captureControllerProvider);
    final notifier = ref.read(captureControllerProvider.notifier);

    // Only a take this composer started shows in it: the recorder is
    // shared with the planning sheet's Capture step.
    final phase = !_ownsCapture
        ? DesignSystemChatInputPhase.compose
        : switch (capture.phase) {
            CapturePhase.listening => DesignSystemChatInputPhase.recording,
            CapturePhase.transcribing =>
              DesignSystemChatInputPhase.transcribing,
            _ => DesignSystemChatInputPhase.compose,
          };

    return DayComposerBar(
      key: widget.barKey,
      controller: _controller,
      header: widget.header,
      nextStep: widget.nextStep,
      hintText:
          widget.hintText ?? context.messages.dailyOsNextDayComposerCheckInHint,
      enabled: widget.enabled && !_submitting,
      phase: phase,
      levels: capture.amplitudes,
      sampleInterval: const Duration(milliseconds: intervalMs),
      elapsed: _elapsed.elapsed,
      onCancelRecording: notifier.reset,
      // Done ends the take; its words land in the field to be read.
      onFinishRecording: () =>
          notifier.toggle(forDate: widget.day, intent: widget.intent),
      errorText: captureErrorMessage(context, _error),
      onStartVoice: _startVoice,
      onSubmitText: _submit,
    );
  }
}
