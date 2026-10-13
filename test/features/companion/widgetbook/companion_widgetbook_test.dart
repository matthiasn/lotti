import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
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
                            matching: find.byType(CustomPaint),
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
  test('the folder lists the companion use cases', () {
    final folder = buildCompanionWidgetbookFolder();
    expect(folder.name, 'Companion');
    final component = folder.children!.single as WidgetbookComponent;
    expect(component.name, 'Lotti (grandma)');
    expect(component.useCases.map((u) => u.name), [
      'Playground',
      'Talking with a voice (WAV)',
      'Looks',
      'Moods',
      'Chat avatar sizes',
    ]);
  });

  testWidgets('the Looks use case shows every look side by side', (
    tester,
  ) async {
    final component =
        buildCompanionWidgetbookFolder().children!.single
            as WidgetbookComponent;
    final looks = component.useCases.firstWhere((u) => u.name == 'Looks');
    setTestSurfaceSize(tester, const Size(1400, 900));
    await tester.pumpWidget(_host(Builder(builder: looks.builder)));
    await tester.pump(const Duration(milliseconds: 16));
    final views = tester.widgetList<CompanionView>(find.byType(CompanionView));
    expect(views.map((v) => v.look), CompanionLook.all);
    for (final look in CompanionLook.all) {
      expect(find.text(look.id), findsOneWidget);
    }
  });

  group('CompanionPlayground', () {
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
  });
}
