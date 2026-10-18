import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/companion_stage_page.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/summary_read_aloud_button.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/spoken_track.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../../tts/test_utils.dart';

/// She ticks for as long as she is mounted: pump frames, never settle.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  Future<void> openStage(
    WidgetTester tester, {
    bool readAloud = true,
    bool engineSupported = true,
    Stream<bool>? readAloudFlag,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => openCompanionStage(
              context,
              sourceId: 'task-1',
              spokenText: 'Two items left.',
            ),
            child: const Text('open'),
          ),
        ),
        overrides: [
          configFlagProvider.overrideWith(
            (ref, flagName) => flagName != enableAiSummaryTtsFlag
                ? Stream.value(false)
                : readAloudFlag ?? Stream.value(readAloud),
          ),
          ttsEngineProvider.overrideWithValue(
            FakeTtsEngine(supported: engineSupported),
          ),
          spokenTrackLoaderProvider.overrideWithValue(
            (clip, text) => Completer<MouthTrack>().future,
          ),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await _pumpFrames(tester);
    // The page route's own entrance.
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('stands her head to toe on her stage, filling the screen, '
      "speaking this summary's utterance", (tester) async {
    await openStage(tester);

    expect(find.byType(CompanionStagePage), findsOneWidget);
    final speaker = tester.widget<CompanionSpeaker>(
      find.byType(CompanionSpeaker),
    );
    expect(speaker.sourceId, 'task-1');
    expect(speaker.framing, CompanionFraming.full);
    expect(speaker.stage, isTrue);
    expect(
      tester.getSize(find.byType(CompanionView)),
      tester.getSize(find.byType(CompanionStagePage)),
    );
  });

  testWidgets('offers the read-aloud control for the words the card showed', (
    tester,
  ) async {
    await openStage(tester);

    final readAloud = tester.widget<SummaryReadAloudButton>(
      find.byType(SummaryReadAloudButton),
    );
    expect(readAloud.sourceId, 'task-1');
    expect(readAloud.text, 'Two items left.');
    // At her feet, below the close control.
    expect(
      tester.getCenter(find.byType(SummaryReadAloudButton)).dy,
      greaterThan(tester.getCenter(find.byTooltip('Close')).dy),
    );
  });

  for (final (readAloud, engineSupported, why) in [
    (false, true, 'read-aloud is off'),
    (true, false, 'the device has no voice'),
  ]) {
    testWidgets('offers no read-aloud control while $why', (tester) async {
      await openStage(
        tester,
        readAloud: readAloud,
        engineSupported: engineSupported,
      );

      expect(find.byType(CompanionStagePage), findsOneWidget);
      expect(find.byType(SummaryReadAloudButton), findsNothing);
    });
  }

  testWidgets('takes the control away when read-aloud is turned off while '
      'she is open, as a synced change does', (tester) async {
    final flag = StreamController<bool>();
    addTearDown(flag.close);
    flag.add(true);
    await openStage(tester, readAloudFlag: flag.stream);
    expect(find.byType(SummaryReadAloudButton), findsOneWidget);

    flag.add(false);
    await _pumpFrames(tester);

    expect(find.byType(CompanionStagePage), findsOneWidget);
    expect(find.byType(SummaryReadAloudButton), findsNothing);
  });

  testWidgets('names itself to a screen reader as it opens', (tester) async {
    final semantics = tester.ensureSemantics();
    await openStage(tester);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Companion, full screen')),
      matchesSemantics(
        label: 'Companion, full screen',
        scopesRoute: true,
        namesRoute: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('keeps the system bars light over her dark stage', (
    tester,
  ) async {
    await openStage(tester);

    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find
          .descendant(
            of: find.byType(CompanionStagePage),
            matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .first,
    );
    expect(region.value, SystemUiOverlayStyle.light);
  });

  testWidgets('the close control takes her back to the card', (tester) async {
    await openStage(tester);

    await tester.tap(find.byTooltip('Close'));
    await _pumpFrames(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CompanionStagePage), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
