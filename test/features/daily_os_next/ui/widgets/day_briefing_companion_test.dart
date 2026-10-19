import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/spoken_track.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_capture_models.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_timeline_models.dart';
import 'package:lotti/features/daily_os_next/logic/day_briefing.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_briefing_companion.dart';
import 'package:lotti/features/design_system/theme/sizing_tokens.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_model_repository.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/utils/consts.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../tts/test_utils.dart';

final _day = DateTime(2026, 10, 15);

const _category = DayAgentCategory(
  id: 'work',
  name: 'Work',
  colorHex: '4F8AF7',
);

TimeBlock _block(String title, int startHour, int minutes) {
  final start = _day.add(Duration(hours: startHour));
  return TimeBlock(
    id: title,
    title: title,
    start: start,
    end: start.add(Duration(minutes: minutes)),
    type: TimeBlockType.ai,
    state: TimeBlockState.committed,
    category: _category,
  );
}

DraftPlan _plan(List<TimeBlock> blocks, {int scheduledMinutes = 150}) =>
    DraftPlan(
      dayDate: _day,
      blocks: blocks,
      bands: const [],
      capacityMinutes: 480,
      scheduledMinutes: scheduledMinutes,
    );

final AppLocalizations _en = lookupAppLocalizations(const Locale('en'));

String _clock(DateTime t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

String _compose(
  DraftPlan plan, {
  required int nowHour,
  bool hasPlan = true,
  AppLocalizations? messages,
}) => composeDayBriefing(
  messages ?? _en,
  DayBriefing.of(
    draft: plan,
    hasPlan: hasPlan,
    now: _day.add(Duration(hours: nowHour)),
  ),
  _clock,
);

/// Her ticker runs for as long as she is on screen, so these tests pump a
/// fixed number of frames instead of settling.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  group('composeDayBriefing', () {
    test('without a plan, only invites a check-in', () {
      expect(
        _compose(DraftPlan.emptyForDay(_day), hasPlan: false, nowHour: 8),
        "There's no plan for this day yet. A short check-in will make one.",
      );
    });

    test('counts, names what is next and the longest, and the free time', () {
      expect(
        _compose(
          _plan([_block('Review', 9, 60), _block('Write', 13, 90)]),
          nowHour: 10,
        ),
        'You have 2 blocks planned. Next up at 13:00: Write. '
        'The longest is Write, at 1 hour and 30 minutes. '
        '5 hours and 30 minutes of your day is still free.',
      );
    });

    test('says when nothing is left today, and a full day', () {
      expect(
        _compose(
          _plan([_block('Review', 9, 45)], scheduledMinutes: 480),
          nowHour: 18,
        ),
        'You have one block planned. Nothing else is planned for today. '
        'Your day is fully booked.',
      );
    });

    test('an empty plan says nothing is planned, and what is free', () {
      expect(
        _compose(_plan(const [], scheduledMinutes: 435), nowHour: 8),
        'Nothing is planned yet. 45 minutes of your day is still free.',
      );
    });

    test('a whole number of hours is said without minutes', () {
      expect(
        _compose(_plan(const [], scheduledMinutes: 420), nowHour: 8),
        endsWith(' 1 hour of your day is still free.'),
      );
    });

    // Every locale, every count: the plural forms (Czech and Romanian have
    // three) must all yield a filled-in sentence that says the count.
    glados.Glados(glados.any.intInRange(0, 40)).test(
      'every block count yields a sentence in every locale',
      (count) {
        final blocks = [
          for (var i = 0; i < count; i++)
            _block('Block $i', 0, 15).copyWith(
              start: _day.add(Duration(minutes: 15 * i)),
              end: _day.add(Duration(minutes: 15 * i + 15)),
            ),
        ];
        for (final locale in AppLocalizations.supportedLocales) {
          final text = _compose(
            _plan(blocks),
            nowHour: 0,
            messages: lookupAppLocalizations(locale),
          );
          expect(text, isNot(contains('{')), reason: '$locale');
          if (count > 1) expect(text, contains('$count'), reason: '$locale');
        }
      },
      tags: 'glados',
    );
  });

  group('DayBriefingCompanion', () {
    late FakeTtsEngine engine;
    late FakeTtsAudioPlayer player;

    setUp(() {
      engine = FakeTtsEngine();
      player = FakeTtsAudioPlayer();
    });

    Future<void> pump(
      WidgetTester tester, {
      bool companion = true,
      bool tts = true,
      bool engineSupported = true,
      bool hasPlan = true,
      FakeTtsModelRepository? models,
    }) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(switch (flagName) {
                enableCompanionFlag => companion,
                enableAiSummaryTtsFlag => tts,
                _ => false,
              }),
            ),
            ttsEngineProvider.overrideWithValue(
              engineSupported ? engine : FakeTtsEngine(supported: false),
            ),
            ttsPlaybackControllerProvider.overrideWith(
              () => TtsPlaybackController(logger: MockDomainLogger()),
            ),
            ttsAudioPlayerProvider.overrideWithValue(player),
            ttsModelRepositoryProvider.overrideWithValue(
              models ?? FakeTtsModelRepository(),
            ),
            spokenTrackLoaderProvider.overrideWithValue(
              (clip, text) => Completer<MouthTrack>().future,
            ),
          ],
          child: Align(
            alignment: Alignment.topLeft,
            child: DayBriefingCompanion(
              draft: _plan([_block('Review', 9, 60), _block('Write', 13, 90)]),
              hasPlan: hasPlan,
            ),
          ),
        ),
      );
      await _pumpFrames(tester);
    }

    for (final (name, companion, tts, engineSupported) in [
      ('her flag is off', false, true, true),
      ('read-aloud is off', true, false, true),
      ('the device has no voice', true, true, false),
    ]) {
      testWidgets('takes no room while $name', (tester) async {
        await pump(
          tester,
          companion: companion,
          tts: tts,
          engineSupported: engineSupported,
        );

        expect(find.byType(CompanionSpeaker), findsNothing);
        expect(tester.getSize(find.byType(DayBriefingCompanion)), Size.zero);
      });
    }

    testWidgets("shows her bust, an avatar's size, on the day's utterance", (
      tester,
    ) async {
      await pump(tester);

      final speaker = tester.widget<CompanionSpeaker>(
        find.byType(CompanionSpeaker),
      );
      expect(speaker.framing, CompanionFraming.bust);
      expect(speaker.sourceId, 'day-briefing:2026-10-15');
      expect(
        tester.getSize(find.byType(CompanionSpeaker)),
        const Size.square(ControlSizes.avatar),
      );
      expect(find.byTooltip('Hear your day'), findsOneWidget);
    });

    testWidgets('a tap speaks the briefing as of the tap', (tester) async {
      await pump(tester);

      await withClock(
        Clock.fixed(_day.add(const Duration(hours: 10))),
        () async {
          await tester.tap(find.byType(CompanionSpeaker));
          await _pumpFrames(tester);
        },
      );

      expect(
        engine.calls.single.text,
        'You have 2 blocks planned. Next up at 1:00 PM: Write. '
        'The longest is Write, at 1 hour and 30 minutes. '
        '5 hours and 30 minutes of your day is still free.',
      );
      expect(player.playCount, 1);
      expect(find.byTooltip('Stop the briefing'), findsOneWidget);
    });

    testWidgets('without the voice model, a tap asks first, showing its '
        'size', (tester) async {
      final models = FakeTtsModelRepository(installed: false);
      await pump(tester, models: models);

      await tester.tap(find.byType(CompanionSpeaker));
      await _pumpFrames(tester);
      // Let the prompt finish sliding in before tapping it.
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Download the voice model?'), findsOneWidget);
      expect(find.text('Download (398.4 MB)'), findsOneWidget);
      expect(models.ensureCount, 0);
      expect(engine.calls, isEmpty);

      await tester.tap(find.text('Download (398.4 MB)'));
      // The prompt answers once its route has closed.
      await tester.pump(const Duration(milliseconds: 400));
      await _pumpFrames(tester);

      expect(models.ensureCount, 1);
      expect(engine.calls, hasLength(1));
    });

    testWidgets('a tap while she speaks stops her', (tester) async {
      await pump(tester);
      await tester.tap(find.byType(CompanionSpeaker));
      await _pumpFrames(tester);
      final stopsBefore = player.stopCount;

      await tester.tap(find.byType(CompanionSpeaker));
      await _pumpFrames(tester);

      expect(player.stopCount, greaterThan(stopsBefore));
      expect(engine.calls, hasLength(1));
      expect(find.byTooltip('Hear your day'), findsOneWidget);
    });

    testWidgets('a tap while another utterance is busy takes the voice over', (
      tester,
    ) async {
      final synthesis = Completer<File>();
      engine = FakeTtsEngine(pendingSynthesis: synthesis.future);
      await pump(tester);
      final voice = ProviderScope.containerOf(
        tester.element(find.byType(DayBriefingCompanion)),
      ).read(ttsPlaybackControllerProvider.notifier);
      // Another day's briefing, still being prepared: the voice is busy.
      voice
          .speak(sourceId: 'day-briefing:2026-10-14', text: 'Yesterday')
          .ignore();
      await _pumpFrames(tester);
      expect(find.byTooltip('Hear your day'), findsOneWidget);

      await tester.tap(find.byType(CompanionSpeaker));
      await _pumpFrames(tester);

      expect(find.byTooltip('Stop the briefing'), findsOneWidget);
      synthesis.complete(File('/tmp/fake_tts_output.wav'));
      await _pumpFrames(tester);
      expect(
        engine.calls.map((c) => c.text),
        ['Yesterday', startsWith('You have 2 blocks planned.')],
      );
      expect(player.playCount, 1);
    });

    testWidgets('a briefing the voice cannot speak shows an error', (
      tester,
    ) async {
      engine = FakeTtsEngine(throwOnSynthesize: true);
      await pump(tester);

      await tester.tap(find.byType(CompanionSpeaker));
      await _pumpFrames(tester);

      expect(find.text('Error'), findsOneWidget);
      expect(find.byTooltip('Hear your day'), findsOneWidget);
    });

    testWidgets('without a plan, she invites a check-in', (tester) async {
      await pump(tester, hasPlan: false);

      await tester.tap(find.byType(CompanionSpeaker));
      await _pumpFrames(tester);

      expect(
        engine.calls.single.text,
        "There's no plan for this day yet. A short check-in will make one.",
      );
    });
  });
}
