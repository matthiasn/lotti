import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/features/daily_os_next/state/capture_dbfs.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/state/recording_style.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_recording_style_view.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:record/record.dart' show Amplitude;

/// The recording-style step: previews both themed pairs (analogue VU meter +
/// modern orb), each driven by a looping simulated level, and persists the
/// chosen style.
///
/// A live-mic **"Try with your voice"** toggle swaps the previews onto the real
/// microphone level: it records to a throwaway file (levels only — never
/// transcribed or saved as a journal entry), streams the amplitude into the
/// previews, and deletes the file on stop. The simulated signal keeps the
/// previews alive by default without any permission prompt; under reduced
/// motion it holds a static frame.
class OnboardingRecordingStyleStep extends ConsumerStatefulWidget {
  const OnboardingRecordingStyleStep({required this.onContinue, super.key});

  /// Advances to the category step once the style is chosen + persisted.
  final VoidCallback onContinue;

  @override
  ConsumerState<OnboardingRecordingStyleStep> createState() =>
      _OnboardingRecordingStyleStepState();
}

class _OnboardingRecordingStyleStepState
    extends ConsumerState<OnboardingRecordingStyleStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sim;
  late final ColorScheme _darkScheme = DesignSystemTheme.dark().colorScheme;
  // Resolved lazily the first time the live tryout starts (so the recorder is
  // never instantiated unless used) and held so the dispose teardown can stop
  // it without `ref`, which is unavailable in dispose.
  AudioRecorderRepository? _liveRepo;
  RecordingStyle _selected = RecordingStyle.modern;
  bool _tryingWithVoice = false;

  // Live-mic state (only while "Try with your voice" is on).
  StreamSubscription<Amplitude>? _ampSub;
  AudioNote? _liveNote;
  double _liveDbfs = _restDbfs;
  List<double> _liveAmps = const [];

  static const _bars = 28;
  static const _restDbfs = -80.0;

  @override
  void initState() {
    super.initState();
    _sim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    final current = ref.read(recordingStyleProvider).asData?.value;
    if (current != null) _selected = current;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      if (_sim.isAnimating) _sim.stop();
      _sim.value = 0.3;
    } else if (!_sim.isAnimating) {
      _sim.repeat();
    }
  }

  @override
  void dispose() {
    // Best-effort teardown of any in-flight tryout (cancel stream, stop the
    // recorder, drop the throwaway file) without awaiting in dispose.
    _ampSub?.cancel();
    if (_liveNote != null) {
      unawaited(_liveRepo?.stopRecording() ?? Future<void>.value());
      _deleteLiveFile(_liveNote);
    }
    _sim.dispose();
    super.dispose();
  }

  Future<void> _startLive() async {
    final repo = ref.read(audioRecorderRepositoryProvider);
    _liveRepo = repo;
    final note = await repo.startRecording();
    if (!mounted) return;
    if (note == null) {
      // Permission denied / start failed — fall back to the simulation.
      setState(() => _tryingWithVoice = false);
      return;
    }
    if (!_tryingWithVoice) {
      // The user toggled back off while the recorder was still starting —
      // discard immediately so we never leave a recording running.
      _liveNote = note;
      unawaited(_stopLive());
      return;
    }
    _liveNote = note;
    _ampSub = repo.amplitudeStream.listen((amp) {
      if (!mounted) return;
      setState(() {
        _liveDbfs = amp.current;
        final next = [..._liveAmps, normaliseDbfs(amp.current)];
        _liveAmps = next.length > _bars
            ? next.sublist(next.length - _bars)
            : next;
      });
    });
  }

  Future<void> _stopLive() async {
    unawaited(_ampSub?.cancel());
    _ampSub = null;
    final note = _liveNote;
    if (note != null) {
      await _liveRepo?.stopRecording();
      await _deleteLiveFile(note);
    }
    if (!mounted) return;
    setState(() {
      _liveNote = null;
      _liveAmps = const [];
      _liveDbfs = _restDbfs;
    });
  }

  Future<void> _deleteLiveFile(AudioNote? note) async {
    if (note == null) return;
    try {
      final path =
          '${getDocumentsDirectory().path}${note.audioDirectory}${note.audioFile}';
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (_) {
      // A leftover throwaway file is harmless (never a journal entry); ignore.
    }
  }

  void _onToggleTryWithVoice(bool value) {
    setState(() => _tryingWithVoice = value);
    unawaited(value ? _startLive() : _stopLive());
  }

  /// A lively but bounded synthetic "speech" level from the looping controller
  /// phase, so both previews animate without touching the mic.
  ({double vu, double dbfs, List<double> amplitudes}) _simulatedLevel() {
    final t = _sim.value;
    final env =
        (0.45 +
                0.4 *
                    math.sin(2 * math.pi * t) *
                    math.sin(2 * math.pi * 3 * t + 0.7))
            .clamp(0.05, 1.0);
    final amplitudes = [
      for (var i = 0; i < _bars; i++)
        (env * (0.5 + 0.5 * math.sin(i * 0.5 + 2 * math.pi * 2 * t))).clamp(
          0.0,
          1.0,
        ),
    ];
    return (vu: -20 + 23 * env, dbfs: -45 + 39 * env, amplitudes: amplitudes);
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final live = _tryingWithVoice && _liveNote != null;
    return AnimatedBuilder(
      animation: _sim,
      builder: (context, _) {
        final level = live
            // 0 VU ≈ -18 dBFS, so VU ≈ dBFS + 18, clamped to the meter range.
            ? (
                vu: (_liveDbfs + 18).clamp(-20.0, 3.0),
                dbfs: _liveDbfs,
                amplitudes: _liveAmps,
              )
            : _simulatedLevel();
        return OnboardingRecordingStyleView(
          accent: dsTokensDark.colors.interactive.enabled,
          colorScheme: _darkScheme,
          title: messages.onboardingRecordingStyleTitle,
          explanation: messages.onboardingRecordingStyleExplanation,
          analogueLabel: messages.onboardingRecordingStyleAnalogue,
          modernLabel: messages.onboardingRecordingStyleModern,
          tryWithVoiceLabel: messages.onboardingRecordingStyleTryVoice,
          continueLabel: messages.onboardingRecordingStyleContinue,
          selected: _selected,
          onSelect: (style) => setState(() => _selected = style),
          tryingWithVoice: _tryingWithVoice,
          onToggleTryWithVoice: _onToggleTryWithVoice,
          onContinue: () async {
            await ref.read(recordingStyleProvider.notifier).setStyle(_selected);
            widget.onContinue();
          },
          vu: level.vu,
          dBFS: level.dbfs,
          amplitudes: level.amplitudes,
        );
      },
    );
  }
}
