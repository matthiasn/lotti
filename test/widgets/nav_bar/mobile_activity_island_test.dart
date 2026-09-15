import 'dart:async';

import 'package:flutter/rendering.dart' show SemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/nav_bar/mobile_activity_island.dart';
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

  Finder capsule() => find.byKey(MobileActivityIsland.capsuleKey);
  Finder timerHalf() => find.byKey(MobileActivityIsland.timerKey);
  Finder recordingHalf() => find.byKey(MobileActivityIsland.recordingKey);
  Finder divider() => find.byKey(MobileActivityIsland.dividerKey);

  DsTokens tokensOf(WidgetTester tester) =>
      tester.element(find.byType(MobileActivityIsland)).designTokens;

  BuildContext islandContext(WidgetTester tester) =>
      tester.element(find.byType(MobileActivityIsland));

  /// A narrow phone at the largest accessibility text scale — the case
  /// where two elapsed times stop sharing one capsule.
  const narrowLargeText = MediaQueryData(
    size: Size(320, 700),
    textScaler: TextScaler.linear(3),
  );

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

      expect(capsule(), findsNothing);
      expect(find.byType(DsGlassChipSurface), findsNothing);
    });

    testWidgets('a timer already running shows on the first frame', (
      tester,
    ) async {
      // Seeded from the service's current entry: without it the island
      // waited for the stream's next tick, a second of nothing.
      await pumpIsland(tester, timer: timerEntry());

      expect(capsule(), findsOneWidget);
      expect(find.text('00:12:34'), findsOneWidget);
    });

    testWidgets('appears when a timer starts and leaves when it stops', (
      tester,
    ) async {
      await pumpIsland(tester);
      expect(capsule(), findsNothing);

      await emitTimer(tester, timerEntry());
      expect(capsule(), findsOneWidget);

      await emitTimer(tester, null);
      expect(capsule(), findsNothing);
    });

    testWidgets('a recording with its modal open is not shown', (
      tester,
    ) async {
      await pumpIsland(tester, state: recorder(modalVisible: true));

      expect(capsule(), findsNothing);
    });

    testWidgets('a paused session stays on the island with its elapsed time', (
      tester,
    ) async {
      await pumpIsland(
        tester,
        state: recorder(status: AudioRecorderStatus.paused),
      );

      expect(recordingHalf(), findsOneWidget);
      expect(find.text('00:03:12'), findsOneWidget);
    });

    testWidgets('a build that omits audio drops only the recording half', (
      tester,
    ) async {
      await pumpIsland(tester, state: recorder(), omitAudio: true);
      expect(
        capsule(),
        findsNothing,
        reason: 'a recording alone has nothing left to show',
      );

      await pumpIsland(
        tester,
        state: recorder(),
        timer: timerEntry(),
        omitAudio: true,
      );
      expect(timerHalf(), findsOneWidget);
      expect(recordingHalf(), findsNothing);
      expect(divider(), findsNothing);
    });

    testWidgets('a broken recorder backend never takes the timer down', (
      tester,
    ) async {
      await pumpIsland(
        tester,
        timer: timerEntry(),
        controller: _BrokenAudioRecorderController.new,
      );

      expect(timerHalf(), findsOneWidget);
      expect(recordingHalf(), findsNothing);
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
      expect(recordingHalf(), findsNothing);
      expect(divider(), findsNothing);

      final dot = tester.widget<Container>(
        find
            .descendant(of: timerHalf(), matching: find.byType(Container))
            .first,
      );
      final decoration = dot.decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, tokens.colors.alert.error.defaultColor);
      expect(tester.getSize(find.byWidget(dot)).width, tokens.spacing.step4);
    });

    testWidgets('a recording alone: live orb and elapsed time, no dot', (
      tester,
    ) async {
      await pumpIsland(tester, state: recorder());
      final tokens = tokensOf(tester);

      expect(find.text('00:03:12'), findsOneWidget);
      expect(timerHalf(), findsNothing);
      expect(divider(), findsNothing);
      final orb = tester.widget<AudioRecordingOrb>(
        find.byType(AudioRecordingOrb),
      );
      expect(orb.dBFS, -18);
      expect(orb.size, tokens.spacing.step6);
    });

    testWidgets('both: the timer leads, a hairline, then the recording', (
      tester,
    ) async {
      await pumpIsland(tester, state: recorder(), timer: timerEntry());
      final tokens = tokensOf(tester);

      expect(capsule(), findsOneWidget);
      expect(divider(), findsOneWidget);
      final timerX = tester.getTopLeft(timerHalf()).dx;
      final dividerX = tester.getTopLeft(divider()).dx;
      final recordingX = tester.getTopLeft(recordingHalf()).dx;
      expect(timerX, lessThan(dividerX));
      expect(dividerX, lessThan(recordingX));

      final rule = tester.getSize(divider());
      expect(rule.width, BorderWidths.hairline);
      expect(rule.height, tokens.spacing.step5);
      expect(
        tester
            .widget<ColoredBox>(
              find.descendant(of: divider(), matching: find.byType(ColoredBox)),
            )
            .color,
        tokens.colors.decorative.level01,
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

      final container = tester.widget<Container>(capsule());
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
      final container = tester.widget<Container>(capsule());
      expect(
        (container.decoration! as BoxDecoration).color,
        dsGlassChipFill(tokens),
      );
      expect(
        tester.widget<Text>(find.text('00:12:34')).style!.color,
        tokens.colors.text.highEmphasis,
      );
    });

    testWidgets('is one capsule height tall and each half fills it', (
      tester,
    ) async {
      await pumpIsland(tester, state: recorder(), timer: timerEntry());
      final tokens = tokensOf(tester);

      expect(tester.getSize(capsule()).height, tokens.spacing.step8);
      expect(
        MobileActivityIsland.capsuleHeight(
          tester.element(find.byType(MobileActivityIsland)),
        ),
        tokens.spacing.step8,
      );
      // Stretched halves: the tap target is the capsule's height, not the
      // text line inside it.
      expect(tester.getSize(timerHalf()).height, tokens.spacing.step8);
      expect(tester.getSize(recordingHalf()).height, tokens.spacing.step8);
    });

    testWidgets('the halves meet at the hairline and reach both ends', (
      tester,
    ) async {
      await pumpIsland(tester, state: recorder(), timer: timerEntry());

      // The capsule's insets and the air around the rule belong to the
      // halves, so a tap anywhere on the pill lands on one of them.
      final pill = tester.getRect(capsule());
      final timerRect = tester.getRect(timerHalf());
      final ruleRect = tester.getRect(divider());
      final recordingRect = tester.getRect(recordingHalf());
      expect(timerRect.left, moreOrLessEquals(pill.left, epsilon: 0.5));
      expect(timerRect.right, moreOrLessEquals(ruleRect.left, epsilon: 0.5));
      expect(
        recordingRect.left,
        moreOrLessEquals(ruleRect.right, epsilon: 0.5),
      );
      expect(recordingRect.right, moreOrLessEquals(pill.right, epsilon: 0.5));
    });

    testWidgets('a lone half spans the whole pill', (tester) async {
      await pumpIsland(tester, timer: timerEntry());
      expect(tester.getRect(timerHalf()), tester.getRect(capsule()));

      await pumpIsland(tester, state: recorder());
      expect(tester.getRect(recordingHalf()), tester.getRect(capsule()));
    });

    testWidgets(
      'grows with the system text scale so digits are never clipped',
      (
        tester,
      ) async {
        // A window wide enough that width pressure plays no part (at 3× two
        // elapsed times outgrow even a large phone), so only the height is
        // under test. At 3× the subtitle2 line is 60 px — half again the
        // default capsule — and the launcher beside it grows the same way.
        const wideLargeText = MediaQueryData(
          size: Size(900, 932),
          textScaler: TextScaler.linear(3),
        );
        await pumpIsland(
          tester,
          state: recorder(),
          timer: timerEntry(),
          mediaQueryData: wideLargeText,
        );
        final context = islandContext(tester);
        final tokens = context.designTokens;

        final expected =
            wideLargeText.textScaler
                .scale(tokens.typography.lineHeight.subtitle2)
                .ceilToDouble() +
            tokens.spacing.step2 * 2;
        expect(expected, greaterThan(tokens.spacing.step8));
        expect(MobileActivityIsland.capsuleHeight(context), expected);
        expect(tester.getSize(capsule()).height, expected);
        // The reserved estate follows the grown capsule, so pages still pad
        // by exactly what renders.
        expect(
          MobileActivityIsland.reservedHeight(context),
          expected + tokens.spacing.step3,
        );
        // And the digits sit fully inside the pill — nothing for the clip to
        // cut.
        final pill = tester.getRect(capsule());
        for (final digits in ['00:12:34', '00:03:12']) {
          final rect = tester.getRect(find.text(digits));
          expect(rect.top, greaterThanOrEqualTo(pill.top), reason: digits);
          expect(rect.bottom, lessThanOrEqualTo(pill.bottom), reason: digits);
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('sits centred in the width it is given', (tester) async {
      await pumpIsland(tester, timer: timerEntry());

      final island = tester.getRect(find.byType(MobileActivityIsland));
      expect(
        tester.getCenter(capsule()).dx,
        moreOrLessEquals(island.center.dx, epsilon: 0.5),
      );
    });

    testWidgets('reserves its height plus the gap it keeps above the bar', (
      tester,
    ) async {
      await pumpIsland(tester, timer: timerEntry());
      final context = tester.element(find.byType(MobileActivityIsland));
      final tokens = context.designTokens;

      expect(
        MobileActivityIsland.gapAboveBar(context),
        tokens.spacing.step3,
      );
      expect(
        MobileActivityIsland.reservedHeight(context),
        tokens.spacing.step8 + tokens.spacing.step3,
      );
    });
  });

  group('width pressure', () {
    testWidgets('both halves fit with their digits at the default scale', (
      tester,
    ) async {
      await pumpIsland(tester, state: recorder(), timer: timerEntry());

      expect(
        MobileActivityIsland.bothHalvesFit(
          islandContext(tester),
          timerElapsed: '00:12:34',
          recordingElapsed: '00:03:12',
        ),
        isTrue,
      );
      expect(find.text('00:12:34'), findsOneWidget);
      expect(find.text('00:03:12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'large text on a narrow phone drops the recording to its orb and '
      'keeps the timer digits',
      (tester) async {
        await pumpIsland(
          tester,
          state: recorder(),
          timer: timerEntry(),
          mediaQueryData: narrowLargeText,
        );

        expect(
          MobileActivityIsland.bothHalvesFit(
            islandContext(tester),
            timerElapsed: '00:12:34',
            recordingElapsed: '00:03:12',
          ),
          isFalse,
        );
        // The timer's digits are the payload with no glyph-only reading;
        // the orb still says "live" on its own.
        expect(find.text('00:12:34'), findsOneWidget);
        expect(find.text('00:03:12'), findsNothing);
        expect(find.byType(AudioRecordingOrb), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(capsule()).width,
          lessThanOrEqualTo(narrowLargeText.size.width),
        );
      },
    );

    testWidgets('a recording without its digits still announces its time', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpIsland(
          tester,
          state: recorder(),
          timer: timerEntry(),
          mediaQueryData: narrowLargeText,
        );
        expect(
          tester.getSemantics(recordingHalf()).getSemanticsData().label,
          'Audio recording in progress, 00:03:12',
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('a lone half never gives up its digits', (tester) async {
      await pumpIsland(
        tester,
        state: recorder(),
        mediaQueryData: narrowLargeText,
      );
      expect(find.text('00:03:12'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await pumpIsland(
        tester,
        timer: timerEntry(),
        mediaQueryData: narrowLargeText,
      );
      expect(find.text('00:12:34'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'where even the degraded content cannot fit, it shrinks rather than '
      'clips a digit',
      (tester) async {
        // Narrower than any phone the app targets, at the largest scale: the
        // measured rule has already given everything it can, so the last
        // resort has to hold on its own.
        const impossible = MediaQueryData(
          size: Size(200, 600),
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
        expect(
          tester.getRect(capsule()).width,
          lessThanOrEqualTo(impossible.size.width),
        );
        // Shrunk, not cut: the digits' painted box is narrower than their
        // natural width, which is what "never truncate a number" buys here.
        final fitted = tester.widget<FittedBox>(
          find.descendant(of: capsule(), matching: find.byType(FittedBox)),
        );
        expect(fitted.fit, BoxFit.scaleDown);
      },
    );
  });

  group('the timer half', () {
    testWidgets('is a button that names itself and its elapsed time', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpIsland(tester, timer: timerEntry());
        final data = tester.getSemantics(timerHalf()).getSemanticsData();
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

      await tester.tap(timerHalf());
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

      await tester.tap(timerHalf());
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

      await tester.tap(timerHalf());
      await tester.pump();

      verify(
        () => navService.beamToNamed(
          '/journal/timer-9',
          data: any(named: 'data'),
        ),
      ).called(1);
    });
  });

  group('the recording half', () {
    testWidgets('is a button announcing the recording', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpIsland(tester, state: recorder());
        final data = tester.getSemantics(recordingHalf()).getSemanticsData();
        expect(data.label, 'Audio recording in progress, 00:03:12');
        expect(data.hasAction(SemanticsAction.tap), isTrue);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('tapping it reopens the recording modal', (tester) async {
      await pumpIsland(tester, state: recorder());

      await tester.tap(recordingHalf());
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

      await tester.tap(recordingHalf());
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

        await tester.tap(recordingHalf());
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
        await tester.tap(recordingHalf());
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
        await tester.tap(recordingHalf());
        await tester.pump();
        await tester.tap(recordingHalf());
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
        final node = tester.getSemantics(recordingHalf());
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

        await tester.tap(recordingHalf());
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
