import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/day_agent_identity.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
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
import 'package:lotti/features/tts/cloud/cloud_speech_synthesizer.dart';
import 'package:lotti/features/tts/cloud/cloud_tts_exception.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_model_repository.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/utils/consts.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../agents/test_data/ai_config_factories.dart';
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
        "There's no plan for this day yet. A short check\u2011in will make one.",
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

  group('composeDayHeadline', () {
    String headline(
      DraftPlan plan, {
      required int nowHour,
      bool hasPlan = true,
    }) => composeDayHeadline(
      _en,
      DayBriefing.of(
        draft: plan,
        hasPlan: hasPlan,
        now: _day.add(Duration(hours: nowHour)),
      ),
      _clock,
    );

    test('without a plan, is the invitation to check in', () {
      expect(
        headline(DraftPlan.emptyForDay(_day), hasPlan: false, nowHour: 8),
        "There's no plan for this day yet. A short check\u2011in will make one.",
      );
    });

    test('counts the blocks and names what is next', () {
      expect(
        headline(
          _plan([_block('Review', 9, 60), _block('Write', 13, 90)]),
          nowHour: 10,
        ),
        'You have 2 blocks planned. Next up at 13:00: Write.',
      );
    });

    test("names the next block by its task's live name when given", () {
      final briefing = DayBriefing.of(
        draft: _plan([_block('Write', 13, 90)]),
        hasPlan: true,
        now: _day.add(const Duration(hours: 10)),
      );

      expect(
        composeDayHeadline(_en, briefing, _clock, nextTitle: 'Draft memo'),
        'You have one block planned. Next up at 13:00: Draft memo.',
      );
      // The spoken briefing opens with the same name.
      expect(
        composeDayBriefing(_en, briefing, _clock, nextTitle: 'Draft memo'),
        startsWith(
          'You have one block planned. Next up at 13:00: Draft memo.',
        ),
      );
    });

    test('says when nothing is left today', () {
      expect(
        headline(_plan([_block('Review', 9, 60)]), nowHour: 20),
        'You have one block planned. Nothing else is planned for today.',
      );
    });

    test('a past day only counts', () {
      expect(
        composeDayHeadline(
          _en,
          DayBriefing.of(
            draft: _plan([_block('Review', 9, 60)]),
            hasPlan: true,
            now: _day.add(const Duration(days: 2)),
          ),
          _clock,
        ),
        'You have one block planned.',
      );
    });

    for (final title in ['Ready?', 'Go!', 'Done.', 'Wait…']) {
      test('a next title ending "$title" gets no second stop', () {
        expect(
          headline(_plan([_block(title, 13, 30)]), nowHour: 10),
          'You have one block planned. Next up at 13:00: $title',
        );
      });
    }

    test('a title ending in a word keeps the template stop', () {
      expect(
        headline(_plan([_block('Write', 13, 30)]), nowHour: 10),
        endsWith('Write.'),
      );
    });

    test('is how the spoken briefing begins', () {
      final plan = _plan([_block('Review', 9, 60), _block('Write', 13, 90)]);
      expect(
        _compose(plan, nowHour: 10),
        startsWith(headline(plan, nowHour: 10)),
      );
    });
  });

  group('DayBriefingCompanion', () {
    late FakeTtsEngine engine;
    late FakeTtsAudioPlayer player;
    late FakeCloudSpeechSynthesizer cloud;

    setUp(() {
      engine = FakeTtsEngine();
      player = FakeTtsAudioPlayer();
      cloud = FakeCloudSpeechSynthesizer();
    });

    Future<void> pump(
      WidgetTester tester, {
      bool companion = true,
      bool tts = true,
      bool engineSupported = true,
      bool hasPlan = true,
      FakeTtsModelRepository? models,
      ResolvedAgentSetup? plannerSetup,
      Locale locale = const Locale('en'),
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
            agentResolvedSetupProvider.overrideWith(
              (ref, agentId) async =>
                  agentId == dailyOsPlannerAgentId ? plannerSetup : null,
            ),
            cloudSpeechSynthesizerProvider.overrideWithValue(cloud),
          ],
          locale: locale,
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

    group("the Daily OS planner's voice", () {
      final mistral = testInferenceProvider(
        id: 'mistral',
        inferenceProviderType: InferenceProviderType.mistral,
      );
      final voxtral = testAiModel(
        id: 'voice-row',
        providerModelId: 'voxtral-mini-tts-3-0',
      );

      ResolvedAgentSetup setup({bool speaks = true}) => ResolvedAgentSetup(
        status: AgentSetupResolutionStatus.resolved,
        profile: ResolvedProfile(
          thinkingModelId: 'thinking',
          thinkingProvider: mistral,
          speechModelId: speaks ? voxtral.providerModelId : null,
          speechProvider: speaks ? mistral : null,
          speechModel: speaks ? voxtral : null,
        ),
      );

      testWidgets('shows her where the device has no on-device voice, '
          "when the planner's profile names a cloud voice", (tester) async {
        await pump(tester, engineSupported: false, plannerSetup: setup());

        expect(find.byType(CompanionSpeaker), findsOneWidget);
      });

      testWidgets('a tap speaks the briefing with that cloud voice, in the '
          "app's language, never through the on-device engine", (
        tester,
      ) async {
        cloud.output = File('/tmp/fake_cloud_briefing.wav');
        await pump(
          tester,
          plannerSetup: setup(),
          locale: const Locale('de'),
        );

        await tester.tap(find.byType(CompanionSpeaker));
        await _pumpFrames(tester);

        final call = cloud.calls.single;
        expect(call.route.provider, mistral);
        expect(call.route.model, voxtral);
        expect(call.route.languageCode, 'de');
        expect(call.text, contains('Write'));
        expect(call.sent, isTrue);
        expect(engine.calls, isEmpty);
        expect(player.playCount, 1);
      });

      testWidgets('a language the cloud voice has no voice for is spoken by '
          'the on-device voice', (tester) async {
        cloud = FakeCloudSpeechSynthesizer(
          error: const CloudTtsException(
            CloudTtsFailure.noVoice,
            'No voice for language ro',
          ),
        );
        await pump(
          tester,
          plannerSetup: setup(),
          locale: const Locale('ro'),
        );

        await tester.tap(find.byType(CompanionSpeaker));
        await _pumpFrames(tester);

        expect(engine.calls, hasLength(1));
        expect(player.playCount, 1);
      });

      testWidgets('a profile without a read-aloud model keeps the on-device '
          'voice', (tester) async {
        await pump(tester, plannerSetup: setup(speaks: false));

        await tester.tap(find.byType(CompanionSpeaker));
        await _pumpFrames(tester);

        expect(cloud.calls, isEmpty);
        expect(engine.calls, hasLength(1));
      });

      testWidgets('without a cloud voice, a device with no on-device voice '
          'still shows nothing', (tester) async {
        await pump(
          tester,
          engineSupported: false,
          plannerSetup: setup(speaks: false),
        );

        expect(find.byType(CompanionSpeaker), findsNothing);
      });
    });

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
        "There's no plan for this day yet. A short check\u2011in will make one.",
      );
    });
  });
}
