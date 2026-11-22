import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/speak_add_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onSpeak,
    VoidCallback? onAdd,
    String? recordingLabel,
  }) => tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: DesignSystemSpeakAddBar(
          speakKey: const ValueKey('speak'),
          addKey: const ValueKey('add'),
          speakLabel: 'Speak',
          addLabel: 'Add',
          addSemanticLabel: 'Add to this goal',
          recordingLabel: recordingLabel,
          onSpeak: onSpeak ?? () {},
          onAdd: onAdd ?? () {},
        ),
      ),
    ),
  );

  testWidgets('Speak is the filled pill under the app mic, and each control '
      'runs its own action', (tester) async {
    var speaks = 0;
    var adds = 0;
    await pump(tester, onSpeak: () => speaks++, onAdd: () => adds++);
    final tokens = tester
        .element(find.byKey(const ValueKey('speak')))
        .designTokens;

    final speak = tester.widget<DsGlassPill>(
      find.byKey(const ValueKey('speak')),
    );
    expect(speak.icon, LottiIcons.mic);
    expect(speak.label, 'Speak');
    expect(speak.fillColor, tokens.colors.interactive.enabled);
    // Add is the quiet pill: no fill of its own.
    final add = tester.widget<DsGlassPill>(find.byKey(const ValueKey('add')));
    expect(add.icon, LottiIcons.add);
    expect(add.fillColor, isNull);

    await tester.tap(find.byKey(const ValueKey('speak')));
    await tester.tap(find.byKey(const ValueKey('add')));
    expect((speaks, adds), (1, 1));
  });

  testWidgets("while this subject's take is running the pill says so in "
      'the recording red, and the same tap goes back to it', (tester) async {
    var speaks = 0;
    await pump(tester, onSpeak: () => speaks++, recordingLabel: 'Recording');
    final tokens = tester
        .element(find.byKey(const ValueKey('speak')))
        .designTokens;

    final speak = tester.widget<DsGlassPill>(
      find.byKey(const ValueKey('speak')),
    );
    expect(speak.label, 'Recording');
    expect(speak.icon, LottiIcons.mic);
    expect(speak.fillColor, tokens.colors.alert.error.defaultColor);
    expect(find.text('Speak'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('speak')));
    expect(speaks, 1);
  });

  testWidgets('the + control says what it adds to, and that name reaches '
      'its action', (tester) async {
    final handle = tester.ensureSemantics();
    var adds = 0;
    await pump(tester, onAdd: () => adds++);

    final named = find.bySemanticsLabel('Add to this goal');
    expect(named, findsOneWidget);
    await tester.tap(named);
    expect(adds, 1);
    handle.dispose();
  });

  testWidgets('at large text on a narrow phone the controls wrap instead of '
      'overflowing', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('add'))).dy,
      greaterThan(tester.getTopLeft(find.byKey(const ValueKey('speak'))).dy),
    );
  });
}
