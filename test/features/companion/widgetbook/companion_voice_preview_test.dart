import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/companion/widgetbook/companion_voice_preview.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';

import '../../../widget_test_utils.dart';

// The media_kit player is native and cannot run under `flutter test`; these
// cover everything up to it. Playing a clip is checked by hand in the
// widgetbook.

Widget _preview(String path) => makeTestableWidgetNoScroll(
  SizedBox(
    width: 600,
    height: 800,
    child: CompanionVoicePreview(
      look: CompanionLook.grandmaStage,
      mood: CompanionMood.bright,
      framing: CompanionFraming.bust,
      wavPath: path,
      text: '',
    ),
  ),
);

void main() {
  testWidgets('shows her, in the look and framing it is given', (tester) async {
    setTestSurfaceSize(tester, const Size(600, 800));
    await tester.pumpWidget(_preview(''));
    final view = tester.widget<CompanionView>(find.byType(CompanionView));
    expect(view.look, CompanionLook.grandmaStage);
    expect(view.mood, CompanionMood.bright);
    expect(view.framing, CompanionFraming.bust);
    expect(view.playhead!(), isNull);
  });

  testWidgets('Play is disabled until a file is named', (tester) async {
    setTestSurfaceSize(tester, const Size(600, 800));
    await tester.pumpWidget(_preview('  '));
    final button = tester.widget<DesignSystemButton>(
      find.byType(DesignSystemButton),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('a file that cannot be read shows the error, not a crash', (
    tester,
  ) async {
    setTestSurfaceSize(tester, const Size(600, 800));
    await tester.pumpWidget(_preview('/no/such/clip.wav'));
    await tester.tap(find.text('Play'));
    // Reading the file is real IO: give the event loop real IO round-trips
    // and pump until its failure lands (test/README.md, "Image decoding never
    // completes inside testWidgets").
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => File(
          '/no/such/clip.wav',
        ).readAsBytes().then((_) {}, onError: (Object _) {}),
      );
      await tester.pump();
      if (find.textContaining('PathNotFoundException').evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.textContaining('PathNotFoundException'), findsOneWidget);
    expect(
      tester.widget<CompanionView>(find.byType(CompanionView)).track,
      isNull,
    );
  });
}
