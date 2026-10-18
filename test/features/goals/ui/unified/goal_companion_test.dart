import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/ui/unified/goal_companion.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  test("a goal report's speech is its own utterance, apart from tasks", () {
    expect(goalReportSpeechSourceId('goal-1'), 'goal-report:goal-1');
    expect(
      goalReportSpeechSourceId('goal-1'),
      isNot(goalReportSpeechSourceId('goal-2')),
    );
  });

  group('goalCompanionPose', () {
    test('gives every track status a gesture and mood without guilt', () {
      const expected = {
        GoalTrackStatus.achieved: (
          mood: CompanionMood.bright,
          gesture: GestureName.celebrate,
        ),
        GoalTrackStatus.onTrack: (
          mood: CompanionMood.bright,
          gesture: GestureName.thumbs,
        ),
        GoalTrackStatus.recovering: (
          mood: CompanionMood.calm,
          gesture: GestureName.clap,
        ),
        GoalTrackStatus.atRisk: (
          mood: CompanionMood.busy,
          gesture: GestureName.think,
        ),
        GoalTrackStatus.offTrack: (
          mood: CompanionMood.frazzled,
          gesture: GestureName.palmsDown,
        ),
        GoalTrackStatus.insufficientData: (
          mood: CompanionMood.sleepy,
          gesture: GestureName.listen,
        ),
      };
      // Every status is mapped: a new one must be given a pose here.
      expect(expected.keys.toSet(), GoalTrackStatus.values.toSet());
      for (final MapEntry(key: status, value: pose) in expected.entries) {
        expect(
          goalCompanionPose(status, resolved: true),
          pose,
          reason: status.name,
        );
      }
      // Each status reads apart from the others at a glance.
      expect(
        expected.values.map((p) => p.gesture).toSet(),
        hasLength(expected.length),
      );
    });

    test('a resolved goal with no status yet listens, sleepy', () {
      expect(
        goalCompanionPose(null, resolved: true),
        (mood: CompanionMood.sleepy, gesture: GestureName.listen),
      );
    });

    test('stands calm and at ready until the health resolves', () {
      for (final status in [null, ...GoalTrackStatus.values]) {
        expect(
          goalCompanionPose(status, resolved: false),
          (mood: CompanionMood.calm, gesture: null),
        );
      }
    });
  });

  testWidgets('GoalCompanionBust is a silent bust in a compact tile on the '
      'status wash', (tester) async {
    const fill = Color(0x3300FF00);
    await tester.pumpWidget(
      makeTestableWidget(
        // Loose, as the card's header row hands it.
        const Align(
          alignment: Alignment.topLeft,
          child: GoalCompanionBust(
            pose: (
              mood: CompanionMood.frazzled,
              gesture: GestureName.palmsDown,
            ),
            fill: fill,
            seed: 7,
          ),
        ),
      ),
    );
    // She ticks for as long as she is mounted: pump frames, never settle.
    await tester.pump(const Duration(milliseconds: 16));

    final tile = tester.widget<Container>(
      find
          .ancestor(
            of: find.byType(CompanionView),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = tile.decoration! as BoxDecoration;
    expect(decoration.color, fill);
    expect(tile.clipBehavior, Clip.antiAlias);
    expect(
      tester.getSize(find.byWidget(tile)),
      const Size.square(ControlSizes.avatarCompact),
    );

    final view = tester.widget<CompanionView>(find.byType(CompanionView));
    expect(view.framing, CompanionFraming.bust);
    expect(view.mood, CompanionMood.frazzled);
    expect(view.holding, GestureName.palmsDown);
    expect(view.autoGestures, isFalse);
    expect(view.track, isNull);
    expect(view.seed, 7);

    // Decorative: the status pill carries the verdict in words.
    final semantics = tester.getSemantics(find.byType(GoalCompanionBust));
    expect(semantics.label, isEmpty);
  });
}
