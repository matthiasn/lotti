import 'package:flutter/widgets.dart';
import 'package:lotti/features/companion/animation/text_lip_sync.dart';
import 'package:lotti/features/companion/animation/tone_track.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/companion/widgetbook/companion_voice_preview.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:widgetbook/widgetbook.dart';

/// The line she says by default in the playground: praise, then something
/// that needs work, so her face has somewhere to go.
const defaultCompanionLine =
    'Good morning! You finished the migration, well done. '
    'The review is overdue, though, and the tests are falling behind. '
    'Four things today.';

/// Widgetbook folder for the in-app companion: Lotti, the grandmother of the
/// pitch videos, and the animals a person may pick instead, drawn live in
/// Flutter. One component per character, each with the same use cases.
WidgetbookFolder buildCompanionWidgetbookFolder() {
  return WidgetbookFolder(
    name: 'Companion',
    children: [
      for (final species in CompanionSpecies.values)
        _characterComponent(species),
    ],
  );
}

/// The component's name for [species].
String companionCharacterName(CompanionSpecies species) => switch (species) {
  CompanionSpecies.grandma => 'Lotti (grandma)',
  CompanionSpecies.cat => 'Cat',
  CompanionSpecies.redPanda => 'Red panda',
};

WidgetbookComponent _characterComponent(CompanionSpecies species) {
  final looks = CompanionLook.of(species);
  CompanionLook lookKnob(BuildContext context) => context.knobs.object.dropdown(
    label: 'Look',
    options: looks,
    labelBuilder: (l) => l.id,
  );
  return WidgetbookComponent(
    name: companionCharacterName(species),
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) => CompanionPlayground(
          look: lookKnob(context),
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
          sass: context.knobs.object.segmented(
            label: 'Sass',
            options: CompanionSass.values,
            labelBuilder: (s) => s.name,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Talking with a voice (WAV)',
        builder: (context) => CompanionVoicePreview(
          look: lookKnob(context),
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
            for (final look in looks) (look.id, look, CompanionMood.calm),
          ],
        ),
      ),
      WidgetbookUseCase(
        name: 'Moods',
        builder: (context) => _Lineup(
          framing: CompanionFraming.bust,
          entries: [
            for (final mood in CompanionMood.values)
              (mood.name, lookKnob(context), mood),
          ],
        ),
      ),
      WidgetbookUseCase(
        name: 'Reactions',
        builder: (context) => CompanionReactionGrid(look: lookKnob(context)),
      ),
      WidgetbookUseCase(
        name: 'Chat avatar sizes',
        builder: (context) => _AvatarSizes(look: lookKnob(context)),
      ),
    ],
  );
}

bool _stageKnob(BuildContext context) =>
    context.knobs.boolean(label: 'Stage backdrop', initialValue: true);

int _smoothingKnob(BuildContext context) => context.knobs.object.segmented(
  label: 'Smoothing (samples per pixel)',
  options: const [1, 2, 4],
  initialOption: CompanionView.platformSupersample,
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
/// ([TextLipSync]) on the view's own clock from the press of the button, and
/// her face follows how they land ([ToneTrack]) with [sass].
class CompanionPlayground extends StatefulWidget {
  const CompanionPlayground({
    required this.look,
    required this.mood,
    required this.framing,
    required this.line,
    required this.rate,
    required this.autoGestures,
    this.sass = CompanionSass.warm,
    this.stage = true,
    this.supersample,
    super.key,
  });

  final CompanionLook look;
  final CompanionMood mood;
  final CompanionFraming framing;
  final String line;
  final double rate;
  final bool autoGestures;
  final CompanionSass sass;
  final bool stage;
  final int? supersample;

  @override
  State<CompanionPlayground> createState() => _CompanionPlaygroundState();
}

class _CompanionPlaygroundState extends State<CompanionPlayground> {
  final _controller = CompanionController();
  TextLipSync? _track;
  ToneTrack? _tone;
  double _startedAt = 0;

  void _say() {
    setState(() {
      final track = TextLipSync(widget.line, rate: widget.rate);
      _track = track;
      _tone = ToneTrack.read(widget.line, track);
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
              tone: _tone,
              sass: widget.sass,
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

/// Every [companionReaction] at once: a row per [CompanionSass], from the
/// lowest approval on the left to the highest on the right, each holding its
/// gesture.
class CompanionReactionGrid extends StatelessWidget {
  const CompanionReactionGrid({required this.look, super.key});

  final CompanionLook look;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final caption = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step5),
      child: Column(
        children: [
          for (final sass in CompanionSass.values)
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: tokens.spacing.step10,
                    child: Text(sass.name, style: caption),
                  ),
                  for (var a = minApproval; a <= maxApproval; a++)
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: CompanionView(
                              look: look,
                              mood: companionReaction(a, sass: sass).mood,
                              holding: companionReaction(a, sass: sass).gesture,
                              autoGestures: false,
                              stage: true,
                              seed: 11 + a * 7 + sass.index * 3,
                            ),
                          ),
                          Text(
                            '${a > 0 ? '+' : ''}$a · '
                            '${companionReaction(a, sass: sass).mood.name}',
                            style: caption,
                          ),
                        ],
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
