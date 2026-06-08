import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_orb.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;
import 'package:lotti/widgets/misc/sidebar_audio_recording_section.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

class _FakeAudioRecorderController extends AudioRecorderController {
  _FakeAudioRecorderController(this._initial);

  final AudioRecorderState _initial;
  int stopCalls = 0;
  int stopRealtimeCalls = 0;
  final List<String?> setCategoryIdCalls = <String?>[];

  @override
  AudioRecorderState build() => _initial;

  @override
  void setCategoryId(String? categoryId) {
    setCategoryIdCalls.add(categoryId);
    super.setCategoryId(categoryId);
  }

  @override
  Future<String?> stop() async {
    stopCalls += 1;
    state = state.copyWith(status: AudioRecorderStatus.stopped);
    return 'audio-entry';
  }

  @override
  Future<String?> stopRealtime() async {
    stopRealtimeCalls += 1;
    state = state.copyWith(status: AudioRecorderStatus.stopped);
    return 'realtime-audio-entry';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAudioRecorderController controller;

  AudioRecorderState recorderState({
    AudioRecorderStatus status = AudioRecorderStatus.recording,
    Duration progress = const Duration(minutes: 7, seconds: 40),
    double dBFS = -18,
    bool modalVisible = false,
    String? linkedId,
    bool isRealtimeMode = false,
  }) {
    return AudioRecorderState(
      status: status,
      progress: progress,
      vu: -6,
      dBFS: dBFS,
      showIndicator: true,
      modalVisible: modalVisible,
      linkedId: linkedId,
      isRealtimeMode: isRealtimeMode,
    );
  }

  Task makeTask(String id, {String title = 'Implement recording orb'}) {
    final now = DateTime(2026, 5, 22, 14);
    return Task(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
        categoryId: 'category-1',
      ),
      data: TaskData(
        title: title,
        dateFrom: now,
        dateTo: now,
        status: TaskStatus.open(
          id: 'status-id',
          createdAt: now,
          utcOffset: 0,
        ),
        statusHistory: const [],
      ),
      entryText: const EntryText(plainText: 'task fallback text'),
    );
  }

  JournalEntry makeEntry(
    String id, {
    String? plainText = 'standalone voice memo',
    String? categoryId = 'category-9',
  }) {
    final now = DateTime(2026, 5, 22, 14);
    return JournalEntry(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
        categoryId: categoryId,
      ),
      entryText: plainText == null ? null : EntryText(plainText: plainText),
    );
  }

  Future<void> pumpSection(
    WidgetTester tester,
    AudioRecorderState state, {
    JournalEntity? linkedEntry,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const SidebarAudioRecordingSection(),
        overrides: [
          audioRecorderControllerProvider.overrideWith(() {
            return controller = _FakeAudioRecorderController(state);
          }),
          if (state.linkedId != null && linkedEntry != null)
            sidebarAudioRecordingLinkedEntryProvider(
              state.linkedId!,
            ).overrideWith((ref) => linkedEntry),
        ],
      ),
    );
    await tester.pump();
  }

  BoxDecoration frameDecoration(WidgetTester tester) {
    return tester
            .widget<DecoratedBox>(
              find.byKey(const Key('sidebar_audio_recording_card_frame')),
            )
            .decoration
        as BoxDecoration;
  }

  testWidgets('collapses when the recorder is not active', (tester) async {
    await pumpSection(
      tester,
      recorderState(status: AudioRecorderStatus.stopped),
    );
    await tester.pump(SidebarAudioRecordingSection.animationDuration);

    expect(find.byKey(const Key('sidebar_audio_recording_card')), findsNothing);
    expect(find.byType(AudioRecordingOrb), findsNothing);
    expect(find.byIcon(Icons.stop_rounded), findsNothing);
  });

  testWidgets('renders linked task title, duration, orb, and stop button', (
    tester,
  ) async {
    await pumpSection(
      tester,
      recorderState(
        linkedId: 'task-1',
        dBFS: -12,
        progress: const Duration(hours: 1, minutes: 2, seconds: 3),
      ),
      linkedEntry: makeTask('task-1', title: 'Urgent voice note'),
    );
    await tester.pump(SidebarAudioRecordingSection.animationDuration);

    expect(find.text('Urgent voice note'), findsOneWidget);
    expect(find.text('01:02:03'), findsOneWidget);
    expect(find.byType(AudioRecordingOrb), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

    final orb = tester.widget<AudioRecordingOrb>(
      find.byType(AudioRecordingOrb),
    );
    expect(orb.dBFS, -12);
    expect(orb.size, dsTokensLight.spacing.step7);

    final material = tester.widget<Material>(
      find.byKey(const Key('sidebar_audio_recording_card')),
    );
    expect(material.borderRadius, BorderRadius.circular(dsTokensLight.radii.s));

    final frame = frameDecoration(tester);
    expect(frame.borderRadius, BorderRadius.circular(dsTokensLight.radii.s));
  });

  testWidgets('intensifies the card frame from live dBFS input', (
    tester,
  ) async {
    await pumpSection(tester, recorderState(dBFS: -60));
    final quietFrame = frameDecoration(tester);
    final quietBorder = quietFrame.border! as Border;
    final quietShadow = quietFrame.boxShadow!.single;

    controller.state = controller.state.copyWith(dBFS: -12);
    await tester.pump();
    final loudFrame = frameDecoration(tester);
    final loudBorder = loudFrame.border! as Border;
    final loudShadow = loudFrame.boxShadow!.single;

    expect(loudBorder.top.width, greaterThan(quietBorder.top.width));
    expect(quietBorder.top.width, lessThan(dsTokensLight.spacing.step1 / 2));
    expect(
      loudBorder.top.width,
      greaterThan(dsTokensLight.spacing.step1 * 0.6),
    );
    expect(
      loudBorder.top.width,
      lessThan(dsTokensLight.spacing.step1 * 0.75),
    );
    controller.state = controller.state.copyWith(dBFS: 0);
    await tester.pump();
    final fullScaleFrame = frameDecoration(tester);
    final fullScaleBorder = fullScaleFrame.border! as Border;

    expect(fullScaleBorder.top.width, dsTokensLight.spacing.step1);
    expect(loudBorder.top.color.a, greaterThan(quietBorder.top.color.a));
    expect(loudShadow.blurRadius, greaterThan(quietShadow.blurRadius));
    expect(loudShadow.spreadRadius, greaterThan(quietShadow.spreadRadius));
    expect(loudFrame.color!.a, greaterThan(quietFrame.color!.a));
  });

  testWidgets('keeps the card frame red when input is clipping', (
    tester,
  ) async {
    await pumpSection(tester, recorderState(dBFS: -1));

    final frame = frameDecoration(tester);
    final border = frame.border! as Border;

    expect(
      border.top.color.withValues(alpha: 1),
      dsTokensLight.colors.alert.error.defaultColor,
    );
  });

  testWidgets('time text uses tabular figure features', (tester) async {
    await pumpSection(tester, recorderState());

    final text = tester.widget<Text>(find.text('00:07:40'));
    final features = text.style?.fontFeatures ?? const <FontFeature>[];

    expect(features, containsAll(numericBadgeFontFeatures));
  });

  testWidgets('stop button stops a standard recording without opening modal', (
    tester,
  ) async {
    await pumpSection(tester, recorderState());

    await tester.tap(find.byIcon(Icons.stop_rounded));
    await tester.pump();

    expect(controller.stopCalls, 1);
    expect(controller.stopRealtimeCalls, 0);
  });

  testWidgets('stop button uses realtime stop for realtime sessions', (
    tester,
  ) async {
    await pumpSection(
      tester,
      recorderState(isRealtimeMode: true),
    );

    await tester.tap(find.byIcon(Icons.stop_rounded));
    await tester.pump();

    expect(controller.stopCalls, 0);
    expect(controller.stopRealtimeCalls, 1);
  });

  testWidgets('uses localized fallback title when there is no linked entry', (
    tester,
  ) async {
    await pumpSection(tester, recorderState());

    expect(find.text('Audio recording in progress'), findsOneWidget);
  });

  testWidgets(
    'shows linked non-task entry text as the title',
    (tester) async {
      await pumpSection(
        tester,
        recorderState(linkedId: 'entry-1'),
        linkedEntry: makeEntry('entry-1', plainText: '  Morning thoughts  '),
      );
      await tester.pump(SidebarAudioRecordingSection.animationDuration);

      // The non-Task branch falls through to entryText.plainText (trimmed).
      expect(find.text('Morning thoughts'), findsOneWidget);
      expect(find.text('Audio recording in progress'), findsNothing);
    },
  );

  testWidgets(
    'falls back to localized title when linked entry has no text',
    (tester) async {
      await pumpSection(
        tester,
        recorderState(linkedId: 'entry-blank'),
        linkedEntry: makeEntry('entry-blank', plainText: '   '),
      );
      await tester.pump(SidebarAudioRecordingSection.animationDuration);

      // Whitespace-only text is not a usable title, so the fallback wins.
      expect(find.text('Audio recording in progress'), findsOneWidget);
    },
  );

  group('linked entry provider + modal tap', () {
    late MockJournalDb mockJournalDb;

    // Use the centralized GetIt harness instead of inline register/reset
    // boilerplate; it guarantees paired cleanup via tearDownTestGetIt and
    // provides the JournalDb mock the FutureProvider resolves through get_it.
    setUp(() async {
      final mocks = await setUpTestGetIt();
      mockJournalDb = mocks.journalDb;
    });

    tearDown(tearDownTestGetIt);

    Future<void> pumpWithRealProvider(
      WidgetTester tester,
      AudioRecorderState state,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SidebarAudioRecordingSection(),
          overrides: [
            audioRecorderControllerProvider.overrideWith(() {
              return controller = _FakeAudioRecorderController(state);
            }),
          ],
        ),
      );
      await tester.pump();
    }

    testWidgets(
      'resolves the linked entry title via JournalDb from get_it',
      (tester) async {
        when(
          () => mockJournalDb.journalEntityById('entry-db'),
        ).thenAnswer((_) async => makeEntry('entry-db', plainText: 'From DB'));

        await pumpWithRealProvider(
          tester,
          recorderState(linkedId: 'entry-db'),
        );
        // Let the FutureProvider body (getIt<JournalDb>().journalEntityById)
        // resolve and rebuild the card with the fetched title.
        await tester.pump();
        await tester.pump(SidebarAudioRecordingSection.animationDuration);

        verify(() => mockJournalDb.journalEntityById('entry-db')).called(1);
        expect(find.text('From DB'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the card opens the modal and forwards the linked categoryId',
      (tester) async {
        when(() => mockJournalDb.journalEntityById('entry-tap')).thenAnswer(
          (_) async =>
              makeEntry('entry-tap', plainText: 'Tap me', categoryId: 'cat-42'),
        );

        await pumpWithRealProvider(
          tester,
          recorderState(linkedId: 'entry-tap'),
        );
        await tester.pump();
        await tester.pump(SidebarAudioRecordingSection.animationDuration);

        expect(controller.state.modalVisible, isFalse);

        await tester.tap(
          find.byKey(const Key('sidebar_audio_recording_card')),
        );
        await tester.pump();

        // show() sets the modal visible and forwards the resolved categoryId.
        expect(controller.state.modalVisible, isTrue);
        expect(controller.setCategoryIdCalls, contains('cat-42'));
      },
    );
  });
}
