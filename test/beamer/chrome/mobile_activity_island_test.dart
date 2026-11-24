import 'dart:async';

import 'package:flutter/rendering.dart' show SemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/chrome/mobile_activity_island.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_chip_surface.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/task_focus_controller.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/nav_bar/mobile_navigation_launcher.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../test_utils/screenshot_harness.dart' show loadAppFonts;
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Width-driven layout: the fit rule measures the elapsed digits, so pin
  // the bundled fonts — the test font is far wider per glyph than Inter and
  // would describe thresholds that do not ship (test/README.md, "Committed
  // per-feature harnesses").
  setUpAll(loadAppFonts);

  final now = DateTime(2026, 7, 16, 9);

  late StreamController<JournalEntity?> timerStream;
  late MockTimeService timeService;
  late MockNavService navService;

  setUp(() async {
    timerStream = StreamController<JournalEntity?>.broadcast();
    timeService = MockTimeService();
    when(timeService.getStream).thenAnswer((_) => timerStream.stream);
    when(timeService.getCurrent).thenReturn(null);
    when(() => timeService.linkedFrom).thenReturn(null);
    navService = MockNavService();
    when(() => navService.beamBack()).thenReturn(null);

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<TimeService>(timeService)
          ..registerSingleton<NavService>(navService);
      },
    );
  });

  tearDown(() async {
    await timerStream.close();
    await tearDownTestGetIt();
  });

  JournalEntity timerEntry({
    String id = 'timer-1',
    Duration elapsed = const Duration(minutes: 12, seconds: 34),
  }) {
    final from = now.subtract(elapsed);
    return JournalEntity.journalEntry(
      meta: Metadata(
        id: id,
        createdAt: from,
        updatedAt: now,
        dateFrom: from,
        dateTo: now,
      ),
    );
  }

  Task task(String id) => Task(
    meta: Metadata(
      id: id,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
    ),
    data: TaskData(
      title: 'Inspect orbital penguin habitat',
      dateFrom: now,
      dateTo: now,
      status: TaskStatus.open(id: 'status', createdAt: now, utcOffset: 0),
      statusHistory: const [],
    ),
    entryText: const EntryText(plainText: ''),
  );

  /// Pumps the island the way the shell hosts it: full width, on the
  /// design-system theme, with [timer] already running.
  Future<void> pumpIsland(
    WidgetTester tester, {
    JournalEntity? timer,
    JournalEntity? linkedFrom,
    ThemeData? theme,
    MediaQueryData? mediaQueryData,
  }) async {
    when(timeService.getCurrent).thenReturn(timer);
    when(() => timeService.linkedFrom).thenReturn(linkedFrom);
    // A fresh tree every time: the island's StreamBuilder seeds itself once,
    // so a re-pump into the same slot would keep the previous timer.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const MobileActivityIsland(),
        theme: theme ?? DesignSystemTheme.dark(),
        mediaQueryData: mediaQueryData,
      ),
    );
    await tester.pump();
  }

  /// Emits on the timer stream: one pump delivers the broadcast event, the
  /// second lays out the rebuilt island.
  Future<void> emitTimer(WidgetTester tester, JournalEntity? entity) async {
    timerStream.add(entity);
    await tester.pump();
    await tester.pump();
  }

  Finder island() => find.byKey(MobileActivityIsland.islandKey);
  Finder timerCapsule() => find.byKey(MobileActivityIsland.timerKey);

  /// The glass pill: the container carrying the chip fill and the hairline
  /// outline.
  Finder glass() => find.byWidgetPredicate(
    (w) => w is Container && w.foregroundDecoration != null,
  );

  BuildContext islandContext(WidgetTester tester) =>
      tester.element(find.byType(MobileActivityIsland));

  DsTokens tokensOf(WidgetTester tester) => islandContext(tester).designTokens;

  group('visibility', () {
    testWidgets('renders nothing while no timer runs', (tester) async {
      await pumpIsland(tester);

      expect(island(), findsNothing);
      expect(find.byType(DsGlassChipSurface), findsNothing);
      expect(tester.getSize(find.byType(MobileActivityIsland)), Size.zero);
    });

    testWidgets('a timer already running shows on the first frame', (
      tester,
    ) async {
      // Seeded from the service's current entry: without it the island
      // waited for the stream's next tick, a second of nothing.
      await pumpIsland(tester, timer: timerEntry());

      expect(timerCapsule(), findsOneWidget);
      expect(find.text('00:12:34'), findsOneWidget);
    });

    testWidgets('appears when a timer starts and leaves when it stops', (
      tester,
    ) async {
      await pumpIsland(tester);
      expect(island(), findsNothing);

      await emitTimer(tester, timerEntry());
      expect(island(), findsOneWidget);
      expect(find.text('00:12:34'), findsOneWidget);

      await emitTimer(tester, null);
      expect(island(), findsNothing);
    });

    testWidgets('the digits follow every tick of the timer stream', (
      tester,
    ) async {
      await pumpIsland(tester, timer: timerEntry());

      await emitTimer(
        tester,
        timerEntry(elapsed: const Duration(minutes: 12, seconds: 35)),
      );

      expect(find.text('00:12:35'), findsOneWidget);
      expect(find.text('00:12:34'), findsNothing);
    });
  });

  group('content', () {
    testWidgets('a red dot and the elapsed time, nothing else', (
      tester,
    ) async {
      await pumpIsland(tester, timer: timerEntry());
      final tokens = tokensOf(tester);

      expect(find.text('00:12:34'), findsOneWidget);
      expect(
        find.descendant(of: island(), matching: find.byType(Text)),
        findsOneWidget,
      );
      expect(find.byType(DsGlassChipSurface), findsOneWidget);

      final dot = tester.widget<Container>(
        find.descendant(
          of: timerCapsule(),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                (w.decoration as BoxDecoration?)?.shape == BoxShape.circle,
          ),
        ),
      );
      final decoration = dot.decoration! as BoxDecoration;
      expect(decoration.color, tokens.colors.alert.error.defaultColor);
      final dotSize = tester.getSize(find.byWidget(dot));
      expect(dotSize.width, tokens.spacing.step4);
      expect(dotSize.height, tokens.spacing.step4);

      // The dot leads, then the step3 gap, then the digits.
      final dotRect = tester.getRect(find.byWidget(dot));
      final digitsRect = tester.getRect(find.text('00:12:34'));
      expect(
        digitsRect.left - dotRect.right,
        moreOrLessEquals(tokens.spacing.step3, epsilon: 0.5),
      );
    });

    testWidgets('elapsed digits are tabular so the capsule never twitches', (
      tester,
    ) async {
      await pumpIsland(tester, timer: timerEntry());
      final tokens = tokensOf(tester);
      final style = tester.widget<Text>(find.text('00:12:34')).style!;
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(style.color, tokens.colors.text.highEmphasis);
      expect(
        style.fontSize,
        tokens.typography.styles.subtitle.subtitle2.fontSize,
      );

      // Different digits, same width: the proof the feature is applied.
      final wide = tester.getSize(find.text('00:12:34')).width;
      final capsuleWidth = tester.getSize(island()).width;
      await emitTimer(tester, timerEntry(elapsed: const Duration(minutes: 48)));
      expect(tester.getSize(find.text('00:48:00')).width, wide);
      expect(tester.getSize(island()).width, capsuleWidth);
    });

    testWidgets('formats every elapsed length as h:mm:ss', (tester) async {
      for (final (elapsed, expected) in [
        (const Duration(seconds: 5), '00:00:05'),
        (const Duration(minutes: 1, seconds: 30), '00:01:30'),
        (const Duration(hours: 1, minutes: 15, seconds: 45), '01:15:45'),
      ]) {
        await pumpIsland(tester, timer: timerEntry(elapsed: elapsed));
        expect(find.text(expected), findsOneWidget, reason: '$elapsed');
      }
    });
  });

  group('chrome', () {
    testWidgets("wears the launcher chips' glass, not a palette of its own", (
      tester,
    ) async {
      await pumpIsland(tester, timer: timerEntry());
      final tokens = tokensOf(tester);
      final radius = BorderRadius.circular(tokens.radii.badgesPills);

      final container = tester.widget<Container>(glass());
      final fill = container.decoration! as BoxDecoration;
      expect(fill.color, dsGlassChipFill(tokens));
      expect(fill.borderRadius, radius);
      final outline = container.foregroundDecoration! as BoxDecoration;
      expect(outline.border, dsGlassChipBorder(tokens));
      expect(outline.borderRadius, radius);

      final surface = tester.widget<DsGlassChipSurface>(
        find.byType(DsGlassChipSurface),
      );
      expect(surface.blurred, isTrue);
      expect(surface.radius, radius);
    });

    testWidgets('the same tokens carry it in the light theme', (
      tester,
    ) async {
      await pumpIsland(
        tester,
        timer: timerEntry(),
        theme: DesignSystemTheme.light(),
      );
      final tokens = tokensOf(tester);
      final container = tester.widget<Container>(glass());
      expect(
        (container.decoration! as BoxDecoration).color,
        dsGlassChipFill(tokens),
      );
      expect(
        tester.widget<Text>(find.text('00:12:34')).style!.color,
        tokens.colors.text.highEmphasis,
      );
    });

    testWidgets('the capsule is one target end to end, a step under the '
        'chips', (tester) async {
      await pumpIsland(tester, timer: timerEntry());
      final context = islandContext(tester);
      final tokens = context.designTokens;

      expect(
        MobileActivityIsland.capsuleHeight(context),
        tokens.spacing.step8,
      );
      expect(
        MobileActivityIsland.capsuleHeight(context),
        lessThan(MobileNavigationLauncher.chipHeight(context)),
      );
      expect(tester.getRect(timerCapsule()), tester.getRect(glass()));
      expect(tester.getSize(timerCapsule()).height, tokens.spacing.step8);
      expect(
        tester.widget<GestureDetector>(timerCapsule()).behavior,
        HitTestBehavior.opaque,
      );
    });

    testWidgets(
      'grows with the system text scale so digits are never clipped',
      (tester) async {
        // At 3× the subtitle2 line is 60 px — half again the default
        // capsule — and the launcher beside it grows the same way.
        const largeText = MediaQueryData(
          size: Size(390, 932),
          textScaler: TextScaler.linear(3),
        );
        await pumpIsland(
          tester,
          timer: timerEntry(),
          mediaQueryData: largeText,
        );
        final context = islandContext(tester);
        final tokens = context.designTokens;

        final expected =
            largeText.textScaler
                .scale(tokens.typography.lineHeight.subtitle2)
                .ceilToDouble() +
            tokens.spacing.step2 * 2;
        expect(expected, greaterThan(tokens.spacing.step8));
        expect(MobileActivityIsland.capsuleHeight(context), expected);
        final pill = tester.getRect(timerCapsule());
        expect(pill.height, expected);
        // The digits sit fully inside the pill — nothing for a clip to cut.
        final rect = tester.getRect(find.text('00:12:34'));
        expect(rect.top, greaterThanOrEqualTo(pill.top));
        expect(rect.bottom, lessThanOrEqualTo(pill.bottom));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('sits centred in the width it is given', (tester) async {
      await pumpIsland(tester, timer: timerEntry());

      final host = tester.getRect(find.byType(MobileActivityIsland));
      expect(
        tester.getCenter(island()).dx,
        moreOrLessEquals(host.center.dx, epsilon: 0.5),
      );
      expect(tester.getSize(island()).width, lessThan(host.width));
    });

    testWidgets('where even the capsule cannot fit, it shrinks rather than '
        'clips a digit', (tester) async {
      // Narrower than any phone the app targets, at the largest scale.
      const impossible = MediaQueryData(
        size: Size(80, 600),
        textScaler: TextScaler.linear(3),
      );
      await pumpIsland(
        tester,
        timer: timerEntry(),
        mediaQueryData: impossible,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('00:12:34'), findsOneWidget);
      expect(
        tester.getRect(glass()).width,
        lessThanOrEqualTo(impossible.size.width),
      );
      expect(
        MobileActivityIsland.width(islandContext(tester), timerRuns: true),
        greaterThan(impossible.size.width),
        reason: 'the content really is wider than the window',
      );
      // Shrunk, not cut.
      final fitted = tester.widget<FittedBox>(
        find.descendant(of: glass(), matching: find.byType(FittedBox)),
      );
      expect(fitted.fit, BoxFit.scaleDown);
    });
  });

  group('MobileActivityBuilder', () {
    /// Pumps the builder and records every `timerRuns` it hands out, and
    /// checks the child passes through untouched.
    Future<List<bool>> pumpBuilder(
      WidgetTester tester, {
      JournalEntity? timer,
    }) async {
      when(timeService.getCurrent).thenReturn(timer);
      final seen = <bool>[];
      const child = SizedBox(key: ValueKey('builderChild'));
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MobileActivityBuilder(
            child: child,
            builder: (context, passed, {required timerRuns}) {
              expect(passed, same(child));
              seen.add(timerRuns);
              return passed;
            },
          ),
          theme: DesignSystemTheme.dark(),
        ),
      );
      await tester.pump();
      return seen;
    }

    testWidgets('a timer already running counts on the first frame', (
      tester,
    ) async {
      final seen = await pumpBuilder(tester, timer: timerEntry());

      expect(seen.first, isTrue);
      expect(find.byKey(const ValueKey('builderChild')), findsOneWidget);
    });

    testWidgets('rebuilds when a timer starts or stops, not on every tick', (
      tester,
    ) async {
      final seen = await pumpBuilder(tester);
      expect(seen, [false]);

      await emitTimer(tester, timerEntry());
      for (var s = 35; s < 38; s++) {
        await emitTimer(tester, timerEntry(elapsed: Duration(seconds: s)));
      }
      await emitTimer(tester, null);

      expect(seen, [false, true, false]);
      // One subscription for the builder's lifetime, not one per rebuild.
      verify(timeService.getStream).called(1);
    });
  });

  group('geometry', () {
    testWidgets('docked, the capsule is centred on the launcher row', (
      tester,
    ) async {
      await pumpIsland(tester, timer: timerEntry());
      final context = islandContext(tester);
      final chip = MobileNavigationLauncher.chipHeight(context);
      final capsule = MobileActivityIsland.capsuleHeight(context);

      final bottom = MobileActivityIsland.dockedBottom(context);
      final rowBottom = MobileNavigationLauncher.rowBottom(context);
      // Same centre line as the chips: equal air above and below.
      expect(bottom - rowBottom, (chip - capsule) / 2);
      expect(bottom + capsule / 2, rowBottom + chip / 2);
    });

    testWidgets('in the row, the capsule claims nothing above the bar', (
      tester,
    ) async {
      await pumpIsland(tester, timer: timerEntry());
      final context = islandContext(tester);

      for (final timerRuns in [false, true]) {
        expect(
          MobileActivityIsland.heightAboveBar(
            context,
            timerRuns: timerRuns,
            inRow: true,
          ),
          0,
          reason: 'timerRuns: $timerRuns',
        );
      }
    });

    testWidgets('floating, the capsule and its float gap count', (
      tester,
    ) async {
      await pumpIsland(tester, timer: timerEntry());
      final context = islandContext(tester);
      final tokens = context.designTokens;

      expect(MobileActivityIsland.floatGap(context), tokens.spacing.step3);
      expect(
        MobileActivityIsland.heightAboveBar(
          context,
          timerRuns: true,
          inRow: false,
        ),
        tokens.spacing.step8 + tokens.spacing.step3,
      );
    });

    testWidgets('with no timer running it claims nothing, even floating', (
      tester,
    ) async {
      await pumpIsland(tester);
      final context = islandContext(tester);

      expect(
        MobileActivityIsland.heightAboveBar(
          context,
          timerRuns: false,
          inRow: false,
        ),
        0,
      );
      expect(MobileActivityIsland.width(context, timerRuns: false), 0);
    });

    testWidgets('width matches what paints', (tester) async {
      for (final scale in [1.0, 2.0]) {
        await pumpIsland(
          tester,
          timer: timerEntry(),
          mediaQueryData: MediaQueryData(
            size: const Size(390, 844),
            textScaler: TextScaler.linear(scale),
          ),
        );
        expect(
          MobileActivityIsland.width(islandContext(tester), timerRuns: true),
          moreOrLessEquals(tester.getSize(island()).width, epsilon: 0.5),
          reason: 'scale $scale',
        );
      }
    });
  });

  group('MobileIslandLayout.resolve', () {
    late BuildContext resolvedContext;

    /// Resolves the layout in a real context of [size] at [scale], with a
    /// worded page action and, when [utility], the chat button docked.
    Future<MobileIslandLayout> resolveAt(
      WidgetTester tester, {
      required bool timerRuns,
      Size size = const Size(390, 844),
      double scale = 1,
      bool utility = false,
    }) async {
      late MobileIslandLayout layout;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) {
              resolvedContext = context;
              layout = MobileIslandLayout.resolve(
                context,
                timerRuns: timerRuns,
                buildLauncher: (reserve) => MobileNavigationLauncher(
                  onOpenMenu: () {},
                  utilityAction: utility
                      ? MobileNavDockAction.glyph(
                          label: 'Chat',
                          icon: Icons.chat,
                          onPressed: () {},
                        )
                      : null,
                  pageAction: MobileNavDockAction.worded(
                    label: 'New task',
                    icon: Icons.add,
                    onPressed: () {},
                  ),
                  reservedCenterWidth: reserve,
                ),
              );
              return const SizedBox.shrink();
            },
          ),
          theme: DesignSystemTheme.dark(),
          mediaQueryData: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
        ),
      );
      return layout;
    }

    testWidgets('nothing running: in the row, reserving nothing', (
      tester,
    ) async {
      final layout = await resolveAt(tester, timerRuns: false);

      expect(layout.inRow, isTrue);
      expect(layout.launcher.reservedCenterWidth, 0);
    });

    testWidgets('a running timer sits in the row, its width reserved, while '
        'it fits', (tester) async {
      final layout = await resolveAt(tester, timerRuns: true, utility: true);

      expect(layout.inRow, isTrue);
      expect(
        layout.launcher.reservedCenterWidth,
        MobileActivityIsland.width(resolvedContext, timerRuns: true),
      );
      expect(layout.launcher.reservedCenterWidth, greaterThan(0));
      expect(layout.launcher.centerFits(resolvedContext), isTrue);
    });

    testWidgets('floats with a reserve-free launcher when the row has no '
        'room', (tester) async {
      final layout = await resolveAt(
        tester,
        timerRuns: true,
        size: const Size(320, 700),
        scale: 3,
        utility: true,
      );
      final context = resolvedContext;

      // The precondition: the capsule really does not fit beside the menu,
      // the chat button and the page action.
      final reserving = MobileNavigationLauncher(
        onOpenMenu: () {},
        utilityAction: layout.launcher.utilityAction,
        pageAction: layout.launcher.pageAction,
        reservedCenterWidth: MobileActivityIsland.width(
          context,
          timerRuns: true,
        ),
      );
      expect(reserving.centerFits(context), isFalse);

      expect(layout.inRow, isFalse);
      expect(layout.launcher.reservedCenterWidth, 0);
    });
  });

  group('the timer capsule', () {
    testWidgets('is a button that names itself and its elapsed time', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpIsland(tester, timer: timerEntry());
        final data = tester.getSemantics(timerCapsule()).getSemanticsData();
        expect(data.label, 'Running timer, 00:12:34');
        expect(data.hint, 'Open running timer');
        expect(data.hasAction(SemanticsAction.tap), isTrue);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('an assistive-tech tap opens the timer like a touch does', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpIsland(tester, timer: timerEntry(id: 'timer-7'));

        tester.semantics.tap(find.semantics.byLabel('Running timer, 00:12:34'));
        await tester.pump();

        verify(
          () => navService.beamToNamed(
            '/journal/timer-7',
            data: any(named: 'data'),
          ),
        ).called(1);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('a task-linked timer publishes focus and opens the task', (
      tester,
    ) async {
      final entry = timerEntry(id: 'entry-456');
      await pumpIsland(tester, timer: entry, linkedFrom: task('task-123'));

      await tester.tap(timerCapsule());
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MobileActivityIsland)),
      );
      final intent = container.read(taskFocusControllerProvider('task-123'));
      expect(intent?.taskId, 'task-123');
      expect(intent?.entryId, 'entry-456');
      verify(
        () =>
            navService.beamToNamed('/tasks/task-123', data: any(named: 'data')),
      ).called(1);
    });

    testWidgets('a journal-linked timer opens the linked entry', (
      tester,
    ) async {
      await pumpIsland(
        tester,
        timer: timerEntry(),
        linkedFrom: timerEntry(id: 'journal-1'),
      );

      await tester.tap(timerCapsule());
      await tester.pump();

      verify(
        () => navService.beamToNamed(
          '/journal/journal-1',
          data: any(named: 'data'),
        ),
      ).called(1);
    });

    testWidgets('an unlinked timer opens its own entry', (tester) async {
      await pumpIsland(tester, timer: timerEntry(id: 'timer-9'));

      await tester.tap(timerCapsule());
      await tester.pump();

      verify(
        () => navService.beamToNamed(
          '/journal/timer-9',
          data: any(named: 'data'),
        ),
      ).called(1);
    });
  });
}
