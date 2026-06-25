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
    this.partnerScene,
    this.ensembleScenes = const [],
    this.ensembleExpressions = const [],
    this.synchronousEnsemble = false,
    this.expression = Expression.neutral,
    this.scale = 1,
    this.playbackRate = 1,
    this.paused = false,
    this.eyeOpenScale = 1,
    this.groundColor,
    this.locomote = false,
    this.walkingPair = false,
    super.key,
  });

  final CharacterScene scene;

  /// Optional alternate scene for the second cat when [walkingPair] is true.
  final CharacterScene? partnerScene;

  /// Additional scenes for multi-cat ensemble mode.
  final List<CharacterScene> ensembleScenes;

  /// Optional per-cat expressions for ensemble mode.
  final List<Expression> ensembleExpressions;

  /// Keeps all ensemble members on the same phase when true.
  final bool synchronousEnsemble;

  final Clip clip;
  final Expression expression;
  final double scale;
  final double playbackRate;
  final bool paused;

  /// Manual eyelid multiplier (1 = no change). The demo animates this to play a
  /// blink on demand; it composes with the always-on autonomic blink.
  final double eyeOpenScale;

  /// When set, the painter fills a floor band and the character stands on it
  /// (with a contact shadow) instead of floating.
  final Color? groundColor;

  /// When true, locomoting clips (walk/run) travel across the stage and turn at
  /// the edges instead of cycling in place (which kills the foot-skate).
  final bool locomote;

  /// Paints two phase-offset copies side-by-side for the walk showcase.
  final bool walkingPair;

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
    if (oldWidget.playbackRate != widget.playbackRate) {
      final wasActive = _ticker.isActive;
      final rawSeconds =
          (_offset + _elapsed).inMicroseconds / Duration.microsecondsPerSecond;
      final displaySeconds = rawSeconds * oldWidget.playbackRate;
      _offset = Duration(
        microseconds:
            (displaySeconds /
                    widget.playbackRate *
                    Duration.microsecondsPerSecond)
                .round(),
      );
      _elapsed = Duration.zero;
      if (wasActive) {
        _ticker.stop();
        if (!widget.paused) _ticker.start();
      }
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
    final seconds =
        total.inMicroseconds /
        Duration.microsecondsPerSecond *
        widget.playbackRate;
    return CustomPaint(
      painter: CharacterPainter(
        scene: widget.scene,
        partnerScene: widget.partnerScene,
        ensembleScenes: widget.ensembleScenes,
        ensembleExpressions: _ensembleExpressionsAt(seconds),
        synchronousEnsemble: widget.synchronousEnsemble,
        clip: widget.clip,
        timeSeconds: seconds,
        expression: widget.expression,
        scale: widget.scale,
        eyeOpenScale: widget.eyeOpenScale,
        groundColor: widget.groundColor,
        locomote: widget.locomote,
        walkingPair: widget.walkingPair,
        renderer: _renderer,
      ),
      child: const SizedBox.expand(),
    );
  }

  List<Expression> _ensembleExpressionsAt(double seconds) {
    if (widget.ensembleExpressions.isEmpty) return const [];
    const offsets = [0.0, 0.65, 1.15, 1.65];
    const period = 1.45;
    return [
      for (final (i, seedExpression) in widget.ensembleExpressions.indexed)
        _cycledExpression(
          seedExpression,
          seconds + offsets[i % offsets.length],
          period,
        ),
    ];
  }

  Expression _cycledExpression(
    Expression seedExpression,
    double seconds,
    double period,
  ) {
    const presets = [
      Expression.neutral,
      Expression.content,
      Expression.happy,
      Expression.surprised,
    ];
    final base = presets.indexWhere((e) => e.name == seedExpression.name);
    final phase = (seconds / period).floor();
    return presets[((base < 0 ? 0 : base) + phase) % presets.length];
  }
}
