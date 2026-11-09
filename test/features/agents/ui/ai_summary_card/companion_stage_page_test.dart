import 'dart:async';
import 'dart:convert';

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
import 'package:lotti/features/companion/state/companion_card_controller.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';
import 'package:lotti/features/companion/state/spoken_track.dart';
import 'package:lotti/features/companion/ui/companion_floating_card.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
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
    CompanionConversationBuilder? conversation,
    ProviderListenable<bool>? pointsAtConversation,
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
                    conversation: conversation,
                    pointsAtConversation: pointsAtConversation,
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

  group("a host's conversation", () {
    late TestGetItMocks mocks;
    late double inset;

    setUp(() async => mocks = await setUpTestGetIt());
    tearDown(tearDownTestGetIt);

    Widget conversation({required Widget card, required double bottomInset}) {
      inset = bottomInset;
      return Stack(
        key: const Key('host-conversation'),
        children: [Positioned.fill(child: card)],
      );
    }

    final figure = find.byKey(const ValueKey('companionStageFigure'));
    final card = find.byKey(CompanionFloatingCardKeys.card);
    final host = find.byKey(const Key('host-conversation'));

    void phone(WidgetTester tester) {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1
        ..padding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.reset);
    }

    void stored(CompanionCardForm form, Map<String, num> placement) => when(
      () => mocks.settingsDb.itemByKey(form.settingsKey),
    ).thenAnswer((_) async => jsonEncode(placement));

    testWidgets('is the page, in the app theme, her small in a card in its '
        'bottom-right corner, the top row under the notch', (tester) async {
      phone(tester);
      await openStage(
        tester,
        conversation: conversation,
        hostControl: const SizedBox(key: Key('host-control')),
      );

      // No stage of her own: she is in the card, over the conversation.
      expect(find.byType(CompanionView), findsOneWidget);
      expect(
        tester.widget<CompanionSpeaker>(figure).stage,
        isFalse,
      );
      expect(find.descendant(of: card, matching: figure), findsOneWidget);
      final page = tester.getRect(host);
      final cardRect = tester.getRect(card);
      expect(cardRect.height, CompanionCardForm.phone.smallHeight);
      expect(cardRect.right, 390 - 16);
      expect(cardRect.bottom, page.bottom - 16);
      // The row with the outfit, the host's control and close sits below
      // the notch, and the conversation — her with it — below the row.
      final outfit = tester.getRect(
        find.byKey(const ValueKey('companionStageOutfit')),
      );
      expect(outfit.top, greaterThanOrEqualTo(59));
      expect(page.top, greaterThanOrEqualTo(outfit.bottom));
      expect(
        tester.getCenter(find.byKey(const Key('host-control'))).dy,
        closeTo(outfit.center.dy, 0.5),
      );
      expect(
        MediaQuery.paddingOf(tester.element(host)).top,
        0,
      );
      // The thread keeps her height and a margin free after its end.
      expect(inset, CompanionCardForm.phone.smallHeight + 16);
    });

    testWidgets('opens where the user left her on a phone, the room after '
        "the thread's end kept up top too", (tester) async {
      phone(tester);
      stored(CompanionCardForm.phone, {'x': 0, 'y': 0, 'h': 300});
      stored(CompanionCardForm.desktop, {'x': 1, 'y': 1, 'h': 500});
      await openStage(tester, conversation: conversation);

      final page = tester.getRect(host);
      final cardRect = tester.getRect(card);
      expect(cardRect.height, 300);
      expect(cardRect.topLeft, page.topLeft + const Offset(16, 16));
      expect(inset, 300 + 16);
    });

    testWidgets('moving her across the middle leaves the room after the '
        "thread's end as it was, so nothing behind her shifts", (tester) async {
      phone(tester);
      await openStage(tester, conversation: conversation);
      final before = inset;
      final start = tester.getRect(card);

      final drag = await tester.startGesture(start.center);
      await drag.moveBy(const Offset(0, -30));
      await drag.moveBy(const Offset(0, -400));
      await tester.pump();
      await drag.up();
      await tester.pump(companionCardPersistDebounce);

      expect(tester.getRect(card).top, lessThan(start.top - 300));
      expect(inset, before);
    });

    testWidgets('on a desktop window keeps the desktop placement', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1600, 1000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      stored(CompanionCardForm.phone, {'x': 0, 'y': 0, 'h': 300});
      await openStage(tester, conversation: conversation);

      expect(
        tester.getRect(card).height,
        CompanionCardForm.desktop.smallHeight,
      );
    });

    testWidgets('the card restyles her: the next outfit', (tester) async {
      phone(tester);
      await openStage(tester, conversation: conversation);
      String worn() =>
          tester.widget<CompanionView>(find.byType(CompanionView)).look.id;
      expect(worn(), companionOutfits.first.id);

      await tester.longPress(card);
      await tester.pump();
      await tester.tap(find.byKey(CompanionFloatingCardKeys.restyle));
      await _pumpFrames(tester);

      expect(worn(), companionOutfits[1].id);
    });

    testWidgets("the top row's outfit control restyles her, and its close "
        'control takes the page away', (tester) async {
      phone(tester);
      await openStage(tester, conversation: conversation);
      String worn() =>
          tester.widget<CompanionView>(find.byType(CompanionView)).look.id;

      await tester.tap(find.byKey(const ValueKey('companionStageOutfit')));
      await tester.pump();
      expect(worn(), companionOutfits[1].id);

      await tester.tap(find.byTooltip('Close'));
      await _pumpFrames(tester);
      await tester.pump(const Duration(milliseconds: 400));

      expect(host, findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    GestureName? held(WidgetTester tester) =>
        tester.widget<CompanionSpeaker>(figure).holding;

    testWidgets('with the conversation to her right she points at it while '
        'the host says so, and lets her arm down after', (tester) async {
      phone(tester);
      stored(CompanionCardForm.phone, {'x': 0, 'y': 1, 'h': 172});
      await openStage(
        tester,
        conversation: conversation,
        pointsAtConversation: _pointingProvider,
      );
      expect(held(tester), GestureName.pointRight);

      ProviderScope.containerOf(
        tester.element(find.byType(CompanionSpeaker)),
      ).read(_pointingProvider.notifier).stop();
      await _pumpFrames(tester);
      expect(held(tester), isNull);
    });

    testWidgets('in the right half, the conversation to her left, she never '
        'points', (tester) async {
      phone(tester);
      await openStage(
        tester,
        conversation: conversation,
        pointsAtConversation: _pointingProvider,
      );

      expect(held(tester), isNull);
    });
  });
}
