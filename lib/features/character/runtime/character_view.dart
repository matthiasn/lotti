import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/runtime/character_painter.dart';
import 'package:lotti/features/character/runtime/character_renderer.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';

/// A live, ticking character widget. The [Ticker] lives here in `State` (not in
/// a Riverpod provider) and only the painter repaints each frame — the per-frame
/// hot path the plan requires. Higher-level state (which clip, which expression)
/// is passed in and changes infrequently.
class CharacterView extends StatefulWidget {
  const CharacterView({
    required this.scene,
    required this.clip,
    this.expression = Expression.neutral,
    this.scale = 1,
    this.paused = false,
    this.eyeOpenScale = 1,
    this.groundColor,
    super.key,
  });

  final CharacterScene scene;
  final Clip clip;
  final Expression expression;
  final double scale;
  final bool paused;

  /// Manual eyelid multiplier (1 = no change). The demo animates this to play a
  /// blink on demand; it composes with the always-on autonomic blink.
  final double eyeOpenScale;

  /// When set, the painter fills a floor band and the character stands on it
  /// (with a contact shadow) instead of floating.
  final Color? groundColor;

  @override
  State<CharacterView> createState() => _CharacterViewState();
}

class _CharacterViewState extends State<CharacterView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  // Cached so a per-frame rebuild reuses one renderer (and its matrix/paint
  // buffers) instead of allocating a fresh one every frame.
  final CharacterRenderer _renderer = CharacterRenderer();

  // [Ticker.start] resets its elapsed to zero, so a naive resume would replay
  // the clip from the beginning. We fold each paused run's elapsed into
  // [_offset] and expose [_offset] + the live ticker elapsed, giving
  // resume-in-place playback.
  Duration _offset = Duration.zero;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (!widget.paused) _ticker.start();
  }

  void _onTick(Duration elapsed) {
    setState(() => _elapsed = elapsed);
  }

  @override
  void didUpdateWidget(CharacterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clip != widget.clip) {
      // A new clip must play from t=0 — otherwise a one-shot swapped onto the
      // same instance would begin partway through. (The scene/rig carries no
      // timeline, so a scene swap keeps the current clock.) Reset and re-sync
      // the ticker to the current paused state.
      _offset = Duration.zero;
      _elapsed = Duration.zero;
      if (_ticker.isActive) _ticker.stop();
      if (!widget.paused) _ticker.start();
      return;
    }
    if (widget.paused && _ticker.isActive) {
      // Bank the elapsed so the clock holds steady, then resumes from here.
      _offset += _elapsed;
      _elapsed = Duration.zero;
      _ticker.stop();
    } else if (!widget.paused && !_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _offset + _elapsed;
    final seconds = total.inMicroseconds / Duration.microsecondsPerSecond;
    return CustomPaint(
      painter: CharacterPainter(
        scene: widget.scene,
        clip: widget.clip,
        timeSeconds: seconds,
        expression: widget.expression,
        scale: widget.scale,
        eyeOpenScale: widget.eyeOpenScale,
        groundColor: widget.groundColor,
        renderer: _renderer,
      ),
      child: const SizedBox.expand(),
    );
  }
}
