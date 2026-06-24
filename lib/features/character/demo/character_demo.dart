import 'package:flutter/material.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/face.dart';
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
void main() {
  runApp(const CharacterDemoApp());
}

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

class _CharacterDemoPageState extends State<CharacterDemoPage> {
  late final CharacterScene _scene = CharacterScene(buildCatInSuitRig());

  Clip _clip = CatClips.walk;
  Expression _expression = Expression.neutral;
  bool _paused = false;

  // Bumped when a clip is (re)selected so one-shots (sit/jump) restart their
  // ticker via the keyed CharacterView.
  int _restart = 0;

  void _selectClip(Clip clip) => setState(() {
    _clip = clip;
    _restart++;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Character demo (cat in a suit)'),
        actions: [
          IconButton(
            tooltip: _paused ? 'Play' : 'Pause',
            icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
            onPressed: () => setState(() => _paused = !_paused),
          ),
          IconButton(
            tooltip: 'Replay',
            icon: const Icon(Icons.replay),
            onPressed: () => setState(() => _restart++),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ColoredBox(
              color: const Color(0xFF26303A),
              child: Center(
                child: SizedBox(
                  width: 320,
                  height: 440,
                  child: CharacterView(
                    key: ValueKey('${_clip.name}-$_restart'),
                    scene: _scene,
                    clip: _clip,
                    expression: _expression,
                    scale: 1.15,
                    paused: _paused,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Motion'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final clip in CatClips.all)
                      ChoiceChip(
                        label: Text(clip.name),
                        selected: _clip.name == clip.name,
                        onSelected: (_) => _selectClip(clip),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Expression'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final expression in Expression.presets)
                      ChoiceChip(
                        label: Text(expression.name),
                        selected: _expression.name == expression.name,
                        onSelected: (_) =>
                            setState(() => _expression = expression),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
