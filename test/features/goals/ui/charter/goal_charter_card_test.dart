import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/goals/logic/goal_charter.dart';
import 'package:lotti/features/goals/state/goal_charter_providers.dart';
import 'package:lotti/features/goals/ui/charter/goal_charter_card.dart';
import 'package:lotti/features/goals/ui/charter/goal_charter_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/ui/evolution/widgets/evolution_recorder_test_utils.dart';

void main() {
  JournalEntry entry(String id, String text, {int day = 1}) =>
      testTextEntryNoGeo.copyWith(
        meta: testTextEntryNoGeo.meta.copyWith(
          id: id,
          dateFrom: DateTime(2026, 8, day),
        ),
        entryText: EntryText(plainText: text),
      );

  Future<void> pump(
    WidgetTester tester, {
    required Future<List<JournalEntry>> Function() entries,
    bool editable = true,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        GoalCharterCard(agentId: 'agent-1', editable: editable),
        overrides: [
          goalCharterEntriesProvider(
            'agent-1',
          ).overrideWith((ref) => entries()),
          chatRecorderControllerProvider.overrideWith(
            TranscriptEmittingController.new,
          ),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets('lists the charter in full, in the order it was written', (
    tester,
  ) async {
    await pump(
      tester,
      entries: () async => [
        entry('purpose', 'This goal is my journal.'),
        entry('style', 'Ask me one guided question each morning.', day: 2),
      ],
    );

    expect(find.text('About this goal'), findsOneWidget);
    final purpose = tester.getTopLeft(find.text('This goal is my journal.'));
    final style = tester.getTopLeft(
      find.text('Ask me one guided question each morning.'),
    );
    expect(purpose.dy, lessThan(style.dy));
    expect(find.byKey(const ValueKey('goal-charter-add')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('goal-charter-over-budget')),
      findsNothing,
    );
  });

  testWidgets('tapping an entry opens its sheet on its words', (tester) async {
    await pump(
      tester,
      entries: () async => [entry('purpose', 'This goal is my journal.')],
    );

    await tester.tap(find.byKey(const ValueKey('goal-charter-entry-purpose')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final form = tester.widget<GoalCharterForm>(find.byType(GoalCharterForm));
    expect(form.entry?.meta.id, 'purpose');
    expect(form.agentId, 'agent-1');
  });

  testWidgets('the header adds a new entry', (tester) async {
    await pump(
      tester,
      entries: () async => [entry('purpose', 'This goal is my journal.')],
    );

    await tester.tap(find.byKey(const ValueKey('goal-charter-add')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      tester.widget<GoalCharterForm>(find.byType(GoalCharterForm)).entry,
      isNull,
    );
  });

  testWidgets('with no charter yet, the card invites one', (tester) async {
    await pump(tester, entries: () async => const []);

    expect(
      find.text(
        'Tell your agent what this goal is for and how you want to be '
        'coached. It reads this every time it writes to you.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('goal-charter-add')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('goal-charter-empty-cta')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GoalCharterForm), findsOneWidget);
  });

  testWidgets('a dormant goal shows its charter but changes nothing', (
    tester,
  ) async {
    await pump(
      tester,
      editable: false,
      entries: () async => [entry('purpose', 'This goal is my journal.')],
    );

    expect(find.text('This goal is my journal.'), findsOneWidget);
    expect(find.byKey(const ValueKey('goal-charter-add')), findsNothing);
    expect(
      find.byKey(const ValueKey('goal-charter-entry-purpose')),
      findsNothing,
    );
  });

  testWidgets('a dormant goal without a charter takes no room', (
    tester,
  ) async {
    await pump(tester, editable: false, entries: () async => const []);

    expect(find.byKey(const ValueKey('goal-charter-card')), findsNothing);
  });

  testWidgets('nothing renders until the charter has loaded', (tester) async {
    final pending = Completer<List<JournalEntry>>();
    await pump(tester, entries: () => pending.future);

    expect(find.byKey(const ValueKey('goal-charter-card')), findsNothing);
    pending.complete(const []);
  });

  testWidgets('a charter longer than one wake carries says so', (
    tester,
  ) async {
    final long = List.filled(goalCharterTokenBudget, 'krill').join(' ');
    await pump(
      tester,
      entries: () async => [
        entry('purpose', 'This goal is my journal.'),
        entry('long', long, day: 2),
      ],
    );

    expect(
      find.byKey(const ValueKey('goal-charter-over-budget')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Your agent can only read the first part of this. Shorten or combine '
        'entries so it reads all of it.',
      ),
      findsOneWidget,
    );
  });
}
