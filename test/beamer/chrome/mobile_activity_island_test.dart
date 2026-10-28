import 'dart:async';

import 'package:flutter/rendering.dart' show SemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/chrome/mobile_activity_island.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_chip_surface.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_orb.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/task_focus_controller.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/nav_bar/mobile_navigation_launcher.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart' show Amplitude;

import '../../helpers/stub_audio_recorder_controller.dart';
import '../../mocks/mocks.dart';
import '../../test_utils/screenshot_harness.dart' show loadAppFonts;
import '../../widget_test_utils.dart';

/// A recorder controller whose build fails, standing in for the MediaKit /
/// audio wiring that can throw on some hosts.
class _BrokenAudioRecorderController extends AudioRecorderController {
  @override
  AudioRecorderState build() => throw StateError('no audio backend');
}

EntryState _savedState(String id, JournalEntity entry) => EntryState.saved(
  entryId: id,
  entry: entry,
  showMap: false,
  isFocused: false,
  shouldShowEditorToolBar: false,
);

/// Serves one saved entry for the recording's linked id, so the island can
/// resolve the category it hands back to the modal.
class _StubEntryController extends EntryController {
  _StubEntryController(this.entry);

  final JournalEntity entry;

  @override
  Future<EntryState?> build() async => _savedState(id, entry);
}

/// A linked entry that stays loading until the test completes it.
class _PendingEntryController extends EntryController {
  _PendingEntryController(this.completer);

  final Completer<JournalEntity> completer;

  @override
  Future<EntryState?> build() async => _savedState(id, await completer.future);
}

/// A linked entry whose load fails.
class _FailingEntryController extends EntryController {
  @override
  Future<EntryState?> build() async => throw StateError('entry unavailable');
}

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

    final recorderRepository = MockAudioRecorderRepository();
    when(
      () => recorderRepository.amplitudeStream,
    ).thenAnswer((_) => const Stream<Amplitude>.empty());
    when(recorderRepository.dispose).thenAnswer((_) async {});

    final getItMocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<TimeService>(timeService)
          ..registerSingleton<NavService>(navService)
          ..registerSingleton<EditorStateService>(MockEditorStateService())
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
          ..registerSingleton<AudioRecorderRepository>(recorderRepository);
      },
    );
    when(
      () => getItMocks.journalDb.getConfigFlag(any()),
    ).thenAnswer((_) async => false);
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

  AudioRecorderState recorder({
    AudioRecorderStatus status = AudioRecorderStatus.recording,
    Duration progress = const Duration(minutes: 3, seconds: 12),
    bool modalVisible = false,
    String? linkedId,
  }) => AudioRecorderState(
    status: status,
    progress: progress,
    vu: -8,
    dBFS: -18,
    showIndicator: status == AudioRecorderStatus.recording,
    modalVisible: modalVisible,
    linkedId: linkedId,
  );

  /// Pumps the island the way the shell hosts it: full width, on the
  /// design-system theme, with the recorder in [state].
  Future<void> pumpIsland(
    WidgetTester tester, {
    AudioRecorderState? state,
    JournalEntity? timer,
    JournalEntity? linkedFrom,
    bool omitAudio = false,
    AudioRecorderController Function()? controller,
    ThemeData? theme,
    MediaQueryData? mediaQueryData,
    List<Override> extraOverrides = const [],
  }) async {
    when(timeService.getCurrent).thenReturn(timer);
    when(() => timeService.linkedFrom).thenReturn(linkedFrom);
    // A fresh tree every time: the island's StreamBuilder seeds itself once,
    // and a ProviderScope cannot swap a provider override in place, so a
    // re-pump into the same slot would keep the previous state.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        MobileActivityIsland(omitAudio: omitAudio),
        theme: theme ?? DesignSystemTheme.dark(),
        mediaQueryData: mediaQueryData,
        overrides: <Override>[
          audioRecorderControllerProvider.overrideWith(
            controller ?? () => StubAudioRecorderController(state),
          ),
          ...extraOverrides,
        ],
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
  Finder recordingCapsule() => find.byKey(MobileActivityIsland.recordingKey);

  /// The glass pill inside [capsule]: the container carrying the chip fill
  /// and the hairline outline.
  Finder glassOf(Finder capsule) => find.descendant(
    of: capsule,
    matching: find.byWidgetPredicate(
      (w) => w is Container && w.foregroundDecoration != null,
    ),
  );

  DsTokens tokensOf(WidgetTester tester) =>
      tester.element(find.byType(MobileActivityIsland)).designTokens;

  BuildContext islandContext(WidgetTester tester) =>
      tester.element(find.byType(MobileActivityIsland));

  group('showsRecording', () {
    test('a live recording with its modal closed counts', () {
      expect(
        MobileActivityIsland.showsRecording(recorder(), omitAudio: false),
        isTrue,
      );
    });

    test('a recording whose modal is open does not — the modal shows it', () {
      expect(
        MobileActivityIsland.showsRecording(
          recorder(modalVisible: true),
          omitAudio: false,
        ),
        isFalse,
      );
    });

    test('a session paused mid-recording still counts — the modal treats it '
        'as active, and a dismissed modal is its only way back', () {
      expect(
        MobileActivityIsland.showsRecording(
          recorder(status: AudioRecorderStatus.paused),
          omitAudio: false,
        ),
        isTrue,
      );
    });

    test('a recorder with no session in flight does not', () {
      for (final status in AudioRecorderStatus.values.where(
        (s) =>
            s != AudioRecorderStatus.recording &&
            s != AudioRecorderStatus.paused,
      )) {
        expect(
          MobileActivityIsland.showsRecording(
            recorder(status: status),
            omitAudio: false,
          ),
          isFalse,
          reason: '$status',
        );
      }
    });

    test('a build that omits audio never counts one', () {
      expect(
        MobileActivityIsland.showsRecording(recorder(), omitAudio: true),
        isFalse,
      );
    });
  });

  group('visibility', () {
    testWidgets('renders nothing while neither a timer nor a recording runs', (
      tester,
    ) async {
      await pumpIsland(
        tester,
        state: recorder(status: AudioRecorderStatus.stopped),
      );

      expect(island(), findsNothing);
      expect(find.byType(DsGlassChipSurface), findsNothing);
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

      await emitTimer(tester, null);
      expect(island(), findsNothing);
    });

    testWidgets('a recording with its modal open is not shown', (
      tester,
    ) async {
      await pumpIsland(tester, state: recorder(modalVisible: true));

      expect(island(), findsNothing);
    });

    testWidgets('a paused session stays on the island with its elapsed time', (
      tester,
    ) async {
      await pumpIsland(
        tester,
        state: recorder(status: AudioRecorderStatus.paused),
      );

      expect(recordingCapsule(), findsOneWidget);
      expect(find.text('00:03:12'), findsOneWidget);
    });

    testWidgets('a build that omits audio drops only the recording capsule', (
      tester,
    ) async {
      await pumpIsland(tester, state: recorder(), omitAudio: true);
      expect(
        island(),
        findsNothing,
        reason: 'a recording alone has nothing left to show',
      );

      await pumpIsland(
        tester,
        state: recorder(),
        timer: timerEntry(),
        omitAudio: true,
      );
      expect(timerCapsule(), findsOneWidget);
      expect(recordingCapsule(), findsNothing);
      expect(find.byType(DsGlassChipSurface), findsOneWidget);
    });

    testWidgets('a broken recorder backend never takes the timer down', (
      tester,
    ) async {
      await pumpIsland(
        tester,
        timer: timerEntry(),
        controller: _BrokenAudioRecorderController.new,
      );

      expect(timerCapsule(), findsOneWidget);
      expect(recordingCapsule(), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('content', () {
    testWidgets('a running timer alone: red dot and elapsed time, no orb', (
      tester,
    ) async {
      await pumpIsland(tester, timer: timerEntry());
      final tokens = tokensOf(tester);

      expect(find.text('00:12:34'), findsOneWidget);
      expect(find.byType(AudioRecordingOrb), findsNothing);
      expect(recordingCapsule(), findsNothing);

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
      expect(tester.getSize(find.byWidget(dot)).width, tokens.spacing.step4);
    });

    testWidgets('a recording alone: live orb and elapsed time, no dot', (
      tester,
    ) async {
      await pumpIsland(tester, state: recorder());
      final tokens = tokensOf(tester);

      expect(find.text('00:03:12'), findsOneWidget);
      expect(timerCapsule(), findsNothing);
      final orb = tester.widget<AudioRecordingOrb>(
        find.byType(AudioRecordingOrb),
      );
      expect(orb.dBFS, -18);
      expect(orb.size, tokens.spacing.step6);
    });

    testWidgets('both: the timer stacks above the recording, one gap apart', (
      tester,
    ) async {
      await pumpIsland(tester, state: recorder(), timer: timerEntry());
      final tokens = tokensOf(tester);

      final timerRect = tester.getRect(timerCapsule());
      final recordingRect = tester.getRect(recordingCapsule());
      expect(timerRect.bottom, lessThan(recordingRect.top));
      expect(recordingRect.top - timerRect.bottom, tokens.spacing.step2);
      // One column, not two ragged pills: the same width, the same centre.
      expect(timerRect.width, recordingRect.width);
      expect(timerRect.center.dx, recordingRect.center.dx);
      expect(
        tester.getSize(island()).height,
        MobileActivityIsland.stackHeight(
          islandContext(tester),
          const MobileActivity(timer: true, recording: true),
        ),
      );
      // Both clocks keep their digits.
      expect(find.text('00:12:34'), findsOneWidget);
      expect(find.text('00:03:12'), findsOneWidget);
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
      await emitTimer(tester, timerEntry(elapsed: const Duration(minutes: 48)));
      expect(tester.getSize(find.text('00:48:00')).width, wide);
    });

    testWidgets('formats every elapsed length as h:mm:ss', (tester) async {
      for (final (progress, expected) in [
        (const Duration(seconds: 5), '00:00:05'),
        (const Duration(minutes: 1, seconds: 30), '00:01:30'),
        (const Duration(hours: 1, minutes: 15, seconds: 45), '01:15:45'),
      ]) {
        await pumpIsland(tester, state: recorder(progress: progress));
        expect(find.text(expected), findsOneWidget, reason: '$progress');
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

      final container = tester.widget<Container>(glassOf(timerCapsule()));
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
      final container = tester.widget<Container>(glassOf(timerCapsule()));
      expect(
        (container.decoration! as BoxDecoration).color,
        dsGlassChipFill(tokens),
      );
      expect(
        tester.widget<Text>(find.text('00:12:34')).style!.color,
        tokens.colors.text.highEmphasis,
      );
    });

    testWidgets('each capsule is one capsule height tall and a target '
        'end to end', (tester) async {
      await pumpIsland(tester, state: recorder(), timer: timerEntry());
      final tokens = tokensOf(tester);

      expect(
        MobileActivityIsland.capsuleHeight(islandContext(tester)),
        tokens.spacing.step8,
      );
      for (final capsule in [timerCapsule(), recordingCapsule()]) {
        // The button is the whole glass pill, not the text line inside it.
        expect(tester.getRect(capsule), tester.getRect(glassOf(capsule)));
        expect(tester.getSize(capsule).height, tokens.spacing.step8);
      }
    });

    testWidgets(
      'grows with the system text scale so digits are never clipped',
      (
        tester,
      ) async {
        // At 3× the subtitle2 line is 60 px — half again the default
        // capsule — and the launcher beside it grows the same way.
        const largeText = MediaQueryData(
          size: Size(390, 932),
          textScaler: TextScaler.linear(3),
        );
        await pumpIsland(
          tester,
          state: recorder(),
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
        for (final (capsule, digits) in [
          (timerCapsule(), '00:12:34'),
          (recordingCapsule(), '00:03:12'),
        ]) {
          final pill = tester.getRect(capsule);
          expect(pill.height, expected, reason: digits);
          // The digits sit fully inside the pill — nothing for a clip to cut.
          final rect = tester.getRect(find.text(digits));
          expect(rect.top, greaterThanOrEqualTo(pill.top), reason: digits);
          expect(rect.bottom, lessThanOrEqualTo(pill.bottom), reason: digits);
        }
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
    });

    testWidgets(
      'where even one elapsed time cannot fit, it shrinks rather than '
      'clips a digit',
      (tester) async {
        // Narrower than any phone the app targets, at the largest scale.
        const impossible = MediaQueryData(
          size: Size(120, 600),
          textScaler: TextScaler.linear(3),
        );
        await pumpIsland(
          tester,
          state: recorder(),
          timer: timerEntry(),
          mediaQueryData: impossible,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('00:12:34'), findsOneWidget);
        expect(find.text('00:03:12'), findsOneWidget);
        expect(
          tester.getRect(timerCapsule()).width,
          lessThanOrEqualTo(impossible.size.width),
        );
        expect(
          MobileActivityIsland.width(
            islandContext(tester),
            const MobileActivity(timer: true, recording: false),
          ),
          greaterThan(impossible.size.width),
          reason: 'the content really is wider than the window',
        );
        // Shrunk, not cut.
        final fitted = tester.widget<FittedBox>(
          find
              .descendant(of: timerCapsule(), matching: find.byType(FittedBox))
              .first,
        );
        expect(fitted.fit, BoxFit.scaleDown);
      },
    );
  });

  group('MobileActivityBuilder', () {
    /// Pumps the builder and records every activity it hands out.
    Future<List<MobileActivity>> pumpBuilder(
      WidgetTester tester, {
      AudioRecorderState? state,
      JournalEntity? timer,
      bool omitAudio = false,
    }) async {
      when(timeService.getCurrent).thenReturn(timer);
      final seen = <MobileActivity>[];
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MobileActivityBuilder(
            omitAudio: omitAudio,
            child: const SizedBox.shrink(),
            builder: (context, activity, child) {
              seen.add(activity);
              return child;
            },
          ),
          theme: DesignSystemTheme.dark(),
          overrides: <Override>[
            audioRecorderControllerProvider.overrideWith(
              () => StubAudioRecorderController(state),
            ),
          ],
        ),
      );
      await tester.pump();
      return seen;
    }

    testWidgets('a timer already running counts on the first frame', (
      tester,
    ) async {
      final seen = await pumpBuilder(tester, timer: timerEntry());

      expect(
        seen.first,
        const MobileActivity(timer: true, recording: false),
      );
    });

    testWidgets('rebuilds when a timer starts or stops, not on every tick', (
      tester,
    ) async {
      final seen = await pumpBuilder(tester);
      expect(seen, [MobileActivity.none]);

      await emitTimer(tester, timerEntry());
      for (var s = 35; s < 38; s++) {
        await emitTimer(tester, timerEntry(elapsed: Duration(seconds: s)));
      }
      await emitTimer(tester, null);

      expect(seen, [
        MobileActivity.none,
        const MobileActivity(timer: true, recording: false),
        MobileActivity.none,
      ]);
    });

    testWidgets('counts a recording by the island rule, and none when audio '
        'is omitted', (tester) async {
      expect(
        (await pumpBuilder(tester, state: recorder())).last,
        const MobileActivity(timer: false, recording: true),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(
        (await pumpBuilder(tester, state: recorder(), omitAudio: true)).last,
        MobileActivity.none,
      );
    });
  });
  group('geometry', () {
    const both = MobileActivity(timer: true, recording: true);
    const timerOnly = MobileActivity(timer: true, recording: false);
    const recordingOnly = MobileActivity(timer: false, recording: true);

    testWidgets('stack height is the capsules plus the gaps between them', (
      tester,
    ) async {
      await pumpIsland(tester, timer: timerEntry());
      final context = islandContext(tester);
      final tokens = context.designTokens;

      expect(MobileActivityIsland.stackHeight(context, MobileActivity.none), 0);
      expect(
        MobileActivityIsland.stackHeight(context, timerOnly),
        tokens.spacing.step8,
      );
      expect(
        MobileActivityIsland.stackHeight(context, both),
        tokens.spacing.step8 * 2 + tokens.spacing.step2,
      );
    });

    testWidgets('docked, the lowest capsule is centred on the launcher row', (
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

    testWidgets('in the row, one capsule claims nothing above the bar and a '
        'stack claims only what rises above it', (tester) async {
      await pumpIsland(tester, timer: timerEntry());
      final context = islandContext(tester);

      expect(
        MobileActivityIsland.heightAboveBar(
          context,
          MobileActivity.none,
          inRow: true,
        ),
        0,
      );
      expect(
        MobileActivityIsland.heightAboveBar(
          context,
          timerOnly,
          inRow: true,
        ),
        0,
      );
      final stackTop =
          MobileActivityIsland.dockedBottom(context) +
          MobileActivityIsland.stackHeight(context, both);
      final above = MobileActivityIsland.heightAboveBar(
        context,
        both,
        inRow: true,
      );
      expect(above, greaterThan(0));
      expect(above, stackTop - MobileNavigationLauncher.barHeight(context));
    });

    testWidgets('floating, the whole stack and its float gap count', (
      tester,
    ) async {
      await pumpIsland(tester, timer: timerEntry());
      final context = islandContext(tester);
      final tokens = context.designTokens;

      expect(MobileActivityIsland.floatGap(context), tokens.spacing.step3);
      expect(
        MobileActivityIsland.heightAboveBar(
          context,
          both,
          inRow: false,
        ),
        MobileActivityIsland.stackHeight(context, both) + tokens.spacing.step3,
      );
      expect(
        MobileActivityIsland.heightAboveBar(
          context,
          MobileActivity.none,
          inRow: false,
        ),
        0,
      );
    });

    testWidgets('width matches the widest capsule as it renders', (
      tester,
    ) async {
      await pumpIsland(tester, state: recorder(), timer: timerEntry());
      final context = islandContext(tester);

      expect(MobileActivityIsland.width(context, MobileActivity.none), 0);
      // The orb is wider than the dot, so the recording sets the stack's
      // width, and the reserve is exactly what paints.
      expect(
        MobileActivityIsland.width(context, recordingOnly),
        greaterThan(MobileActivityIsland.width(context, timerOnly)),
      );
      expect(
        MobileActivityIsland.width(context, both),
        moreOrLessEquals(tester.getSize(island()).width, epsilon: 0.5),
      );

      await pumpIsland(tester, timer: timerEntry());
      expect(
        MobileActivityIsland.width(islandContext(tester), timerOnly),
        moreOrLessEquals(tester.getSize(island()).width, epsilon: 0.5),
      );
    });

    test('activities compare by what runs', () {
      expect(
        const MobileActivity(timer: true, recording: false),
        timerOnly,
      );
      expect(timerOnly.hashCode, isNot(recordingOnly.hashCode));
      expect(timerOnly, isNot(recordingOnly));
      expect(MobileActivity.none.isEmpty, isTrue);
      expect(both.count, 2);
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

  group('the recording capsule', () {
    testWidgets('is a button announcing the recording', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpIsland(tester, state: recorder());
        final data = tester.getSemantics(recordingCapsule()).getSemanticsData();
        expect(data.label, 'Audio recording in progress, 00:03:12');
        expect(data.hasAction(SemanticsAction.tap), isTrue);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('tapping it reopens the recording modal', (tester) async {
      await pumpIsland(tester, state: recorder());

      await tester.tap(recordingCapsule());
      // Bounded pumps: the sheet animates in and its orb never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MobileActivityIsland)),
      );
      // The modal marks itself visible on the shared controller the moment
      // it opens — which is also what hides this half while it is up.
      expect(
        container.read(audioRecorderControllerProvider).modalVisible,
        isTrue,
      );
      final modal = tester.widget<AudioRecordingModalContent>(
        find.byType(AudioRecordingModalContent),
      );
      expect(modal.linkedId, isNull);
      expect(modal.categoryId, isNull);
    });

    testWidgets('a linked recording reopens for its entry and its category', (
      tester,
    ) async {
      final linked = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'entry-1',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
          categoryId: 'cat-1',
        ),
      );
      await pumpIsland(
        tester,
        state: recorder(linkedId: 'entry-1'),
        extraOverrides: [
          entryControllerProvider(
            'entry-1',
          ).overrideWith(() => _StubEntryController(linked)),
        ],
      );
      await tester.pump();

      await tester.tap(recordingCapsule());
      // Bounded pumps: the sheet animates in and its orb never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The category rides along so an uncategorised session cannot inherit
      // an earlier one, and the modal continues the same linked entry.
      final modal = tester.widget<AudioRecordingModalContent>(
        find.byType(AudioRecordingModalContent),
      );
      expect(modal.linkedId, 'entry-1');
      expect(modal.categoryId, 'cat-1');
    });

    testWidgets(
      'a tap while the linked entry is still loading waits for it rather '
      'than reopening without its category',
      (tester) async {
        final completer = Completer<JournalEntity>();
        await pumpIsland(
          tester,
          state: recorder(linkedId: 'entry-1'),
          extraOverrides: [
            entryControllerProvider(
              'entry-1',
            ).overrideWith(() => _PendingEntryController(completer)),
          ],
        );

        await tester.tap(recordingCapsule());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        // Nothing yet: opening now would hand the modal a null category and
        // clear the session's.
        expect(find.byType(AudioRecordingModalContent), findsNothing);

        completer.complete(
          JournalEntity.journalEntry(
            meta: Metadata(
              id: 'entry-1',
              createdAt: now,
              updatedAt: now,
              dateFrom: now,
              dateTo: now,
              categoryId: 'cat-1',
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final modal = tester.widget<AudioRecordingModalContent>(
          find.byType(AudioRecordingModalContent),
        );
        expect(modal.linkedId, 'entry-1');
        expect(modal.categoryId, 'cat-1');
      },
    );

    testWidgets(
      'an entry that lands after the island has gone opens nothing',
      (tester) async {
        // The recording stops (the island unmounts) while its linked entry
        // is still loading: when the entry finally lands there is no
        // surface left to open the modal from, and nothing may throw.
        final completer = Completer<JournalEntity>();
        await pumpIsland(
          tester,
          state: recorder(linkedId: 'entry-1'),
          extraOverrides: [
            entryControllerProvider(
              'entry-1',
            ).overrideWith(() => _PendingEntryController(completer)),
          ],
        );
        await tester.tap(recordingCapsule());
        await tester.pump();

        await tester.pumpWidget(const SizedBox.shrink());
        completer.complete(
          JournalEntity.journalEntry(
            meta: Metadata(
              id: 'entry-1',
              createdAt: now,
              updatedAt: now,
              dateFrom: now,
              dateTo: now,
              categoryId: 'cat-1',
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(AudioRecordingModalContent), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'taps queued behind a loading entry open one sheet, not one per tap',
      (tester) async {
        final completer = Completer<JournalEntity>();
        await pumpIsland(
          tester,
          state: recorder(linkedId: 'entry-1'),
          extraOverrides: [
            entryControllerProvider(
              'entry-1',
            ).overrideWith(() => _PendingEntryController(completer)),
          ],
        );

        // Both taps land while the entry is still loading, so both reopen
        // calls are waiting when it arrives.
        await tester.tap(recordingCapsule());
        await tester.pump();
        await tester.tap(recordingCapsule());
        await tester.pump();

        completer.complete(
          JournalEntity.journalEntry(
            meta: Metadata(
              id: 'entry-1',
              createdAt: now,
              updatedAt: now,
              dateFrom: now,
              dateTo: now,
              categoryId: 'cat-1',
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // The first continuation opened the modal and marked it visible; the
        // second saw that and stood down.
        expect(find.byType(AudioRecordingModalContent), findsOneWidget);
      },
    );

    testWidgets('an assistive-tech tap reopens the modal like a touch does', (
      tester,
    ) async {
      // The Semantics node carries its own onTap for screen readers; the
      // gesture detector underneath is excluded from semantics, so this is
      // the only path an accessibility action takes.
      final handle = tester.ensureSemantics();
      try {
        await pumpIsland(tester, state: recorder());
        final node = tester.getSemantics(recordingCapsule());
        // The binding's own pipeline owner: the root owner has no semantics
        // owner in widget tests.
        // ignore: deprecated_member_use
        tester.binding.pipelineOwner.semanticsOwner!.performAction(
          node.id,
          SemanticsAction.tap,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(AudioRecordingModalContent), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });

    testWidgets(
      'a linked entry that fails to load still reopens, uncategorised',
      (
        tester,
      ) async {
        await pumpIsland(
          tester,
          state: recorder(linkedId: 'entry-1'),
          extraOverrides: [
            entryControllerProvider(
              'entry-1',
            ).overrideWith(_FailingEntryController.new),
          ],
        );

        await tester.tap(recordingCapsule());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // A load failure is a resolved answer, not a loading state: the
        // session is still reachable, just without a category to carry.
        final modal = tester.widget<AudioRecordingModalContent>(
          find.byType(AudioRecordingModalContent),
        );
        expect(modal.linkedId, 'entry-1');
        expect(modal.categoryId, isNull);
      },
    );
  });
}
