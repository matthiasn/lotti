import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/state/spoken_track.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_briefing_strip.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_capacity_bar.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_row_scaffold.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_task_metadata.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_model_repository.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_get_it.dart';
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
  String? taskId,
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
    taskId: taskId,
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
    double? width,
    bool dense = false,
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        mediaQueryData: width == null
            ? null
            : phoneMediaQueryData.copyWith(size: Size(width, 900)),
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
          ...overrides,
        ],
        child: Align(
          alignment: Alignment.topCenter,
          child: DayBriefingStrip(
            draft: draft ?? _plan(),
            hasPlan: hasPlan,
            actualBlocks: actualBlocks,
            dense: dense,
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

/// The legend entry naming [name] with [minutes]: the two sit in one entry,
/// the name free to shorten and the minutes never.
Finder _legendEntry(String name, String minutes) => find.ancestor(
  of: find.text(minutes),
  matching: find.byWidgetPredicate(
    (w) =>
        w is Row &&
        w.children.any(
          (c) =>
              c is Flexible &&
              c.child is Text &&
              (c.child as Text).data == name,
        ),
  ),
);

void main() {
  late _Bench bench;
  setUp(() => bench = _Bench());

  group('DayBriefingStrip sentence', () {
    testWidgets('counts the blocks and names what is next', (tester) async {
      await _at(10, () => bench.pump(tester));

      expect(
        find.text('You have 3 blocks planned. Next up at 1:00\u00A0PM: Write.'),
        findsOneWidget,
      );
    });

    testWidgets('moves on to the following block once the next one starts', (
      tester,
    ) async {
      var now = _day.add(const Duration(hours: 10));
      await withClock(Clock(() => now), () async {
        await bench.pump(tester);
        expect(
          find.textContaining('Next up at 1:00\u00A0PM: Write.'),
          findsOne,
        );

        now = _day.add(const Duration(hours: 13, seconds: 1));
        await tester.pump(const Duration(hours: 3, seconds: 1));

        expect(
          find.textContaining('Next up at 3:00\u00A0PM: Lunch.'),
          findsOne,
        );
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
          "There's no plan for this day yet. A short check\u2011in will make one.",
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

    testWidgets('captions are medium-emphasis with tabular figures', (
      tester,
    ) async {
      await _at(10, () => bench.pump(tester));

      final style = _text(tester, '3h planned').style!;
      expect(style.color, _tokens(tester).colors.text.mediumEmphasis);
      expect(style.fontFeatures, dayFigures);
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

    testWidgets('without a plan, the bar is the recorded time by category', (
      tester,
    ) async {
      await _at(
        12,
        () => bench.pump(
          tester,
          draft: DraftPlan.emptyForDay(_day),
          hasPlan: false,
          actualBlocks: [
            _block('A', 8, 90, type: TimeBlockType.manual),
            _block('B', 10, 30, type: TimeBlockType.manual, category: _admin),
          ],
        ),
      );

      final bar = tester.widget<DayCapacityBar>(find.byType(DayCapacityBar));
      expect(bar.segments.map((s) => (s.color, s.minutes)), [
        (categoryColorFromHex(_deep.colorHex), 90),
        (categoryColorFromHex(_admin.colorHex), 30),
      ]);
      // No capacity to fill: one solid line, not progress towards a goal.
      expect(bar.capacityMinutes, 0);
    });
  });

  group('DayBriefingStrip surface', () {
    testWidgets('is the aiCard surface at radii.l', (tester) async {
      await _at(10, () => bench.pump(tester));
      final tokens = _tokens(tester);

      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(DayBriefingStrip),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color, tokens.colors.aiCard.background);
      expect(decoration.border, Border.all(color: tokens.colors.aiCard.border));
      expect(decoration.borderRadius, BorderRadius.circular(tokens.radii.l));
    });
  });

  group('DayBriefingStrip legend', () {
    testWidgets('names the largest categories with their minutes', (
      tester,
    ) async {
      await _at(10, () => bench.pump(tester));

      expect(_legendEntry('Deep', '2h 30m'), findsOneWidget);
      expect(_legendEntry('Admin', '30m'), findsOneWidget);
    });

    DraftPlan fourCategories() {
      const c = DayAgentCategory(id: 'c', name: 'Calls', colorHex: '00AAFF');
      const d = DayAgentCategory(id: 'd', name: 'Desk', colorHex: 'AA00FF');
      return _plan(
        blocks: [
          _block('a', 8, 120),
          _block('b', 11, 60, category: _admin),
          _block('c', 13, 45, category: c),
          _block('d', 15, 15, category: d),
        ],
      );
    }

    testWidgets('on a phone, names the largest two and sums up the rest', (
      tester,
    ) async {
      await _at(10, () => bench.pump(tester, draft: fourCategories()));

      expect(_legendEntry('Deep', '2h'), findsOneWidget);
      expect(_legendEntry('Admin', '1h'), findsOneWidget);
      expect(_legendEntry('+2 more', '1h'), findsOneWidget);
      expect(find.textContaining('Calls'), findsNothing);
      // The bar folds the same tail into one decorative segment, ranked
      // below the category hues and set off from the free track by its
      // gap, so every colour on it is named.
      final bar = tester.widget<DayCapacityBar>(find.byType(DayCapacityBar));
      expect(bar.segments.map((s) => s.minutes), [120, 60, 60]);
      expect(
        bar.segments.last.color,
        _tokens(tester).colors.decorative.level02,
      );
    });

    testWidgets('on a wide pane, names every category', (tester) async {
      await _at(
        10,
        () => bench.pump(tester, draft: fourCategories(), width: 1400),
      );

      for (final (name, minutes) in [
        ('Deep', '2h'),
        ('Admin', '1h'),
        ('Calls', '45m'),
        ('Desk', '15m'),
      ]) {
        expect(_legendEntry(name, minutes), findsOneWidget);
      }
      final bar = tester.widget<DayCapacityBar>(find.byType(DayCapacityBar));
      expect(bar.segments, hasLength(4));
    });

    testWidgets('a day without a plan names its recorded categories', (
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

      expect(_legendEntry('Deep', '1h 30m'), findsOneWidget);
    });

    testWidgets(
      'entries wrap rather than cut a name; the minutes read a step '
      'stronger and never shorten',
      (tester) async {
        await _at(10, () => bench.pump(tester, draft: fourCategories()));
        final tokens = _tokens(tester);

        // The entries sit in a Wrap: a name that does not fit moves to the
        // next line whole.
        expect(
          find.ancestor(of: find.text('Deep'), matching: find.byType(Wrap)),
          findsOneWidget,
        );
        final name = tester.widget<Text>(find.text('Deep'));
        expect(name.style!.color, tokens.colors.text.lowEmphasis);
        expect(name.textWidthBasis, TextWidthBasis.longestLine);
        final minutes = tester.widget<Text>(find.text('2h'));
        expect(minutes.overflow, isNull);
        expect(minutes.style!.color, tokens.colors.text.mediumEmphasis);
        expect(
          find.ancestor(of: find.text('2h'), matching: find.byType(Flexible)),
          findsNothing,
          reason: 'the minutes never yield width',
        );
        // A step2 between a name and its figure.
        expect(
          tester.getTopLeft(find.text('2h')).dx -
              tester.getTopRight(find.text('Deep')).dx,
          closeTo(tokens.spacing.step2, 0.01),
        );
      },
    );

    testWidgets('a long legend wraps to a second line on a phone', (
      tester,
    ) async {
      const long = DayAgentCategory(
        id: 'long',
        name: 'Interplanetary penguin logistics and fish diplomacy',
        colorHex: '00AAFF',
      );
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _at(
        10,
        () => bench.pump(
          tester,
          width: 360,
          draft: _plan(
            blocks: [
              _block('a', 8, 120),
              _block('b', 11, 60, category: long),
            ],
          ),
        ),
      );

      final first = tester.getTopLeft(find.text('Deep')).dy;
      final second = tester.getTopLeft(find.text(long.name)).dy;
      expect(second, greaterThan(first));
      expect(
        tester.widget<Text>(find.text(long.name)).data,
        long.name,
        reason: 'the name is whole, on its own line',
      );
    });
  });

  group('DayBriefingStrip dense', () {
    testWidgets(
      'keeps the sentence, the line and its planned/free captions, and '
      'leaves out the legend',
      (tester) async {
        await _at(10, () => bench.pump(tester, dense: true));

        expect(find.textContaining('You have 3'), findsOneWidget);
        expect(find.byType(DayCapacityBar), findsOneWidget);
        final messages = tester.element(find.byType(DayBriefingStrip)).messages;
        // 3h planned of an 8h day: 5h free.
        expect(
          find.text(messages.dailyOsNextBriefingPlannedCaption('3h')),
          findsOneWidget,
        );
        expect(
          find.text(messages.dailyOsNextBriefingFreeCaption('5h')),
          findsOneWidget,
        );
        expect(_legendEntry('Deep', '2h 30m'), findsNothing);
      },
    );
  });

  group('DayBriefingStrip and the live task', () {
    setUp(setUpTestGetIt);
    tearDown(tearDownTestGetIt);

    // The task was renamed and moved to another category since planning.
    final live = liveTaskMetadataProvider.overrideWith(
      (ref, taskId) async => const LiveTaskMetadata(
        title: 'Ship the migration',
        categoryId: 'ops',
        categoryName: 'Operations',
        categoryColorHex: '#00AA88',
      ),
    );

    testWidgets("names the next block by its task's live title", (
      tester,
    ) async {
      await _at(
        10,
        () => bench.pump(
          tester,
          draft: _plan(blocks: [_block('Write', 13, 90, taskId: 'task-1')]),
          overrides: [live],
        ),
      );
      await tester.pump();

      expect(find.textContaining('Next up at'), findsOneWidget);
      expect(find.textContaining('Ship the migration'), findsOneWidget);
      expect(find.textContaining('Write'), findsNothing);
    });

    testWidgets("colours the bar and names the legend by the task's live "
        'category, as the timeline and the agenda do', (tester) async {
      await _at(
        10,
        () => bench.pump(
          tester,
          draft: _plan(blocks: [_block('Write', 13, 90, taskId: 'task-1')]),
          overrides: [live],
        ),
      );
      await tester.pump();

      expect(_legendEntry('Operations', '1h 30m'), findsOneWidget);
      expect(find.text('Deep'), findsNothing);
      final bar = tester.widget<DayCapacityBar>(find.byType(DayCapacityBar));
      expect(bar.segments.single.color, categoryColorFromHex('#00AA88'));
    });
  });

  group('DayBriefingStrip headline typesetting', () {
    testWidgets('keeps the time and its meridiem together', (tester) async {
      await _at(10, () => bench.pump(tester));

      final sentence = tester
          .widget<Text>(find.textContaining('You have 3'))
          .data!;
      expect(sentence, contains('1:00\u00A0PM'));
      expect(sentence, isNot(contains('1:00 PM')));
    });

    testWidgets('a title ending in its own stop gets no second one', (
      tester,
    ) async {
      await _at(
        10,
        () => bench.pump(
          tester,
          draft: _plan(blocks: [_block('Ready?', 13, 30)]),
        ),
      );

      expect(find.textContaining('Ready?'), findsOneWidget);
      expect(find.textContaining('Ready?.'), findsNothing);
    });
  });

  group('DayBriefingStrip voice', () {
    final tap = find.byKey(const Key('daily_os_briefing_play'));

    testWidgets('offers no play button while the companion cannot speak', (
      tester,
    ) async {
      await _at(10, () => bench.pump(tester));

      expect(tap, findsNothing);
      // Nothing else on the strip is a tap target.
      await tester.tap(find.byType(DayBriefingStrip));
      await tester.pump();
      expect(bench.engine.calls, isEmpty);
    });

    testWidgets('the play button ends the sentence row, in the violet accent', (
      tester,
    ) async {
      await _at(10, () => bench.pump(tester, voice: true));

      final sentence = tester.getRect(find.textContaining('You have 3'));
      final button = tester.getRect(tap);
      expect(button.left, greaterThan(sentence.right));
      expect(
        tester.widget<Icon>(find.byIcon(LottiIcons.play)).color,
        _tokens(tester).colors.aiCard.accent,
      );
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
        startsWith(
          'You have 3 blocks planned. Next up at 1:00 PM: Write.',
        ),
      );
      expect(find.byTooltip('Stop the briefing'), findsOneWidget);
      expect(find.byIcon(LottiIcons.stop), findsOneWidget);
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
