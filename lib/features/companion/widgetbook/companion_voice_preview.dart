import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/animation/speech_envelope.dart';
import 'package:lotti/features/companion/animation/voiced_text_track.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:media_kit/media_kit.dart';

/// Plays a WAV out loud and has her say it, the way the on-device voice will
/// feed her: the clip's loudness is computed before it plays, and each frame
/// the mouth reads the player's playhead. With the clip's [text] the mouth
/// also takes the words' shapes ([VoicedTextTrack]).
class CompanionVoicePreview extends StatefulWidget {
  const CompanionVoicePreview({
    required this.look,
    required this.mood,
    required this.framing,
    required this.wavPath,
    required this.text,
    this.stage = true,
    this.supersample,
    super.key,
  });

  final CompanionLook look;
  final CompanionMood mood;
  final CompanionFraming framing;
  final String wavPath;
  final String text;
  final bool stage;
  final int? supersample;

  @override
  State<CompanionVoicePreview> createState() => _CompanionVoicePreviewState();
}

class _CompanionVoicePreviewState extends State<CompanionVoicePreview> {
  Player? _player;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  MouthTrack? _track;
  Duration? _position;
  String? _error;

  Future<void> _play() async {
    final path = widget.wavPath.trim();
    try {
      final bytes = await File(path).readAsBytes();
      // The page may have been left while the file was read: a player made
      // now would never be disposed.
      if (!mounted) return;
      final text = widget.text.trim();
      final track = text.isEmpty
          ? SpeechEnvelope.fromWav(bytes)
          : VoicedTextTrack.fromWav(bytes, text);
      final player = _player ??= _listen(Player());
      setState(() {
        _error = null;
        _position = null;
        _track = track;
      });
      await player.open(Media(path));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Player _listen(Player player) {
    _subscriptions
      ..add(
        player.stream.position.listen((p) {
          if (player.state.playing) _position = p;
        }),
      )
      ..add(
        player.stream.completed.listen((done) {
          if (done) _position = null;
        }),
      );
    return player;
  }

  @override
  void dispose() {
    // Teardown of a preview page: a failed cancel or dispose leaves nothing
    // for anyone to act on, so their futures are dropped on purpose.
    for (final s in _subscriptions) {
      s.cancel().ignore();
    }
    _player?.dispose().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final error = _error;
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step5),
      child: Column(
        children: [
          Expanded(
            child: CompanionView(
              look: widget.look,
              mood: widget.mood,
              framing: widget.framing,
              stage: widget.stage,
              supersample: widget.supersample,
              track: _track,
              playhead: () => _position,
            ),
          ),
          SizedBox(height: tokens.spacing.step4),
          DesignSystemButton(
            label: 'Play',
            onPressed: widget.wavPath.trim().isEmpty ? null : _play,
          ),
          if (error != null) ...[
            SizedBox(height: tokens.spacing.step2),
            Text(
              error,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.alert.error.defaultColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
