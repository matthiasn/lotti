import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/companion_card_controller.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';
import 'package:lotti/features/companion/state/spoken_track.dart';
import 'package:lotti/features/companion/ui/companion_floating_card.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_stage_pointing.dart';
import 'package:lotti/features/front_agent/state/front_voice_providers.dart';
import 'package:lotti/features/front_agent/ui/front_chat_hero.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';
import '../../companion/companion_overrides.dart';

/// The composer, mid-send or settled as the test says.
class _Composer extends FrontChatController {
  _Composer({required this.sending});

  final bool sending;

  @override
  FrontChatComposerState build() => FrontChatComposerState(isSending: sending);
}

/// The voice, speaking [_source] or silent.
class _Voice extends TtsPlaybackController {
  _Voice(this._source);

  final String? _source;

  @override
  TtsPlaybackState build() => _source == null
      ? const TtsPlaybackState()
      : TtsPlaybackState(status: TtsPlaybackStatus.playing, sourceId: _source);
}

/// She ticks for as long as she is mounted: pump frames, never settle.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  /// Lotti's outfits, in order.
  final outfits = CompanionLook.of(CompanionSpecies.grandma);
  const area = Size(390, 600);
  late TestGetItMocks mocks;
  late int customizes;

  setUp(() async {
    mocks = await setUpTestGetIt();
    customizes = 0;
  });
  tearDown(tearDownTestGetIt);

  void stored(CompanionCardForm form, Map<String, num> placement) => when(
    () => mocks.settingsDb.itemByKey(form.settingsKey),
  ).thenAnswer((_) async => jsonEncode(placement));

  Future<void> pumpCard(
    WidgetTester tester, {
    CompanionCardForm form = CompanionCardForm.phone,
    bool points = false,
    bool sending = false,
    String? speaking,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: area,
              child: FrontCompanionCard(
                conversationId: 'c-1',
                form: form,
                onCustomize: () => customizes++,
              ),
            ),
          ),
        ),
        overrides: <Override>[
          ...companionLookOverrides(outfit: outfits.first),
          spokenTrackLoaderProvider.overrideWithValue(
            (clip, text) => Completer<MouthTrack>().future,
          ),
          frontStagePointsProvider('c-1').overrideWithValue(points),
          frontChatControllerProvider.overrideWith(
            () => _Composer(sending: sending),
          ),
          ttsPlaybackControllerProvider.overrideWith(() => _Voice(speaking)),
        ],
      ),
    );
    await _pumpFrames(tester);
  }

  final card = find.byKey(CompanionFloatingCardKeys.card);
  CompanionSpeaker speaker(WidgetTester tester) => tester.widget(
    find.descendant(of: card, matching: find.byType(CompanionSpeaker)),
  );

  testWidgets("she speaks the conversation in her surface's outfit, small "
      'in the bottom-right corner of the area at first', (tester) async {
    await pumpCard(tester);

    expect(speaker(tester).sourceId, frontVoiceSourceId('c-1'));
    expect(speaker(tester).dressedFor, frontCompanionDressedFor);
    final rect = tester.getRect(card);
    expect(rect.height, CompanionCardForm.phone.smallHeight);
    expect(rect.right, area.width - 16);
    expect(rect.bottom, area.height - 16);
  });

  testWidgets('keeps the placement the user left in its own form', (
    tester,
  ) async {
    stored(CompanionCardForm.phone, {'x': 0, 'y': 0, 'h': 300});
    stored(CompanionCardForm.desktop, {'x': 1, 'y': 1, 'h': 200});

    await pumpCard(tester);
    expect(tester.getRect(card).topLeft, const Offset(16, 16));
    expect(tester.getSize(card).height, 300);

    await pumpCard(tester, form: CompanionCardForm.desktop);
    expect(tester.getSize(card).height, 200);
    expect(tester.getRect(card).bottom, area.height - 16);
  });

  testWidgets('a tap on the card keeps it; Hide in its menu puts it away: '
      'the header shows her face again', (tester) async {
    await pumpCard(tester);
    final container = ProviderScope.containerOf(tester.element(card));
    expect(container.read(frontCompanionCardShownProvider), isTrue);

    await tester.tap(card);
    await tester.pump(kDoubleTapTimeout);
    expect(container.read(frontCompanionCardShownProvider), isTrue);

    await tester.longPress(card);
    await tester.pump();
    await tester.tap(find.byKey(CompanionFloatingCardKeys.hide));
    await tester.pump();
    expect(container.read(frontCompanionCardShownProvider), isFalse);
  });

  testWidgets("the card's Customize row asks for her settings, her outfit "
      'left as it is', (tester) async {
    await pumpCard(tester);
    final container = ProviderScope.containerOf(tester.element(card));

    await tester.longPress(card);
    await tester.pump();
    await tester.tap(find.byKey(CompanionFloatingCardKeys.customize));
    await _pumpFrames(tester);

    expect(customizes, 1);
    expect(container.read(companionOutfitProvider)?.id, outfits.first.id);
  });

  for (final (speaking, accent) in [('c-1', true), ('c-2', false)]) {
    testWidgets('her edge takes the accent: $accent while $speaking speaks', (
      tester,
    ) async {
      await pumpCard(tester, speaking: frontVoiceSourceId(speaking));
      expect(
        tester
            .widget<CompanionFloatingCard>(find.byType(CompanionFloatingCard))
            .speaking,
        accent,
      );
    });
  }

  testWidgets('in the left half, the thread to her right, she points at what '
      'her reply lists', (tester) async {
    stored(CompanionCardForm.phone, {'x': 0, 'y': 1, 'h': 172});
    await pumpCard(tester, points: true, sending: true);

    expect(speaker(tester).holding, GestureName.pointRight);
  });

  testWidgets('docked, she shows her bust collapsed and all of her '
      'expanded, and always points, the thread being to her right', (
    tester,
  ) async {
    await pumpCard(
      tester,
      form: CompanionCardForm.docked,
      points: true,
      sending: true,
    );
    expect(speaker(tester).framing, CompanionFraming.bust);
    expect(speaker(tester).holding, GestureName.pointRight);

    await tester.tap(find.byKey(CompanionFloatingCardKeys.expand));
    await tester.pump(kDoubleTapTimeout);
    await _pumpFrames(tester);
    expect(speaker(tester).framing, CompanionFraming.full);
  });

  testWidgets("in the right half she never points, holding the turn's pose "
      'as her bust in the header does', (tester) async {
    await pumpCard(tester, points: true, sending: true);

    expect(speaker(tester).holding, GestureName.think);
  });
}
