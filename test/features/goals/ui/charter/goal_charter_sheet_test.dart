import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/agents/ui/chat/waveform_bars.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/charter/goal_charter_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/ui/evolution/widgets/evolution_recorder_test_utils.dart';

void main() {
  late MockGoalRepository repository;
  late MockDomainLogger logger;

  final existing = testTextEntryNoGeo.copyWith(
    meta: testTextEntryNoGeo.meta.copyWith(id: 'charter-1'),
    entryText: const EntryText(plainText: 'This goal is my journal.'),
  );

  setUpAll(registerAllFallbackValues);

  setUp(() {
    repository = MockGoalRepository();
    logger = MockDomainLogger();
  });

  /// Pumps a button that opens the sheet, then opens it — so a save that
  /// closes the sheet is seen closing.
  Future<void> openSheet(
    WidgetTester tester, {
    JournalEntry? entry,
    ChatRecorderController Function()? recorder,
    bool journalStack = true,
  }) async {
    final overrides = <Override>[
      goalRepositoryProvider.overrideWithValue(
        journalStack ? repository : null,
      ),
      domainLoggerProvider.overrideWithValue(logger),
      chatRecorderControllerProvider.overrideWith(
        recorder ?? TranscriptEmittingController.new,
      ),
    ];
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => DesignSystemButton(
            label: 'open',
            onPressed: () => showGoalCharterSheet(
              context: context,
              agentId: 'agent-1',
              entry: entry,
            ),
          ),
        ),
        overrides: overrides,
      ),
    );
    await tester.tap(find.text('open'));
    // A fixed pump, not pumpAndSettle: the transcribing spinner never
    // settles. Half a second covers the sheet's entrance.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  DesignSystemButton button(WidgetTester tester, String key) =>
      tester.widget<DesignSystemButton>(find.byKey(ValueKey(key)));

  group('writing', () {
    testWidgets('a new entry is saved for this goal and the sheet closes', (
      tester,
    ) async {
      when(
        () => repository.createCharterEntry(
          agentId: any(named: 'agentId'),
          text: any(named: 'text'),
        ),
      ).thenAnswer((_) async => existing);
      await openSheet(tester);

      expect(find.text('About this goal'), findsOneWidget);
      expect(button(tester, 'goal-charter-save').onPressed, isNull);
      expect(find.byKey(const ValueKey('goal-charter-delete')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('goal-charter-text')),
        'Ask me one guided question each morning.',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('goal-charter-save')));
      await tester.pumpAndSettle();

      verify(
        () => repository.createCharterEntry(
          agentId: 'agent-1',
          text: 'Ask me one guided question each morning.',
        ),
      ).called(1);
      expect(find.byType(GoalCharterForm), findsNothing);
    });

    testWidgets('⌘/Ctrl+Enter saves, as the button does', (tester) async {
      when(
        () => repository.createCharterEntry(
          agentId: any(named: 'agentId'),
          text: any(named: 'text'),
        ),
      ).thenAnswer((_) async => existing);
      await openSheet(tester);

      await tester.enterText(
        find.byKey(const ValueKey('goal-charter-text')),
        'Coach me gently.',
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      verify(
        () => repository.createCharterEntry(
          agentId: 'agent-1',
          text: 'Coach me gently.',
        ),
      ).called(1);
      expect(find.byType(GoalCharterForm), findsNothing);
    });

    testWidgets('Cancel closes the sheet and writes nothing', (tester) async {
      await openSheet(tester, entry: existing);

      await tester.tap(find.byKey(const ValueKey('goal-charter-cancel')));
      await tester.pumpAndSettle();

      expect(find.byType(GoalCharterForm), findsNothing);
      verifyZeroInteractions(repository);
    });

    testWidgets('without a journal stack, save and delete say they could not '
        'and keep the sheet open', (tester) async {
      await openSheet(tester, entry: existing, journalStack: false);

      await tester.tap(find.byKey(const ValueKey('goal-charter-save')));
      await tester.pump();
      expect(find.text("That didn't save. Try again."), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('goal-charter-delete')));
      await tester.pump();
      final context = tester.element(find.byType(GoalCharterForm));
      expect(find.text(context.messages.journalDeleteFailed), findsOneWidget);
      expect(find.byType(GoalCharterForm), findsOneWidget);
    });

    testWidgets('blank words cannot be saved', (tester) async {
      await openSheet(tester);

      await tester.enterText(
        find.byKey(const ValueKey('goal-charter-text')),
        '   ',
      );
      await tester.pump();

      expect(button(tester, 'goal-charter-save').onPressed, isNull);
    });

    testWidgets("an edit opens on the entry's words and saves new ones", (
      tester,
    ) async {
      when(
        () => repository.updateCharterEntry(
          any(),
          agentId: any(named: 'agentId'),
          text: any(named: 'text'),
        ),
      ).thenAnswer((_) async => true);
      await openSheet(tester, entry: existing);

      expect(find.text('This goal is my journal.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('goal-charter-text')),
        'This goal is my season journal.',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('goal-charter-save')));
      await tester.pumpAndSettle();

      verify(
        () => repository.updateCharterEntry(
          existing,
          agentId: 'agent-1',
          text: 'This goal is my season journal.',
        ),
      ).called(1);
      expect(find.byType(GoalCharterForm), findsNothing);
    });

    testWidgets('an entry can be deleted from its sheet', (tester) async {
      when(
        () => repository.deleteCharterEntry(
          any(),
          agentId: any(named: 'agentId'),
        ),
      ).thenAnswer((_) async => true);
      await openSheet(tester, entry: existing);

      await tester.tap(find.byKey(const ValueKey('goal-charter-delete')));
      await tester.pumpAndSettle();

      verify(
        () => repository.deleteCharterEntry(existing, agentId: 'agent-1'),
      ).called(1);
      expect(find.byType(GoalCharterForm), findsNothing);
    });

    testWidgets('a refused save keeps the sheet open on the words, with the '
        'reason under them', (tester) async {
      when(
        () => repository.createCharterEntry(
          agentId: any(named: 'agentId'),
          text: any(named: 'text'),
        ),
      ).thenAnswer((_) async => null);
      await openSheet(tester);

      await tester.enterText(
        find.byKey(const ValueKey('goal-charter-text')),
        'Coach me gently.',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('goal-charter-save')));
      await tester.pumpAndSettle();

      expect(find.byType(GoalCharterForm), findsOneWidget);
      expect(find.text('Coach me gently.'), findsOneWidget);
      expect(find.text("That didn't save. Try again."), findsOneWidget);
    });

    testWidgets('a save that throws is logged with its trace and reported '
        'under the field', (tester) async {
      when(
        () => repository.createCharterEntry(
          agentId: any(named: 'agentId'),
          text: any(named: 'text'),
        ),
      ).thenThrow(StateError('db gone'));
      await openSheet(tester);

      await tester.enterText(
        find.byKey(const ValueKey('goal-charter-text')),
        'Coach me gently.',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('goal-charter-save')));
      await tester.pumpAndSettle();

      expect(find.text("That didn't save. Try again."), findsOneWidget);
      verify(
        () => logger.error(
          LogDomain.general,
          any(that: isA<StateError>()),
          stackTrace: any(named: 'stackTrace', that: isNotNull),
          subDomain: 'GoalCharterSheet',
          message: 'Failed to write a goal charter entry',
        ),
      ).called(1);
    });
  });

  group('dictation', () {
    late StartableTranscriptController recorder;

    Future<void> openWithRecorder(
      WidgetTester tester, {
      JournalEntry? entry,
    }) => openSheet(
      tester,
      entry: entry,
      recorder: () => recorder = StartableTranscriptController(),
    );

    Future<void> dictate(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('goal-charter-dictate')));
      await tester.pump();
    }

    String fieldText(WidgetTester tester) => tester
        .widget<TextField>(
          find.descendant(
            of: find.byKey(const ValueKey('goal-charter-text')),
            matching: find.byType(TextField),
          ),
        )
        .controller!
        .text;

    testWidgets('Dictate starts a take the sheet then shows', (tester) async {
      await openWithRecorder(tester);

      await dictate(tester);

      expect(recorder.startCalls, 1);
      expect(find.byType(WaveformBars), findsOneWidget);
    });

    testWidgets('a transcript is added after what is written, never '
        'replacing it', (tester) async {
      await openWithRecorder(tester);
      await tester.enterText(
        find.byKey(const ValueKey('goal-charter-text')),
        'This goal is my journal.',
      );
      await dictate(tester);

      recorder.emitTranscript('Ask me one question each morning.');
      await tester.pump();
      await tester.pump();

      expect(
        fieldText(tester),
        'This goal is my journal.\n\nAsk me one question each morning.',
      );
      expect(recorder.clearResultCalls, 1);
    });

    testWidgets('a take another surface started never lands in the charter, '
        'nor shows here', (tester) async {
      await openWithRecorder(tester);

      // The goal's chat composer shares the recorder.
      recorder.emitRecording();
      await tester.pump();
      expect(find.byType(WaveformBars), findsNothing);
      expect(
        button(tester, 'goal-charter-dictate').onPressed,
        isNull,
        reason: 'the shared recorder is busy',
      );

      recorder.emitTranscript('A message for the chat.');
      await tester.pump();
      await tester.pump();

      expect(fieldText(tester), isEmpty);
      expect(recorder.clearResultCalls, 0);
    });

    testWidgets('closing the sheet cancels its own take', (tester) async {
      await openWithRecorder(tester);
      await dictate(tester);

      await tester.tap(find.byKey(const ValueKey('goal-charter-cancel')));
      await tester.pumpAndSettle();

      expect(find.byType(GoalCharterForm), findsNothing);
      expect(recorder.cancelCalls, 1);
    });

    testWidgets("closing the sheet leaves another surface's take alone", (
      tester,
    ) async {
      await openWithRecorder(tester);
      recorder.emitRecording();
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('goal-charter-cancel')));
      await tester.pumpAndSettle();

      expect(recorder.cancelCalls, 0);
    });

    testWidgets('a failed dictation says why under the field', (
      tester,
    ) async {
      await openWithRecorder(tester);
      await dictate(tester);

      recorder.emitError(
        'mic denied',
        kind: ChatRecorderErrorKind.permissionDenied,
      );
      await tester.pump();

      final context = tester.element(find.byType(GoalCharterForm));
      expect(
        find.text(context.messages.chatInputRecordingNoMicPermission),
        findsOneWidget,
      );
    });

    testWidgets('while recording, Save waits and Stop transcribes', (
      tester,
    ) async {
      await openWithRecorder(tester, entry: existing);
      await dictate(tester);

      expect(button(tester, 'goal-charter-save').onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey('goal-charter-dictation-stop')),
      );
      await tester.pump();
      expect(recorder.stopCalls, 1);
      expect(find.text('Transcribing…'), findsOneWidget);
      expect(button(tester, 'goal-charter-save').onPressed, isNull);

      recorder.emitTranscript('More words.');
      await tester.pump();
      await tester.pump();
      // Back to idle: the field's words can be saved again.
      expect(button(tester, 'goal-charter-save').onPressed, isNotNull);
    });

    testWidgets('Cancel throws the take away and frees the sheet', (
      tester,
    ) async {
      await openWithRecorder(tester);
      await dictate(tester);

      await tester.tap(
        find.byKey(const ValueKey('goal-charter-dictation-cancel')),
      );
      await tester.pump();

      expect(recorder.cancelCalls, 1);
      expect(find.byKey(const ValueKey('goal-charter-dictate')), findsOne);
      expect(button(tester, 'goal-charter-dictate').onPressed, isNotNull);
    });

    testWidgets('the elapsed clock changes digits without moving the '
        'waveform or the buttons', (tester) async {
      await openWithRecorder(tester);
      await dictate(tester);

      Rect rectOf(Finder finder) => tester.getRect(finder);
      final waveform = find.byType(WaveformBars);
      final stop = find.byKey(const ValueKey('goal-charter-dictation-stop'));
      final elapsed = find.byKey(const ValueKey('goal-charter-elapsed'));

      recorder.updateElapsed(const Duration(seconds: 9));
      await tester.pump();
      final waveformAt = rectOf(waveform);
      final stopAt = rectOf(stop);
      final elapsedAt = rectOf(elapsed);
      expect(find.text('00:09'), findsOneWidget);

      for (final (duration, label) in [
        (const Duration(seconds: 10), '00:10'),
        (const Duration(minutes: 1), '01:00'),
        (const Duration(minutes: 9, seconds: 59), '09:59'),
        (const Duration(minutes: 10), '10:00'),
        (const Duration(minutes: 59, seconds: 59), '59:59'),
      ]) {
        recorder.updateElapsed(duration);
        await tester.pump();
        expect(find.text(label), findsOneWidget);
        expect(rectOf(waveform), waveformAt, reason: label);
        expect(rectOf(stop), stopAt, reason: label);
        expect(rectOf(elapsed), elapsedAt, reason: label);
      }

      final style = tester.widget<Text>(elapsed).style!;
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    });
  });
}
