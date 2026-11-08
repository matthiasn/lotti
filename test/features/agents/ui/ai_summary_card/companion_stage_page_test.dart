import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/companion_stage_page.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/summary_read_aloud_button.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';
import 'package:lotti/features/companion/state/spoken_track.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';
import '../../../companion/companion_overrides.dart';
import '../../../tts/test_utils.dart';

/// Whether the host would have her point at its panel, switched by a test.
class _Pointing extends Notifier<bool> {
  @override
  bool build() => true;

  void stop() => state = false;
}

final _pointingProvider = NotifierProvider<_Pointing, bool>(_Pointing.new);

/// She ticks for as long as she is mounted: pump frames, never settle.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  /// Lotti's outfits, in order: what the stage's palette steps through.
  final companionOutfits = CompanionLook.of(CompanionSpecies.grandma);

  Future<void> openStage(
    WidgetTester tester, {
    CompanionMood? mood,
    GestureName? holding,
    bool readAloud = true,
    bool engineSupported = true,
    Stream<bool>? readAloudFlag,
    Widget? hostControl,
    Widget? sidePanel,
    ProviderListenable<bool>? pointsAtSidePanel,
    String? dressedFor,
    bool surprise = false,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => mood == null
                ? openCompanionStage(
                    context,
                    sourceId: 'task-1',
                    spokenText: 'Two items left.',
                    controls: hostControl,
                    sidePanel: sidePanel,
                    pointsAtSidePanel: pointsAtSidePanel,
                    dressedFor: dressedFor,
                  )
                : openCompanionStage(
                    context,
                    sourceId: 'task-1',
                    spokenText: 'Two items left.',
                    mood: mood,
                    holding: holding,
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
          if (surprise) ...[
            companionOutfitSeedProvider.overrideWithValue(7),
            companionCustomizationProvider.overrideWithBuild(
              (ref, notifier) => const CompanionCustomization(),
            ),
          ] else
            ...companionLookOverrides(outfit: companionOutfits.first),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await _pumpFrames(tester);
    // The page route's own entrance.
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('stands her head to toe on her stage, the width of the screen '
      "and down to its controls, speaking this summary's utterance", (
    tester,
  ) async {
    await openStage(tester);

    expect(find.byType(CompanionStagePage), findsOneWidget);
    final speaker = tester.widget<CompanionSpeaker>(
      find.byType(CompanionSpeaker),
    );
    expect(speaker.sourceId, 'task-1');
    expect(speaker.framing, CompanionFraming.full);
    expect(speaker.stage, isTrue);
    final page = tester.getRect(find.byType(CompanionStagePage));
    final figure = tester.getRect(find.byType(CompanionView));
    expect(figure.width, page.width);
    expect(figure.top, page.top);
    // The controls stand in a band of their own below her: nothing is drawn
    // on her.
    expect(
      tester.getRect(find.byType(SummaryReadAloudButton)).top,
      greaterThanOrEqualTo(figure.bottom),
    );
  });

  testWidgets('stands calm and at ready unless the host poses her', (
    tester,
  ) async {
    await openStage(tester);

    final speaker = tester.widget<CompanionSpeaker>(
      find.byType(CompanionSpeaker),
    );
    expect(speaker.mood, CompanionMood.calm);
    expect(speaker.holding, isNull);
  });

  testWidgets("keeps the host's pose, so she stands up as she was tapped", (
    tester,
  ) async {
    await openStage(
      tester,
      mood: CompanionMood.busy,
      holding: GestureName.think,
    );

    final speaker = tester.widget<CompanionSpeaker>(
      find.byType(CompanionSpeaker),
    );
    expect(speaker.mood, CompanionMood.busy);
    expect(speaker.holding, GestureName.think);
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

  testWidgets("a host's own read-aloud control stands at her feet in place "
      "of the summary's", (tester) async {
    await openStage(
      tester,
      hostControl: const SizedBox(key: Key('host-voice'), width: 44),
    );

    expect(find.byKey(const Key('host-voice')), findsOneWidget);
    expect(find.byType(SummaryReadAloudButton), findsNothing);
    expect(
      tester.getCenter(find.byKey(const Key('host-voice'))).dy,
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

  testWidgets('the outfit control changes her into her next outfit, and '
      'back round to the first', (tester) async {
    await openStage(tester);
    String worn() =>
        tester.widget<CompanionView>(find.byType(CompanionView)).look.id;
    expect(worn(), companionOutfits.first.id);

    final outfit = find.byKey(const ValueKey('companionStageOutfit'));
    expect(find.bySemanticsLabel('Change outfit'), findsOneWidget);
    await tester.tap(outfit);
    await tester.pump();
    expect(worn(), companionOutfits[1].id);

    for (var i = 1; i < companionOutfits.length; i++) {
      await tester.tap(outfit);
      await tester.pump();
    }
    expect(worn(), companionOutfits.first.id);
  });

  group('her outfit', () {
    CompanionSpeaker speaker(WidgetTester tester) =>
        tester.widget<CompanionSpeaker>(find.byType(CompanionSpeaker));

    testWidgets('is drawn for the summary she speaks, as on its card', (
      tester,
    ) async {
      await openStage(tester);
      expect(
        tester
            .widget<CompanionStagePage>(find.byType(CompanionStagePage))
            .dressedFor,
        'task-1',
      );
      expect(speaker(tester).dressedFor, 'task-1');
    });

    testWidgets('is drawn for the subject a host names instead', (
      tester,
    ) async {
      await openStage(tester, dressedFor: 'front-chat');
      expect(speaker(tester).sourceId, 'task-1');
      expect(speaker(tester).dressedFor, 'front-chat');
    });

    testWidgets('on "Surprise me" the control steps on from the outfit she '
        'is shown in', (tester) async {
      await openStage(tester, surprise: true);
      final roll = CompanionLookRoll(
        customization: const CompanionCustomization(),
        picked: null,
        seed: 7,
      );
      final shown = roll.outfitFor('task-1');
      String worn() =>
          tester.widget<CompanionView>(find.byType(CompanionView)).look.id;
      expect(worn(), shown.id);

      await tester.tap(find.byKey(const ValueKey('companionStageOutfit')));
      await tester.pump();
      final at = companionOutfits.indexOf(shown);
      expect(
        worn(),
        companionOutfits[(at + 1) % companionOutfits.length].id,
      );
    });
  });

  testWidgets('the close control takes her back to the card', (tester) async {
    await openStage(tester);

    await tester.tap(find.byTooltip('Close'));
    await _pumpFrames(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CompanionStagePage), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  group("a host's side panel", () {
    const panel = SizedBox.expand(key: Key('host-panel'));
    late TestGetItMocks mocks;

    setUp(() async => mocks = await setUpTestGetIt());
    tearDown(tearDownTestGetIt);

    double figureWidth(WidgetTester tester) => tester
        .getRect(find.byKey(const ValueKey('companionStageFigure')))
        .width;

    testWidgets('stands beside her on a desktop window, the conversation '
        'keeping the larger share', (tester) async {
      tester.view
        ..physicalSize = const Size(1600, 1000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openStage(tester, sidePanel: panel);

      final side = tester.getRect(find.byKey(const Key('host-panel')));
      final figure = tester.getRect(
        find.byKey(const ValueKey('companionStageFigure')),
      );
      expect(side.left, greaterThanOrEqualTo(figure.right));
      expect(
        side.width / (side.width + figure.width),
        closeTo(1 - defaultCompanionStageShare, 0.01),
      );
    });

    testWidgets('opens at the share the user saved', (tester) async {
      when(() => mocks.settingsDb.itemsByKeys(any())).thenAnswer(
        (_) async => {companionStageShareKey: '0.5'},
      );
      tester.view
        ..physicalSize = const Size(1600, 1000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openStage(tester, sidePanel: panel);

      expect(
        figureWidth(tester),
        closeTo((1600 - 3) * 0.5, 0.5),
      );
    });

    testWidgets('the divider between them drags her share with the pointer '
        'and saves it', (tester) async {
      tester.view
        ..physicalSize = const Size(1600, 1000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openStage(tester, sidePanel: panel);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(CompanionStagePage.sidePanelDividerKey)),
      );
      // Past the drag slop, so the next move is applied whole.
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      final before = figureWidth(tester);
      await gesture.moveBy(const Offset(160, 0));
      await tester.pump();
      await gesture.up();
      final after = figureWidth(tester);

      expect(after - before, closeTo(160, 0.5));
      await tester.pump(persistDebounce);
      verify(
        () => mocks.settingsDb.saveSettingsItem(
          companionStageShareKey,
          (after / (1600 - 3)).toStringAsFixed(3),
        ),
      ).called(1);
    });

    testWidgets('stands under her on a phone, at the default share, '
        'each half keeping clear of only the system bar it meets', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1
        ..padding = const FakeViewPadding(top: 47, bottom: 34);
      addTearDown(tester.view.reset);
      await openStage(tester, sidePanel: panel);

      final side = tester.getRect(find.byKey(const Key('host-panel')));
      final band = tester.getRect(
        find.byKey(CompanionStagePage.sidePanelDividerKey),
      );
      // Her share of what the band leaves, the band, then the panel.
      expect(band.top, closeTo((844 - 24) * defaultCompanionStageShare, 0.5));
      expect((band.height, band.width), (24.0, 390.0));
      expect(side.top, band.bottom);
      expect((side.width, side.bottom), (390.0, 844.0));

      final panelInsets = MediaQuery.paddingOf(
        tester.element(find.byKey(const Key('host-panel'))),
      );
      final stageInsets = MediaQuery.paddingOf(
        tester.element(find.byKey(const ValueKey('companionStageFigure'))),
      );
      expect((panelInsets.top, panelInsets.bottom), (0.0, 34.0));
      expect((stageInsets.top, stageInsets.bottom), (47.0, 0.0));
    });

    testWidgets('on a phone opens at the height share saved for a phone, '
        'not the width share a desktop saved', (tester) async {
      when(() => mocks.settingsDb.itemsByKeys(any())).thenAnswer(
        (_) async => {
          companionStageShareKey: '0.6',
          companionStageHeightShareKey: '0.3',
        },
      );
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openStage(tester, sidePanel: panel);

      expect(
        tester.getRect(find.byKey(CompanionStagePage.sidePanelDividerKey)).top,
        closeTo((844 - 24) * 0.3, 0.5),
      );
    });

    testWidgets('on a phone the band between them drags her height with the '
        'finger and saves it for a phone', (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openStage(tester, sidePanel: panel);
      final divider = find.byKey(CompanionStagePage.sidePanelDividerKey);

      final gesture = await tester.startGesture(tester.getCenter(divider));
      // Past the drag slop, so the next move is applied whole.
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      final before = tester.getRect(divider).top;
      await gesture.moveBy(const Offset(0, 82));
      await tester.pump();
      await gesture.up();
      final after = tester.getRect(divider).top;

      expect(after - before, closeTo(82, 0.5));
      await tester.pump(persistDebounce);
      verify(
        () => mocks.settingsDb.saveSettingsItem(
          companionStageHeightShareKey,
          (after / (844 - 24)).toStringAsFixed(3),
        ),
      ).called(1);
      verifyNever(
        () => mocks.settingsDb.saveSettingsItem(companionStageShareKey, any()),
      );
    });

    testWidgets('on a phone, at her smallest share with the keyboard up, '
        'nothing overflows', (tester) async {
      when(() => mocks.settingsDb.itemsByKeys(any())).thenAnswer(
        (_) async => {companionStageHeightShareKey: '0.25'},
      );
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1
        ..padding = const FakeViewPadding(top: 47, bottom: 34)
        ..viewInsets = const FakeViewPadding(bottom: 336);
      addTearDown(tester.view.reset);
      await openStage(tester, sidePanel: panel);

      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byKey(const Key('host-panel'))).bottom,
        844 - 336,
      );
    });

    GestureName? held(WidgetTester tester) => tester
        .widget<CompanionSpeaker>(
          find.byKey(const ValueKey('companionStageFigure')),
        )
        .holding;

    testWidgets('she points at it while the host says so, and lets her arm '
        'down after', (tester) async {
      tester.view
        ..physicalSize = const Size(1600, 1000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openStage(
        tester,
        sidePanel: panel,
        pointsAtSidePanel: _pointingProvider,
      );
      // The panel is on her right, the screen's right.
      expect(held(tester), GestureName.pointRight);

      ProviderScope.containerOf(
        tester.element(find.byType(CompanionSpeaker)),
      ).read(_pointingProvider.notifier).stop();
      await _pumpFrames(tester);
      expect(held(tester), isNull);
    });

    testWidgets('on a phone, with the panel under her, she never points', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openStage(
        tester,
        sidePanel: panel,
        pointsAtSidePanel: _pointingProvider,
      );

      expect(held(tester), isNull);
    });
  });
}
