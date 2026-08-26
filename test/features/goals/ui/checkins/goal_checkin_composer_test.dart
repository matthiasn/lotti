import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_composer.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final now = DateTime(2026, 8, 18, 14, 20);

  late List<({String text, String goalEntryId})> saved;
  late List<String> recorded;
  var saveSucceeds = true;
  String? recorderResult;

  setUp(() {
    saved = [];
    recorded = [];
    saveSucceeds = true;
    recorderResult = 'audio-1';
  });

  Future<void> pump(
    WidgetTester tester, {
    String? captureTarget = 'goal-1',
    String? preparedLine,
    String? personaName,
  }) => withClock(
    Clock.fixed(now),
    () => tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        GoalCheckInComposer(
          agentId: 'agent-1',
          goalTitle: 'Fitness',
          preparedLine: preparedLine,
          personaName: personaName,
          categoryId: 'cat-1',
          saveText: ({required text, required goalEntryId, categoryId}) async {
            saved.add((text: text, goalEntryId: goalEntryId));
            return saveSucceeds;
          },
          openRecorder: (context, {required goalEntryId, categoryId}) async {
            recorded.add(goalEntryId);
            return recorderResult;
          },
        ),
        overrides: [
          goalCaptureTargetProvider(
            'agent-1',
          ).overrideWith((ref) async => captureTarget),
        ],
      ),
    ),
  );

  group('the real adapters behind the seams', () {
    tearDown(getIt.reset);

    test('saveCheckInText reports failure rather than throwing', () async {
      // No journal stack registered: the static path logs and returns null,
      // and the adapter must translate that into "not saved" rather than
      // letting the composer think it succeeded.
      getIt.registerSingleton<DomainLogger>(MockDomainLogger());

      expect(
        await saveCheckInText(text: 'Walked.', goalEntryId: 'goal-1'),
        isFalse,
      );
    });
  });

  testWidgets('names the goal and the moment', (tester) async {
    await pump(tester);
    await tester.pump();

    expect(find.text('Check in · Fitness'), findsOneWidget);
    expect(find.textContaining('August'), findsOneWidget);
  });

  testWidgets('opens on the recorder, not on a keyboard', (tester) async {
    await pump(tester);
    await tester.pump();

    // One tap, no typing, is the entire point.
    expect(find.byKey(const ValueKey('goal-checkin-record')), findsOneWidget);
    expect(find.byType(DesignSystemTextarea), findsNothing);
  });

  testWidgets('recording is withheld until the goal row exists', (
    tester,
  ) async {
    await pump(tester, captureTarget: null);
    await tester.pump();

    // Linking to a row that has not been written saves the recording and
    // silently drops the link, so the beat would never appear.
    final button = tester.widget<DesignSystemButton>(
      find.byKey(const ValueKey('goal-checkin-record')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Write instead swaps the recorder for a textarea', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump();

    await tester.tap(find.text('Write instead'));
    await tester.pump();

    expect(find.byType(DesignSystemTextarea), findsOneWidget);
    expect(find.byKey(const ValueKey('goal-checkin-record')), findsNothing);
    // And back again — the fallback is a toggle, not a one-way door.
    expect(find.text('Record a check-in'), findsWidgets);
  });

  testWidgets("the prepared line is shown as the agent's, not as fact", (
    tester,
  ) async {
    await pump(
      tester,
      preparedLine: 'You said you would walk after lunch. It is 14:20.',
      personaName: 'Juno',
    );
    await tester.pump();

    expect(
      find.text('You said you would walk after lunch. It is 14:20.'),
      findsOneWidget,
    );
    // Provenance is explicit: the user is never answering a prompt without
    // knowing whose it is.
    expect(find.text('Juno · prepared for you'), findsOneWidget);
  });

  testWidgets('recording links to the goal row it was given', (tester) async {
    await pump(tester);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('goal-checkin-record')));
    await tester.pumpAndSettle();

    // The link is what puts the recording on the timeline — and, because the
    // recorder's stop path transcribes goal-linked audio, into the pipeline.
    expect(recorded, ['goal-1']);
    // The composer's job ended with the recording; it closes itself.
    expect(find.byType(GoalCheckInComposer), findsNothing);
  });

  testWidgets('discarding a recording returns to the composer', (tester) async {
    recorderResult = null;
    await pump(tester);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('goal-checkin-record')));
    await tester.pump();

    expect(recorded, ['goal-1']);
    expect(find.byType(GoalCheckInComposer), findsOneWidget);
  });

  testWidgets('a written check-in saves its text against the goal', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump();
    await tester.tap(find.text('Write instead'));
    await tester.pump();

    await tester.enterText(
      find.byType(DesignSystemTextarea),
      '  Gym bag is packed.  ',
    );
    await tester.tap(find.text('Save check-in'));
    await tester.pump();

    expect(saved, hasLength(1));
    // Trimmed: the surrounding whitespace is an artifact of typing, not part
    // of what the user said.
    expect(saved.single.text, 'Gym bag is packed.');
    expect(saved.single.goalEntryId, 'goal-1');
  });

  testWidgets('an empty written check-in saves nothing', (tester) async {
    await pump(tester);
    await tester.pump();
    await tester.tap(find.text('Write instead'));
    await tester.pump();

    await tester.enterText(find.byType(DesignSystemTextarea), '   ');
    await tester.tap(find.text('Save check-in'));
    await tester.pump();

    expect(saved, isEmpty);
  });

  testWidgets('a failed save keeps the composer open with the text intact', (
    tester,
  ) async {
    saveSucceeds = false;
    await pump(tester);
    await tester.pump();
    await tester.tap(find.text('Write instead'));
    await tester.pump();

    await tester.enterText(find.byType(DesignSystemTextarea), 'Walked.');
    await tester.tap(find.text('Save check-in'));
    await tester.pumpAndSettle();

    // Closing on failure would discard what the user just wrote.
    expect(find.byType(GoalCheckInComposer), findsOneWidget);
    expect(find.text('Walked.'), findsOneWidget);
  });

  testWidgets('Close dismisses record mode without implying a save', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump();

    expect(find.text('Save check-in'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Record mode has one primary CTA; Close is an unambiguous dismissal.
    expect(saved, isEmpty);
    expect(find.byType(GoalCheckInComposer), findsNothing);
  });

  testWidgets('no prepared line renders no empty card', (tester) async {
    await pump(tester);
    await tester.pump();

    // An absent prompt is normal; capture is the job, the prompt is additive.
    expect(find.textContaining('prepared for you'), findsNothing);
  });
}
