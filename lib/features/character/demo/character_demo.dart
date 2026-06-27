import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/character/engine/autonomic.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/runtime/character_painter.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';
import 'package:lotti/features/character/runtime/character_view.dart';
import 'package:lotti/features/character/samples/cat_in_suit.dart';

/// A standalone, interactive viewer for the character engine — a dev tool, not
/// a product surface. Run it directly:
///
/// ```sh
/// fvm flutter run -d macos -t lib/features/character/demo/character_demo.dart
/// ```
///
/// Pick a motion cycle and an expression and watch the rig animate live. This
/// is the live counterpart to the offline film strips.
///
/// **Keyboard** (the view is focused on launch):
/// - `1`–`7` — walk / run / kick / dance / sit / jump / idle
///   (also `←` / `→` to cycle)
/// - `N C H S D A` — neutral / content / happy / surprised / sad / angry
///   (also `↑` / `↓` to cycle)
/// - `B` — blink · `X` — auto-cycle faces · `M` — wander/in-place
/// - `Space` — play/pause · `0` — replay
void main() {
  runApp(const CharacterDemoApp());
}

/// Direct keyboard shortcut per expression, keyed by preset name. Shown on the
/// chips and handled in [_CharacterDemoPageState._handleKey].
const Map<String, String> kExpressionKeys = {
  'neutral': 'N',
  'content': 'C',
  'happy': 'H',
  'surprised': 'S',
  'sad': 'D',
  'angry': 'A',
};

const double kAuthoredDanceBpm = 120;
const double kDefaultDanceBpm = 124;

AutonomicLayer _danceAutonomic(int seed) => AutonomicLayer(
  seed: seed,
  blinkIntervalBase: 1.7,
  blinkIntervalJitter: 1.1,
  eyeDartInterval: 1.05,
  eyeDartAmplitude: 0.75,
);

class CharacterDemoApp extends StatelessWidget {
  const CharacterDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Character demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const CharacterDemoPage(),
    );
  }
}

class CharacterDemoPage extends StatefulWidget {
  const CharacterDemoPage({super.key});

  @override
  State<CharacterDemoPage> createState() => _CharacterDemoPageState();
}

class _CharacterDemoPageState extends State<CharacterDemoPage>
    with SingleTickerProviderStateMixin {
  late final CharacterScene _scene = CharacterScene(
    buildCatInSuitRig(
      legWidthScale: kDanceLeadLegWidthScale,
      armWidthScale: kDanceLeadArmWidthScale,
    ),
    autonomic: _danceAutonomic(11),
  );
  late final CharacterScene _partnerScene = CharacterScene(
    buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
    autonomic: _danceAutonomic(29),
  );
  late final CharacterScene _thirdScene = CharacterScene(
    buildCatInSuitRig(palette: CatInSuitPalette.darkBrown),
    autonomic: _danceAutonomic(47),
  );

  // Manual blink: a short controller whose value (0..1) is mapped to an eyelid
  // multiplier — a fast close then a slower open, the same asymmetry the
  // autonomic blink uses. It rests at 1 (eyes open) when not blinking.
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  final FocusNode _focus = FocusNode();

  Clip _clip = CatClips.dance;
  Expression _expression = Expression.neutral;
  double _danceBpm = kDefaultDanceBpm;
  bool _paused = false;

  // When true, walk/run travel across the stage and turn at the edges (the cat
  // "moves around"); off shows the cycle in place for pose review.
  bool _wander = true;

  // Bumped when a clip is (re)selected so one-shots (sit/jump) restart their
  // ticker via the keyed CharacterView.
  int _restart = 0;

  // When running, advances the expression on an interval (the "cycle faces"
  // option). Null = off; default off so widget tests leave no pending timer.
  Timer? _exprCycle;

  @override
  void dispose() {
    _exprCycle?.cancel();
    _blink.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _selectClip(Clip clip) => setState(() {
    _clip = clip;
    _restart++;
  });

  void _replay() => setState(() => _restart++);

  void _triggerBlink() => _blink.forward(from: 0);

  /// Toggles the auto-advance of expressions (the "cycle faces" option).
  void _toggleExpressionCycle() => setState(() {
    if (_exprCycle != null) {
      _exprCycle!.cancel();
      _exprCycle = null;
    } else {
      _exprCycle = Timer.periodic(
        const Duration(milliseconds: 1500),
        (_) => _cycleExpression(1),
      );
    }
  });

  void _cycleClip(int dir) {
    final all = CatClips.all;
    final i = all.indexWhere((c) => c.name == _clip.name);
    _selectClip(all[(i + dir) % all.length]);
  }

  void _cycleExpression(int dir) {
    const all = Expression.presets;
    final i = all.indexWhere((e) => e.name == _expression.name);
    setState(() => _expression = all[(i + dir) % all.length]);
  }

  void _setExpression(Expression e) => setState(() => _expression = e);

  bool get _showPair =>
      _clip.name == CatClips.walk.name || _clip.name == CatClips.dance.name;

  double get _playbackRate =>
      _clip.name == CatClips.dance.name ? _danceBpm / kAuthoredDanceBpm : 1;

  // Maps the blink controller value to an eyelid openness multiplier: a fast
  // close (first third) then a slower open, resting at 1 (eyes open).
  double _blinkScale(double v) {
    const closeFrac = 0.32;
    if (v <= 0 || v >= 1) return 1;
    return v < closeFrac
        ? 1 - v / closeFrac
        : (v - closeFrac) / (1 - closeFrac);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final all = CatClips.all;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.digit1:
        _selectClip(all[0]);
      case LogicalKeyboardKey.digit2:
        _selectClip(all[1]);
      case LogicalKeyboardKey.digit3:
        _selectClip(all[2]);
      case LogicalKeyboardKey.digit4:
        _selectClip(all[3]);
      case LogicalKeyboardKey.digit5:
        _selectClip(all[4]);
      case LogicalKeyboardKey.digit6:
        _selectClip(all[5]);
      case LogicalKeyboardKey.digit7:
        _selectClip(all[6]);
      case LogicalKeyboardKey.digit0:
        _replay();
      case LogicalKeyboardKey.arrowRight:
        _cycleClip(1);
      case LogicalKeyboardKey.arrowLeft:
        _cycleClip(-1);
      case LogicalKeyboardKey.arrowUp:
        _cycleExpression(1);
      case LogicalKeyboardKey.arrowDown:
        _cycleExpression(-1);
      case LogicalKeyboardKey.keyN:
        _setExpression(Expression.neutral);
      case LogicalKeyboardKey.keyC:
        _setExpression(Expression.content);
      case LogicalKeyboardKey.keyH:
        _setExpression(Expression.happy);
      case LogicalKeyboardKey.keyS:
        _setExpression(Expression.surprised);
      case LogicalKeyboardKey.keyD:
        _setExpression(Expression.sad);
      case LogicalKeyboardKey.keyA:
        _setExpression(Expression.angry);
      case LogicalKeyboardKey.keyB:
        _triggerBlink();
      case LogicalKeyboardKey.keyX:
        _toggleExpressionCycle();
      case LogicalKeyboardKey.keyM:
        setState(() => _wander = !_wander);
      case LogicalKeyboardKey.space:
        setState(() => _paused = !_paused);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Character demo (cat in a suit)'),
          actions: [
            IconButton(
              tooltip: _wander ? 'Walk in place (M)' : 'Wander (M)',
              icon: Icon(
                _wander ? Icons.directions_walk : Icons.flip_to_front,
              ),
              onPressed: () => setState(() => _wander = !_wander),
            ),
            IconButton(
              tooltip: 'Blink (B)',
              icon: const Icon(Icons.remove_red_eye_outlined),
              onPressed: _triggerBlink,
            ),
            IconButton(
              tooltip: _paused ? 'Play (Space)' : 'Pause (Space)',
              icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
              onPressed: () => setState(() => _paused = !_paused),
            ),
            IconButton(
              tooltip: 'Replay (0)',
              icon: const Icon(Icons.replay),
              onPressed: _replay,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF202A33), Color(0xFF2C3845)],
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Auto-fit: the rig is ~300 units tall, stand it at ~78% of
                    // the available height so it fills the stage at any size.
                    final scale = constraints.maxHeight * 0.78 / 300.0;
                    return AnimatedBuilder(
                      animation: _blink,
                      builder: (context, _) => CharacterView(
                        key: ValueKey('${_clip.name}-$_restart'),
                        scene: _scene,
                        partnerScene: _partnerScene,
                        ensembleScenes: _clip.name == CatClips.dance.name
                            ? [_partnerScene, _thirdScene]
                            : const [],
                        ensembleClips: _clip.name == CatClips.dance.name
                            ? [
                                CatClips.dance,
                                CatClips.danceBackupLeft,
                                CatClips.danceBackupRight,
                              ]
                            : const [],
                        ensembleExpressions: _clip.name == CatClips.dance.name
                            ? [
                                _expression,
                                Expression.content,
                                Expression.happy,
                              ]
                            : const [],
                        synchronousEnsemble: _clip.name == CatClips.dance.name,
                        clip: _clip,
                        expression: _expression,
                        scale: scale,
                        playbackRate: _playbackRate,
                        paused: _paused,
                        eyeOpenScale: _blinkScale(_blink.value),
                        groundColor: const Color(0xFF374551),
                        backdrop: _clip.name == CatClips.dance.name
                            ? CharacterBackdrop.waterfront
                            : CharacterBackdrop.none,
                        locomote: _wander,
                        walkingPair: _showPair,
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A prominent blink button (the immediate-blink action the
                  // reviewer reaches for) alongside the motion/expression picks.
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _triggerBlink,
                        icon: const Icon(Icons.remove_red_eye_outlined),
                        label: const Text('Blink'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonalIcon(
                        onPressed: _toggleExpressionCycle,
                        icon: Icon(
                          _exprCycle != null
                              ? Icons.stop
                              : Icons.auto_awesome_outlined,
                        ),
                        label: Text(
                          _exprCycle != null ? 'Stop cycle' : 'Cycle faces',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'B blink · X cycle',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.54),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Motion  ·  ← → to cycle'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final (i, clip) in CatClips.all.indexed)
                        ChoiceChip(
                          label: Text('${clip.name}  ${i + 1}'),
                          selected: _clip.name == clip.name,
                          onSelected: (_) => _selectClip(clip),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Expression  ·  ↑ ↓ to cycle'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final expression in Expression.presets)
                        ChoiceChip(
                          label: Text(
                            '${expression.name}  ${kExpressionKeys[expression.name] ?? ''}',
                          ),
                          selected: _expression.name == expression.name,
                          onSelected: (_) =>
                              setState(() => _expression = expression),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 78,
                        child: Text('BPM ${_danceBpm.round()}'),
                      ),
                      Expanded(
                        child: Slider(
                          min: 80,
                          max: 240,
                          divisions: 160,
                          value: _danceBpm,
                          onChanged: _clip.name == CatClips.dance.name
                              ? (value) => setState(() => _danceBpm = value)
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Space play/pause · 0 replay',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.54),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
