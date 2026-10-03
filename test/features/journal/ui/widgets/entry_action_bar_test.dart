import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/entry_action_bar.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/glass_record_button.dart';
import 'package:lotti/logic/create/entry_creation_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/stub_audio_recorder_controller.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

/// Fallback shell so mocktail's `any<BuildContext>()` matcher has a valid
/// prototype value. Never interacted with.
class _FakeBuildContext extends Fake implements BuildContext {}

AudioRecorderState _recorderState({
  required AudioRecorderStatus status,
  String? linkedId,
}) => AudioRecorderState(
  status: status,
  progress: Duration.zero,
  vu: -20,
  dBFS: -160,
  showIndicator: false,
  modalVisible: false,
  linkedId: linkedId,
);

/// The entry under test carries a category, so every creation call can be
/// checked to forward it.
final JournalEntry _entry = testTextEntry.copyWith(
  meta: testTextEntry.meta.copyWith(categoryId: categoryMindfulness.id),
);

void main() {
  late MockEntryCreationService creationService;

  setUpAll(() {
    registerFallbackValue(_FakeBuildContext());
  });

  setUp(() async {
    creationService = MockEntryCreationService();
    await setUpTestGetIt();

    // Default stubs so every affordance completes cleanly even when a test
    // is not asserting on that specific call.
    when(
      () => creationService.createTaskAndOpen(
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => testTask);
    when(
      () => creationService.showCreateEntryModal(
        any(),
        linkedFromId: any(named: 'linkedFromId'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => creationService.showAudioRecordingModal(
        any(),
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) {});
  });

  tearDown(tearDownTestGetIt);

  Future<void> pumpBar(
    WidgetTester tester, {
    JournalEntity? entry,
    AudioRecorderState? recorderState,
    Widget? topSlot,
    MediaQueryData? mediaQueryData,
    List<Override> extraOverrides = const [],
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        Material(
          child: EntryActionBar(
            entry: entry ?? _entry,
            topSlot: topSlot,
          ),
        ),
        mediaQueryData: mediaQueryData,
        overrides: [
          ...extraOverrides,
          entryCreationServiceProvider.overrideWithValue(creationService),
          audioRecorderControllerProvider.overrideWith(
            () => StubAudioRecorderController(recorderState),
          ),
        ],
      ),
    );
    await tester.pump();
  }

  /// The round button the shared record widget renders under the bar's key.
  DsGlassRoundButton micButton(WidgetTester tester) =>
      tester.widget<DsGlassRoundButton>(
        find.descendant(
          of: find.byKey(EntryActionBar.audioKey),
          matching: find.byType(DsGlassRoundButton),
        ),
      );

  group('layout', () {
    testWidgets('renders Add a task, the mic and the plus on one glass strip', (
      tester,
    ) async {
      await pumpBar(tester);

      expect(find.byType(DesignSystemGlassStrip), findsOneWidget);
      expect(find.byKey(EntryActionBar.addTaskKey), findsOneWidget);
      expect(find.byKey(EntryActionBar.audioKey), findsOneWidget);
      expect(find.byKey(EntryActionBar.addKey), findsOneWidget);
      expect(find.byType(DsGlassRoundButton), findsNWidgets(2));
    });

    testWidgets('orders the controls Add a task, mic, plus from the left', (
      tester,
    ) async {
      await pumpBar(tester);

      final addTask = tester.getRect(find.byKey(EntryActionBar.addTaskKey));
      final audio = tester.getRect(find.byKey(EntryActionBar.audioKey));
      final add = tester.getRect(find.byKey(EntryActionBar.addKey));

      expect(addTask.right, lessThan(audio.left));
      expect(audio.right, lessThan(add.left));
      // One row: the three share a vertical centre.
      expect(audio.center.dy, closeTo(addTask.center.dy, 0.01));
      expect(add.center.dy, closeTo(addTask.center.dy, 0.01));
    });

    testWidgets("spaces the controls on the task bar's step4 rhythm", (
      tester,
    ) async {
      await pumpBar(tester);

      final tokens = tester.element(find.byType(EntryActionBar)).designTokens;
      final addTask = tester.getRect(find.byKey(EntryActionBar.addTaskKey));
      final audio = tester.getRect(find.byKey(EntryActionBar.audioKey));
      final add = tester.getRect(find.byKey(EntryActionBar.addKey));

      expect(audio.left - addTask.right, closeTo(tokens.spacing.step4, 0.01));
      expect(add.left - audio.right, closeTo(tokens.spacing.step4, 0.01));
    });

    testWidgets('round buttons and the pill share one 48 px height', (
      tester,
    ) async {
      await pumpBar(tester);

      for (final key in [
        EntryActionBar.addTaskKey,
        EntryActionBar.audioKey,
        EntryActionBar.addKey,
      ]) {
        expect(
          tester.getSize(find.byKey(key)).height,
          DsGlassRoundButton.defaultDiameter,
          reason: '$key',
        );
      }
      expect(
        tester.getSize(find.byKey(EntryActionBar.audioKey)).width,
        DsGlassRoundButton.defaultDiameter,
      );
    });

    testWidgets('renders no activity slot when none is given', (tester) async {
      await pumpBar(tester);

      expect(find.byKey(EntryActionBar.topSlotKey), findsNothing);
    });

    testWidgets('renders an optional activity slot above the action row', (
      tester,
    ) async {
      await pumpBar(
        tester,
        topSlot: const SizedBox(
          key: ValueKey('test-top-slot-content'),
          height: 24,
        ),
      );

      expect(find.byKey(EntryActionBar.topSlotKey), findsOneWidget);
      expect(
        find.byKey(const ValueKey('test-top-slot-content')),
        findsOneWidget,
      );
      expect(
        tester.getRect(find.byKey(EntryActionBar.topSlotKey)).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(EntryActionBar.addTaskKey)).top,
        ),
      );
    });

    testWidgets('pads the row by the bottom safe-area inset', (tester) async {
      await pumpBar(tester);
      final flushHeight = tester.getSize(find.byType(EntryActionBar)).height;

      const inset = 34.0;
      await pumpBar(
        tester,
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(bottom: inset),
        ),
      );

      expect(
        tester.getSize(find.byType(EntryActionBar)).height,
        closeTo(flushHeight + inset, 0.01),
      );
      // The controls sit above the inset, not inside it.
      final bar = tester.getRect(find.byType(EntryActionBar));
      final add = tester.getRect(find.byKey(EntryActionBar.addKey));
      expect(bar.bottom - add.bottom, greaterThanOrEqualTo(inset));
    });

    testWidgets('large text wraps the controls without clipping their '
        'hit targets', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpBar(
        tester,
        mediaQueryData: const MediaQueryData(
          size: Size(320, 844),
          textScaler: TextScaler.linear(2),
        ),
      );

      final bounds = tester.getRect(find.byType(EntryActionBar));
      for (final key in [
        EntryActionBar.addTaskKey,
        EntryActionBar.audioKey,
        EntryActionBar.addKey,
      ]) {
        final control = tester.getRect(find.byKey(key));
        expect(control.left, greaterThanOrEqualTo(bounds.left));
        expect(control.right, lessThanOrEqualTo(bounds.right));
        expect(control.top, greaterThanOrEqualTo(bounds.top));
        expect(control.bottom, lessThanOrEqualTo(bounds.bottom));
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('Add a task', () {
    testWidgets("is the bar's filled primary: accent fill, on-accent ink, "
        'the add-task glyph and the short verb', (tester) async {
      await pumpBar(tester);

      final tokens = tester.element(find.byType(EntryActionBar)).designTokens;
      final pill = tester.widget<DsGlassPill>(
        find.byKey(EntryActionBar.addTaskKey),
      );
      expect(pill.fillColor, tokens.colors.interactive.enabled);
      expect(pill.foregroundColor, tokens.colors.text.onInteractiveAlert);
      expect(pill.icon, LottiIcons.addTask);
      expect(find.text('Add a task'), findsOneWidget);
      // The mic and the plus stay translucent, so the pill is the strip's
      // only filled shape.
      expect(micButton(tester).backgroundColor, isNull);
      expect(
        tester
            .widget<DsGlassRoundButton>(find.byKey(EntryActionBar.addKey))
            .backgroundColor,
        isNull,
      );
    });

    testWidgets(
      'its accessible name contains the visible label and adds the '
      'relationship',
      (tester) async {
        await pumpBar(tester);

        expect(
          find.bySemanticsLabel('Add a task linked to this entry'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping runs the create-and-open journey with the entry and its '
      'category',
      (tester) async {
        await pumpBar(tester);

        await tester.tap(find.byKey(EntryActionBar.addTaskKey));
        await tester.pump();

        verify(
          () => creationService.createTaskAndOpen(
            linkedId: _entry.meta.id,
            categoryId: categoryMindfulness.id,
          ),
        ).called(1);
      },
    );

    testWidgets('forwards a null category when the entry has none', (
      tester,
    ) async {
      await pumpBar(tester, entry: testTextEntry);

      await tester.tap(find.byKey(EntryActionBar.addTaskKey));
      await tester.pump();

      verify(
        () => creationService.createTaskAndOpen(
          linkedId: testTextEntry.meta.id,
          // ignore: avoid_redundant_argument_values
          categoryId: null,
        ),
      ).called(1);
    });
  });

  group('record audio', () {
    testWidgets('is the shared record button, scoped to this entry', (
      tester,
    ) async {
      await pumpBar(tester);

      final record = tester.widget<GlassRecordButton>(
        find.byKey(EntryActionBar.audioKey),
      );
      expect(record.linkedId, _entry.meta.id);
      // Idle: the accent ring and glyph the task bar's mic wears.
      final tokens = tester.element(find.byType(EntryActionBar)).designTokens;
      expect(micButton(tester).outlineColor, tokens.colors.interactive.enabled);
      expect(find.bySemanticsLabel('Record a voice note'), findsOneWidget);
    });

    testWidgets('lights up for a recording linked to this entry', (
      tester,
    ) async {
      await pumpBar(
        tester,
        recorderState: _recorderState(
          status: AudioRecorderStatus.recording,
          linkedId: _entry.meta.id,
        ),
      );

      final tokens = tester.element(find.byType(EntryActionBar)).designTokens;
      expect(
        micButton(tester).backgroundColor,
        tokens.colors.alert.error.defaultColor,
      );
      expect(
        find.bySemanticsLabel('Audio recording in progress'),
        findsOneWidget,
      );
    });

    testWidgets('stays idle for a recording linked to another entry', (
      tester,
    ) async {
      await pumpBar(
        tester,
        recorderState: _recorderState(
          status: AudioRecorderStatus.recording,
          linkedId: 'some-other-entry',
        ),
      );

      expect(micButton(tester).backgroundColor, isNull);
      expect(find.bySemanticsLabel('Record a voice note'), findsOneWidget);
    });

    testWidgets('tapping opens the recording modal linked to the entry', (
      tester,
    ) async {
      await pumpBar(tester);

      await tester.tap(find.byKey(EntryActionBar.audioKey));
      await tester.pump();

      verify(
        () => creationService.showAudioRecordingModal(
          any(),
          linkedId: _entry.meta.id,
          categoryId: categoryMindfulness.id,
        ),
      ).called(1);
    });
  });

  group('plus', () {
    testWidgets('is a quiet glass circle wearing the plus, named for the '
        'linked entry it adds', (tester) async {
      await pumpBar(tester);

      final add = tester.widget<DsGlassRoundButton>(
        find.byKey(EntryActionBar.addKey),
      );
      expect(add.icon, LottiIcons.add);
      expect(add.backgroundColor, isNull);
      expect(add.outlineColor, isNull);
      expect(add.iconColor, isNull);
      expect(find.bySemanticsLabel('Add linked entry'), findsOneWidget);
    });

    testWidgets('tapping opens the Add sheet linked to the entry, as the '
        'floating button did', (tester) async {
      await pumpBar(tester);

      await tester.tap(find.byKey(EntryActionBar.addKey));
      await tester.pump();

      verify(
        () => creationService.showCreateEntryModal(
          any(),
          linkedFromId: _entry.meta.id,
          categoryId: categoryMindfulness.id,
        ),
      ).called(1);
      verifyNever(
        () => creationService.createTaskAndOpen(
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      );
    });
  });
}
