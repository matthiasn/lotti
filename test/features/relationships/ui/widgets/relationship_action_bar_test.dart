import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_action_bar.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  late int speaks;
  late int adds;

  setUp(() {
    speaks = 0;
    adds = 0;
  });

  Future<void> pump(WidgetTester tester, {Size? size}) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        RelationshipActionBar(
          personName: 'Pip',
          onSpeak: () => speaks++,
          onAdd: () => adds++,
        ),
      ),
    );
  }

  testWidgets('two labelled controls: Speak, the filled primary, and Add', (
    tester,
  ) async {
    await pump(tester);

    final pills = tester.widgetList<DsGlassPill>(find.byType(DsGlassPill));
    expect(pills.map((p) => p.label), ['Speak', 'Add']);
    expect(pills.first.fillColor, isNotNull, reason: 'Speak is the primary');
    expect(pills.last.fillColor, isNull, reason: 'Add is glass');
    // No unlabelled discs: every control says what it does.
    expect(find.byType(DsGlassRoundButton), findsNothing);
  });

  testWidgets('each control does its own thing', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('person-action-speak')));
    await tester.tap(find.byKey(const ValueKey('person-action-add')));

    expect(speaks, 1);
    expect(adds, 1);
  });

  testWidgets('Add names whose timeline it adds to, for a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    expect(find.bySemanticsLabel("Add to Pip's timeline"), findsOneWidget);
    handle.dispose();
  });

  testWidgets('at a narrow width and large text the controls wrap rather '
      'than overflow', (tester) async {
    // The surface and the harness's own MediaQuery both narrow and large: a
    // MediaQuery wrapped around the harness is replaced by the one it
    // builds inside, so the text scale has to go through it.
    const narrow = Size(240, 600);
    setTestSurfaceSize(tester, narrow);
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        RelationshipActionBar(
          personName: 'Pip',
          onSpeak: () {},
          onAdd: () {},
        ),
        mediaQueryData: const MediaQueryData(
          size: narrow,
          textScaler: TextScaler.linear(2),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final speak = tester.getRect(
      find.byKey(const ValueKey('person-action-speak')),
    );
    final add = tester.getRect(find.byKey(const ValueKey('person-action-add')));
    expect(add.top, greaterThan(speak.top), reason: 'Add took a second line');
  });
}
