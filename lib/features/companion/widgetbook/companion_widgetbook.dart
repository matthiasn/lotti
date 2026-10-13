import 'package:flutter/widgets.dart';
import 'package:lotti/features/companion/animation/text_lip_sync.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/companion/widgetbook/companion_voice_preview.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:widgetbook/widgetbook.dart';

/// The line she says by default in the playground.
const defaultCompanionLine =
    'Good morning! Four things today. The big one is the migration, at ten. '
    'And you have a walk planned, which I fully support.';

/// Widgetbook folder for the in-app companion: Lotti, the grandmother of the
/// pitch videos, drawn live in Flutter.
WidgetbookFolder buildCompanionWidgetbookFolder() {
  return WidgetbookFolder(
    name: 'Companion',
    children: [
      WidgetbookComponent(
        name: 'Lotti (grandma)',
        useCases: [
          WidgetbookUseCase(
            name: 'Playground',
            builder: (context) => CompanionPlayground(
              look: _lookKnob(context),
              mood: _moodKnob(context),
              framing: context.knobs.object.segmented(
                label: 'Framing',
                options: CompanionFraming.values,
                labelBuilder: (f) => f.name,
              ),
              stage: _stageKnob(context),
              supersample: _smoothingKnob(context),
              line: context.knobs.string(
                label: 'Line',
                initialValue: defaultCompanionLine,
                maxLines: 4,
              ),
              rate: context.knobs.double.slider(
                label: 'Speaking rate',
                initialValue: 1,
                min: 0.6,
                max: 1.6,
                divisions: 10,
              ),
              autoGestures: context.knobs.boolean(
                label: 'Gestures while talking',
                initialValue: true,
              ),
            ),
          ),
          WidgetbookUseCase(
            name: 'Talking with a voice (WAV)',
            builder: (context) => CompanionVoicePreview(
              look: _lookKnob(context),
              mood: _moodKnob(context),
              framing: context.knobs.object.segmented(
                label: 'Framing',
                options: CompanionFraming.values,
                initialOption: CompanionFraming.bust,
                labelBuilder: (f) => f.name,
              ),
              stage: _stageKnob(context),
              supersample: _smoothingKnob(context),
              wavPath: context.knobs.string(
                label: 'WAV file (16-bit PCM)',
              ),
              text: context.knobs.string(
                label: 'Its words (optional, for mouth shapes)',
                maxLines: 4,
              ),
            ),
          ),
          WidgetbookUseCase(
            name: 'Looks',
            builder: (context) => _Lineup(
              framing: CompanionFraming.full,
              entries: [
                for (final look in CompanionLook.all)
                  (look.id, look, CompanionMood.calm),
              ],
            ),
          ),
          WidgetbookUseCase(
            name: 'Moods',
            builder: (context) => _Lineup(
              framing: CompanionFraming.bust,
              entries: [
                for (final mood in CompanionMood.values)
                  (mood.name, _lookKnob(context), mood),
              ],
            ),
          ),
          WidgetbookUseCase(
            name: 'Chat avatar sizes',
            builder: (context) => _AvatarSizes(look: _lookKnob(context)),
          ),
        ],
      ),
    ],
  );
}

CompanionLook _lookKnob(BuildContext context) => context.knobs.object.dropdown(
  label: 'Look',
  options: CompanionLook.all,
  labelBuilder: (l) => l.id,
);

bool _stageKnob(BuildContext context) =>
    context.knobs.boolean(label: 'Stage backdrop', initialValue: true);

int _smoothingKnob(BuildContext context) => context.knobs.object.segmented(
  label: 'Smoothing (samples per pixel)',
  options: const [1, 2, 4],
  initialOption: 4,
  labelBuilder: (f) => '$f×',
);

CompanionMood _moodKnob(BuildContext context) => context.knobs.object.dropdown(
  label: 'Mood',
  options: CompanionMood.values,
  labelBuilder: (m) => m.name,
);

/// Her, live, with a button to say the line and one per gesture.
///
/// The line is spoken silently: the mouth follows the words
/// ([TextLipSync]) on the view's own clock from the press of the button.
class CompanionPlayground extends StatefulWidget {
  const CompanionPlayground({
    required this.look,
    required this.mood,
    required this.framing,
    required this.line,
    required this.rate,
    required this.autoGestures,
    this.stage = true,
    this.supersample = 4,
    super.key,
  });

  final CompanionLook look;
  final CompanionMood mood;
  final CompanionFraming framing;
  final String line;
  final double rate;
  final bool autoGestures;
  final bool stage;
  final int supersample;

  @override
  State<CompanionPlayground> createState() => _CompanionPlaygroundState();
}

class _CompanionPlaygroundState extends State<CompanionPlayground> {
  final _controller = CompanionController();
  TextLipSync? _track;
  double _startedAt = 0;

  void _say() {
    setState(() {
      _track = TextLipSync(widget.line, rate: widget.rate);
      _startedAt = _controller.time;
    });
  }

  /// The line's playhead on the view's own clock.
  Duration? _playhead() {
    final track = _track;
    if (track == null) return null;
    final elapsed = Duration(
      microseconds: ((_controller.time - _startedAt) * 1e6).round(),
    );
    if (elapsed > track.length) {
      _track = null;
      return null;
    }
    return elapsed;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
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
              playhead: _playhead,
              autoGestures: widget.autoGestures,
              controller: _controller,
            ),
          ),
          SizedBox(height: tokens.spacing.step4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: tokens.spacing.step2,
            runSpacing: tokens.spacing.step2,
            children: [
              DesignSystemButton(
                key: const ValueKey('companion_say'),
                label: 'Say the line',
                onPressed: _say,
              ),
              for (final g in GestureName.values)
                DesignSystemButton(
                  key: ValueKey('companion_gesture_${g.name}'),
                  label: g.name,
                  variant: DesignSystemButtonVariant.secondary,
                  onPressed: () => _controller.play(g),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Several of her side by side, each captioned.
class _Lineup extends StatelessWidget {
  const _Lineup({required this.framing, required this.entries});

  final CompanionFraming framing;
  final List<(String, CompanionLook, CompanionMood)> entries;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step5),
      child: Row(
        children: [
          for (final (i, (caption, look, mood)) in entries.indexed)
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: CompanionView(
                      look: look,
                      mood: mood,
                      framing: framing,
                      stage: true,
                      seed: 11 + i * 7,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step2),
                  Text(
                    caption,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.lowEmphasis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Her bust at the sizes a chat or a card would show her, to judge what
/// still reads.
class _AvatarSizes extends StatelessWidget {
  const _AvatarSizes({required this.look});

  final CompanionLook look;

  static const sizes = [40.0, 64.0, 96.0, 160.0];

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Center(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: tokens.spacing.step6,
        children: [
          for (final size in sizes)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.colors.background.level02,
                    borderRadius: BorderRadius.circular(tokens.radii.m),
                  ),
                  child: SizedBox.square(
                    dimension: size,
                    child: CompanionView(
                      look: look,
                      framing: CompanionFraming.bust,
                    ),
                  ),
                ),
                SizedBox(height: tokens.spacing.step2),
                Text(
                  '${size.round()} px',
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
