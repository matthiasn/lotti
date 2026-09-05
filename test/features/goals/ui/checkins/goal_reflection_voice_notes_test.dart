import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/goals/ui/checkins/goal_reflection_voice_notes.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  final today = DateTime(2026, 8, 18, 9);
  final yesterday = today.subtract(const Duration(days: 1));

  Metadata meta(String id, DateTime at, {DateTime? deletedAt}) => Metadata(
    id: id,
    createdAt: at,
    updatedAt: at,
    dateFrom: at,
    dateTo: at,
    deletedAt: deletedAt,
  );

  JournalAudio audio(String id, DateTime at, {DateTime? deletedAt}) =>
      JournalAudio(
        meta: meta(id, at, deletedAt: deletedAt),
        data: AudioData(
          dateFrom: at,
          dateTo: at.add(const Duration(seconds: 20)),
          audioFile: '$id.m4a',
          audioDirectory: '/audio/',
          duration: const Duration(seconds: 20),
        ),
      );

  late List<String> recorded;

  setUp(() {
    recorded = [];
  });

  Future<void> pump(
    WidgetTester tester, {
    required DateTime day,
    List<JournalEntity> entries = const [],
    String? captureTarget = 'goal-1',
    bool enabled = true,
  }) => withClock(
    Clock.fixed(today.add(const Duration(hours: 2))),
    // The settle pump belongs INSIDE the fixed clock, not after it. The
    // capture target resolves a frame late, and that rebuild is the one that
    // asks `clock.now()` whether the reflected day is today — so leaving it
    // outside read the wall clock and hid the capture row for every run that
    // happened on a later calendar day than the fixture.
    () async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          GoalReflectionVoiceNotes(
            agentId: 'agent-1',
            day: day,
            enabled: enabled,
            openRecorder: (context, {required goalEntryId, categoryId}) async {
              recorded.add(goalEntryId);
              return 'audio-1';
            },
          ),
          overrides: [
            goalCheckInEntriesProvider('agent-1').overrideWithValue(entries),
            goalCaptureTargetProvider(
              'agent-1',
            ).overrideWith((ref) async => captureTarget),
          ],
        ),
      );
      await tester.pump();
    },
  );

  testWidgets("shows the reflected day's recordings, not today's", (
    tester,
  ) async {
    await pump(
      tester,
      day: yesterday,
      entries: [
        audio('today-a', today),
        audio('today-b', today),
        audio('yesterday-note', yesterday),
      ],
    );
    await tester.pump();

    // Exactly one player: yesterday's. Reopening yesterday's sheet used to
    // hide its own voice note and show two unrelated recordings from today.
    expect(find.byType(AudioPlayerWidget), findsOneWidget);
  });

  testWidgets('a deleted recording is not offered for playback', (
    tester,
  ) async {
    await pump(
      tester,
      day: today,
      entries: [
        audio('kept', today),
        audio('gone', today, deletedAt: today),
      ],
    );
    await tester.pump();

    expect(find.byType(AudioPlayerWidget), findsOneWidget);
  });

  testWidgets('offers capture only on today', (tester) async {
    await pump(tester, day: today);
    await tester.pump();
    expect(find.text('Add a voice note'), findsOneWidget);

    await pump(tester, day: yesterday);
    await tester.pump();
    // A recording always lands on the moment it happens, so offering capture
    // under a past day would file today's words as yesterday's.
    expect(find.text('Add a voice note'), findsNothing);
  });

  testWidgets('withholds capture until the goal row exists', (tester) async {
    await pump(tester, day: today, captureTarget: null);
    await tester.pump();

    // Linking to a goal row that has not been written yet saves the recording
    // and silently drops the link.
    expect(find.text('Add a voice note'), findsNothing);
  });

  testWidgets('adding a voice note links it to the goal', (tester) async {
    await pump(tester, day: today);
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('goal-reflection-add-voice-note')),
    );
    await tester.pump();

    // Linked immediately, so a dismissed sheet cannot orphan the recording —
    // and the link is what makes the recorder's stop path transcribe it as a
    // check-in.
    expect(recorded, ['goal-1']);
  });

  testWidgets('a disabled sheet offers no capture', (tester) async {
    await pump(tester, day: today, enabled: false);
    await tester.pump();
    expect(find.text('Add a voice note'), findsNothing);
  });

  testWidgets('the capture row is a quiet link: no hover fill, its own ink '
      'lifts', (tester) async {
    await pump(tester, day: today);
    await tester.pump();

    final row = find.byKey(const ValueKey('goal-reflection-add-voice-note'));
    final ink = tester.widget<InkWell>(
      find.descendant(of: row, matching: find.byType(InkWell)),
    );
    expect(ink.hoverColor, Colors.transparent);
    expect(
      ink.overlayColor?.resolve({WidgetState.hovered}),
      Colors.transparent,
    );

    final tokens = tester.element(row).designTokens;
    Text label() => tester.widget<Text>(find.text('Add a voice note'));
    expect(label().style?.color, tokens.colors.interactive.enabled);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(row));
    await tester.pump();
    expect(label().style?.color, tokens.colors.interactive.hover);
    await gesture.moveTo(Offset.zero);
    await tester.pump();
  });
}
