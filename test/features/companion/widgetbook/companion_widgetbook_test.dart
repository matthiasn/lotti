import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_flourish.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/rig/supersampled_painter.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/companion/widgetbook/companion_widgetbook.dart';
import 'package:widgetbook/widgetbook.dart';

import '../../../widget_test_utils.dart';

Widget _host(Widget child) => makeTestableWidgetNoScroll(
  SizedBox(width: 1400, height: 900, child: child),
);

CompanionPose _pose(WidgetTester tester) =>
    ((tester
                        .widget<CustomPaint>(
                          find.descendant(
                            of: find.byType(CompanionView),
                            matching: find.byWidgetPredicate(
                              (w) =>
                                  w is CustomPaint &&
                                  w.painter is SupersampledPainter,
                            ),
                          ),
                        )
                        .painter!
                    as SupersampledPainter)
                .inner
            as CompanionPainter)
        .pose;

const _playground = CompanionPlayground(
  look: CompanionLook.grandma,
  mood: CompanionMood.calm,
  framing: CompanionFraming.full,
  line: 'Good morning! Four things today.',
  rate: 1,
  autoGestures: false,
);

void main() {
  List<WidgetbookComponent> components() =>
      buildCompanionWidgetbookFolder().children!.cast<WidgetbookComponent>();

  test('the folder has one component per character, each with every use '
      'case', () {
    final folder = buildCompanionWidgetbookFolder();
    expect(folder.name, 'Companion');
    expect(components().map((c) => c.name), [
      'Lotti (grandma)',
      'Cat',
      'Red panda',
    ]);
    for (final component in components()) {
      expect(component.useCases.map((u) => u.name), [
        'Playground',
        'Talking with a voice (WAV)',
        'Looks',
        'Moods',
        'Reactions',
        'Chat avatar sizes',
      ]);
    }
  });

  for (final species in CompanionSpecies.values) {
    testWidgets("${species.name}'s Looks use case shows its own looks only", (
      tester,
    ) async {
      final component = components().firstWhere(
        (c) => c.name == companionCharacterName(species),
      );
      final looks = component.useCases.firstWhere((u) => u.name == 'Looks');
      setTestSurfaceSize(tester, const Size(1400, 900));
      await tester.pumpWidget(_host(Builder(builder: looks.builder)));
      await tester.pump(const Duration(milliseconds: 16));
      final views = tester.widgetList<CompanionView>(
        find.byType(CompanionView),
      );
      expect(views.map((v) => v.look), CompanionLook.of(species));
      expect(views.every((v) => v.look.species == species), isTrue);
      for (final look in CompanionLook.of(species)) {
        expect(find.text(look.id), findsOneWidget);
      }
    });
  }

  testWidgets('Reactions shows every sass at every approval, each holding '
      'its gesture', (tester) async {
    setTestSurfaceSize(tester, const Size(1400, 900));
    await tester.pumpWidget(
      _host(const CompanionReactionGrid(look: CompanionLook.cat)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    final views = tester
        .widgetList<CompanionView>(find.byType(CompanionView))
        .toList();
    expect(views, hasLength(CompanionSass.values.length * 7));
    var i = 0;
    for (final sass in CompanionSass.values) {
      expect(find.text(sass.name), findsOneWidget);
      for (var a = minApproval; a <= maxApproval; a++) {
        final cue = companionReaction(a, sass: sass);
        expect(views[i].mood, cue.mood, reason: '${sass.name} $a');
        expect(views[i].holding, cue.gesture, reason: '${sass.name} $a');
        expect(views[i].look, CompanionLook.cat);
        i++;
      }
    }
  });

  group('CompanionPlayground', () {
    testWidgets('has a button per flourish, each one pulls its face', (
      tester,
    ) async {
      setTestSurfaceSize(tester, const Size(1400, 900));
      await tester.pumpWidget(_host(_playground));
      for (final f in CompanionFlourish.values) {
        expect(
          find.byKey(ValueKey('companion_flourish_${f.name}')),
          findsOneWidget,
        );
      }
      await tester.tap(
        find.byKey(
          ValueKey('companion_flourish_${CompanionFlourish.wink.name}'),
        ),
      );
      var shut = 0.0;
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        shut = math.max(
          shut,
          _pose(tester).blinkOf(1) - _pose(tester).blinkOf(-1),
        );
      }
      expect(shut, greaterThan(0.5));
    });

    testWidgets('has a button per gesture, each one plays it', (tester) async {
      setTestSurfaceSize(tester, const Size(1400, 900));
      await tester.pumpWidget(_host(_playground));
      expect(
        find.byKey(ValueKey('companion_gesture_${GestureName.wave.name}')),
        findsOneWidget,
      );
      for (final g in GestureName.values) {
        expect(find.text(g.name), findsOneWidget);
      }
      await tester.tap(find.text(GestureName.celebrate.name));
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_pose(tester).left.wrist.dy, lessThan(-130));
      expect(_pose(tester).right.wrist.dy, lessThan(-130));
    });

    testWidgets('"Say the line" talks for as long as the line runs', (
      tester,
    ) async {
      setTestSurfaceSize(tester, const Size(1400, 900));
      await tester.pumpWidget(_host(_playground));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_pose(tester).mouth.open, 0);

      await tester.tap(find.byKey(const ValueKey('companion_say')));
      final opens = <double>[];
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        opens.add(_pose(tester).mouth.open);
      }
      final widest = opens.reduce((a, b) => a > b ? a : b);
      // The line runs about two seconds, then she falls quiet.
      expect(opens.sublist(260).every((o) => o == 0), isTrue);
      expect(widest, greaterThan(3));
    });

    testWidgets('her face follows the line, with the sass it is given', (
      tester,
    ) async {
      setTestSurfaceSize(tester, const Size(1400, 900));
      await tester.pumpWidget(
        _host(
          const CompanionPlayground(
            look: CompanionLook.grandma,
            mood: CompanionMood.calm,
            framing: CompanionFraming.full,
            line: defaultCompanionLine,
            rate: 1,
            autoGestures: false,
            sass: CompanionSass.sassy,
          ),
        ),
      );
      CompanionView shown() =>
          tester.widget<CompanionView>(find.byType(CompanionView));
      expect(shown().tone, isNull);
      expect(shown().sass, CompanionSass.sassy);

      await tester.tap(find.byKey(const ValueKey('companion_say')));
      await tester.pump();
      // The default line has praise and something that needs work.
      final approvals = shown().tone!.cues.map((c) => c.approval).toList();
      expect(approvals.any((a) => a != null && a > 0), isTrue);
      expect(approvals.any((a) => a != null && a < 0), isTrue);
    });
  });
}
