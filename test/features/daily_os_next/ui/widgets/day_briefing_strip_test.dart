import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/state/spoken_track.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_briefing_strip.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_capacity_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_model_repository.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../tts/test_utils.dart';

final _day = DateTime(2026, 10, 15);

const _deep = DayAgentCategory(id: 'deep', name: 'Deep', colorHex: '3366FF');
const _admin = DayAgentCategory(id: 'admin', name: 'Admin', colorHex: 'F5A623');

TimeBlock _block(
  String title,
  int startHour,
  int minutes, {
  DayAgentCategory category = _deep,
  TimeBlockState state = TimeBlockState.drafted,
  TimeBlockType type = TimeBlockType.ai,
}) {
  final start = _day.add(Duration(hours: startHour));
  return TimeBlock(
    id: '$title-$startHour',
    title: title,
    start: start,
    end: start.add(Duration(minutes: minutes)),
    type: type,
    state: state,
    category: category,
  );
}

/// Review 9:00 (1h), Write 13:00 (1h 30m), Lunch 15:00 (30m, admin): 3h
/// planned. The stored `scheduledMinutes` deliberately disagrees.
DraftPlan _plan({int capacityMinutes = 480, List<TimeBlock>? blocks}) =>
    DraftPlan(
      dayDate: _day,
      blocks:
          blocks ??
          [
            _block('Review', 9, 60),
            _block('Write', 13, 90),
            _block('Lunch', 15, 30, category: _admin),
          ],
      bands: const [],
      capacityMinutes: capacityMinutes,
      scheduledMinutes: 999,
    );

class _Bench {
  final engine = FakeTtsEngine();
  final player = FakeTtsAudioPlayer();

  Future<void> pump(
    WidgetTester tester, {
    DraftPlan? draft,
    bool hasPlan = true,
    List<TimeBlock> actualBlocks = const [],
    bool voice = false,
    Widget? trailing,
  }) async {
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: [
          configFlagProvider.overrideWith(
            (ref, flagName) => Stream.value(
              voice &&
                  (flagName == enableCompanionFlag ||
                      flagName == enableAiSummaryTtsFlag),
            ),
          ),
          ttsEngineProvider.overrideWithValue(engine),
          ttsPlaybackControllerProvider.overrideWith(
            () => TtsPlaybackController(logger: MockDomainLogger()),
          ),
          ttsAudioPlayerProvider.overrideWithValue(player),
          ttsModelRepositoryProvider.overrideWithValue(
            FakeTtsModelRepository(),
          ),
          spokenTrackLoaderProvider.overrideWithValue(
            (clip, text) => Completer<MouthTrack>().future,
          ),
          agentResolvedSetupProvider.overrideWith(
            (ref, agentId) async => null,
          ),
        ],
        child: Align(
          alignment: Alignment.topCenter,
          child: DayBriefingStrip(
            draft: draft ?? _plan(),
            hasPlan: hasPlan,
            actualBlocks: actualBlocks,
            trailing: trailing,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }
}

DsTokens _tokens(WidgetTester tester) =>
    tester.element(find.byType(DayBriefingStrip)).designTokens;

Text _text(WidgetTester tester, String data) =>
    tester.widget<Text>(find.text(data));

/// Runs [body] with the clock at [hour]:00 on the plan's day.
Future<void> _at(int hour, Future<void> Function() body) =>
    withClock(Clock.fixed(_day.add(Duration(hours: hour))), body);

void main() {
  late _Bench bench;
  setUp(() => bench = _Bench());

  group('DayBriefingStrip sentence', () {
    testWidgets('counts the blocks and names what is next', (tester) async {
      await _at(10, () => bench.pump(tester));

      expect(
        find.text('You have 3 blocks planned. Next up at 1:00 PM: Write.'),
        findsOneWidget,
      );
    });

    testWidgets('moves on to the following block once the next one starts', (
      tester,
    ) async {
      var now = _day.add(const Duration(hours: 10));
      await withClock(Clock(() => now), () async {
        await bench.pump(tester);
        expect(find.textContaining('Next up at 1:00 PM: Write.'), findsOne);

        now = _day.add(const Duration(hours: 13, seconds: 1));
        await tester.pump(const Duration(hours: 3, seconds: 1));

        expect(find.textContaining('Next up at 3:00 PM: Lunch.'), findsOne);
      });
    });

    testWidgets('leaves no timer behind once it is gone', (tester) async {
      await _at(10, () => bench.pump(tester));

      await tester.pumpWidget(const SizedBox.shrink());

      // A pending timer would fail the test at teardown.
      expect(find.byType(DayBriefingStrip), findsNothing);
    });

    testWidgets('without a plan, is the invitation to check in', (
      tester,
    ) async {
      await _at(
        10,
        () => bench.pump(
          tester,
          draft: DraftPlan.emptyForDay(_day),
          hasPlan: false,
        ),
      );

      expect(
        find.text(
          "There's no plan for this day yet. A short check-in will make one.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('leads with the violet sparkle in high-emphasis body text', (
      tester,
    ) async {
      await _at(10, () => bench.pump(tester));
      final tokens = _tokens(tester);

      expect(
        tester.widget<Icon>(find.byIcon(LottiIcons.aiSpark)).color,
        tokens.colors.aiCard.accent,
      );
      final sentence = tester.widget<Text>(
        find.textContaining('You have 3 blocks'),
      );
      expect(sentence.style?.color, tokens.colors.text.highEmphasis);
      expect(
        sentence.style?.fontSize,
        tokens.typography.styles.body.bodySmall.fontSize,
      );
    });
  });

  group('DayBriefingStrip captions', () {
    testWidgets(
      'planned minutes come from the blocks, not the stored total, and the '
      'rest of the capacity is free',
      (tester) async {
        await _at(10, () => bench.pump(tester));

        expect(find.text('3h planned'), findsOneWidget);
        expect(find.text('5h free'), findsOneWidget);
      },
    );

    testWidgets('an over-booked day says by how much, in error ink', (
      tester,
    ) async {
      await _at(
        10,
        () => bench.pump(tester, draft: _plan(capacityMinutes: 150)),
      );

      expect(find.text('30m over'), findsOneWidget);
      expect(find.textContaining('free'), findsNothing);
      expect(
        _text(tester, '30m over').style?.color,
        _tokens(tester).colors.alert.error.ink,
      );
    });

    testWidgets('a day planned exactly to capacity has nothing free', (
      tester,
    ) async {
      await _at(
        10,
        () => bench.pump(tester, draft: _plan(capacityMinutes: 180)),
      );

      expect(find.text('0m free'), findsOneWidget);
    });

    testWidgets('a day without a capacity names only what is planned', (
      tester,
    ) async {
      await _at(10, () => bench.pump(tester, draft: _plan(capacityMinutes: 0)));

      expect(find.text('3h planned'), findsOneWidget);
      expect(find.textContaining('free'), findsNothing);
      expect(find.textContaining('over'), findsNothing);
    });

    testWidgets('dropped blocks are not planned time', (tester) async {
      await _at(
        10,
        () => bench.pump(
          tester,
          draft: _plan(
            blocks: [
              _block('Review', 9, 60),
              _block('Gone', 11, 120, state: TimeBlockState.dropped),
            ],
          ),
        ),
      );

      expect(find.text('1h planned'), findsOneWidget);
    });

    testWidgets('captions are low-emphasis with tabular figures', (
      tester,
    ) async {
      await _at(10, () => bench.pump(tester));

      final style = _text(tester, '3h planned').style!;
      expect(style.color, _tokens(tester).colors.text.lowEmphasis);
      expect(style.fontFeatures, numericBadgeFontFeatures);
    });

    testWidgets('without a plan, says what is tracked and how much is done', (
      tester,
    ) async {
      await _at(
        12,
        () => bench.pump(
          tester,
          draft: DraftPlan.emptyForDay(_day),
          hasPlan: false,
          actualBlocks: [
            _block(
              'A',
              8,
              90,
              type: TimeBlockType.manual,
              state: TimeBlockState.completed,
            ),
            _block(
              'B',
              10,
              65,
              type: TimeBlockType.manual,
              state: TimeBlockState.inProgress,
            ),
          ],
        ),
      );

      expect(find.text('2h 35m tracked'), findsOneWidget);
      expect(find.text('1 done'), findsOneWidget);
    });
  });

  group('DayBriefingStrip bar', () {
    testWidgets('draws one segment per category, in its colour', (
      tester,
    ) async {
      await _at(10, () => bench.pump(tester));

      final bar = tester.widget<DayCapacityBar>(find.byType(DayCapacityBar));
      expect(bar.capacityMinutes, 480);
      expect(
        bar.segments.map((s) => (s.color, s.minutes, s.label)),
        [
          (categoryColorFromHex(_deep.colorHex), 150, 'Deep · 2h 30m'),
          (categoryColorFromHex(_admin.colorHex), 30, 'Admin · 30m'),
        ],
      );
      expect(
        bar.semanticsLabel,
        'Planned time by category: Deep 2h 30m, Admin 30m',
      );
    });

    testWidgets('an empty plan has an unlabelled, bare bar', (tester) async {
      await _at(10, () => bench.pump(tester, draft: _plan(blocks: const [])));

      final bar = tester.widget<DayCapacityBar>(find.byType(DayCapacityBar));
      expect(bar.segments, isEmpty);
      expect(bar.semanticsLabel, isNull);
      expect(find.text('0m planned'), findsOneWidget);
    });

    testWidgets('without a plan, the bar is the tracked time in teal', (
      tester,
    ) async {
      await _at(
        12,
        () => bench.pump(
          tester,
          draft: DraftPlan.emptyForDay(_day),
          hasPlan: false,
          actualBlocks: [_block('A', 8, 90, type: TimeBlockType.manual)],
        ),
      );

      final bar = tester.widget<DayCapacityBar>(find.byType(DayCapacityBar));
      expect(bar.segments.single.minutes, 90);
      expect(
        bar.segments.single.color,
        _tokens(tester).colors.interactive.enabled,
      );
      expect(bar.capacityMinutes, DraftPlan.emptyForDay(_day).capacityMinutes);
    });
  });

  group('DayBriefingStrip surface', () {
    testWidgets('is the aiCard surface at radii.l', (tester) async {
      await _at(10, () => bench.pump(tester));
      final tokens = _tokens(tester);

      final decoration =
          tester.widget<Ink>(find.byType(Ink)).decoration! as BoxDecoration;
      expect(decoration.color, tokens.colors.aiCard.background);
      expect(decoration.border, Border.all(color: tokens.colors.aiCard.border));
      expect(decoration.borderRadius, BorderRadius.circular(tokens.radii.l));
    });

    testWidgets('puts the trailing controls at the end of the sentence row', (
      tester,
    ) async {
      await _at(
        10,
        () => bench.pump(tester, trailing: const Icon(LottiIcons.settings)),
      );

      final sentence = tester.getRect(find.textContaining('You have 3'));
      final trailing = tester.getRect(find.byIcon(LottiIcons.settings));
      expect(trailing.left, greaterThan(sentence.right));
      expect(trailing.center.dy, closeTo(sentence.center.dy, 1));
    });
  });

  group('DayBriefingStrip voice', () {
    final tap = find.byKey(const Key('daily_os_briefing_strip_tap'));

    testWidgets('is inert while the companion cannot speak', (tester) async {
      await _at(10, () => bench.pump(tester));

      expect(tap, findsNothing);
      await tester.tap(find.byType(DayBriefingStrip));
      await tester.pump();
      expect(bench.engine.calls, isEmpty);
    });

    testWidgets('a tap briefs the day as the companion would', (tester) async {
      await _at(10, () async {
        await bench.pump(tester, voice: true);
        expect(find.byTooltip('Hear your day'), findsOneWidget);

        await tester.tap(tap);
        await tester.pump();
        await tester.pump();
      });

      expect(
        bench.engine.calls.single.text,
        startsWith('You have 3 blocks planned. Next up at 1:00 PM: Write.'),
      );
      expect(find.byTooltip('Stop the briefing'), findsOneWidget);
    });

    testWidgets('a second tap stops her', (tester) async {
      await _at(10, () async {
        await bench.pump(tester, voice: true);
        await tester.tap(tap);
        await tester.pump();
        await tester.pump();
        final stopsBefore = bench.player.stopCount;

        await tester.tap(tap);
        await tester.pump();
        await tester.pump();

        expect(bench.player.stopCount, greaterThan(stopsBefore));
      });
      expect(bench.engine.calls, hasLength(1));
      expect(find.byTooltip('Hear your day'), findsOneWidget);
    });
  });
}
