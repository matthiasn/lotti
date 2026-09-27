import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/entry_diff_view.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/entry_field_diff.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../widget_test_utils.dart';
import 'conflict_test_entities.dart';

Future<void> _pump(WidgetTester tester, EntryDiff diff) async {
  await tester.pumpWidget(makeTestableWidget(EntryDiffView(diff: diff)));
  await tester.pump();
}

void main() {
  testWidgets('body change renders both sides with the changed word', (
    tester,
  ) async {
    final diff = computeEntryDiff(
      entryOf(text: 'hello world'),
      entryOf(text: 'hello brave world'),
    );

    await _pump(tester, diff);

    expect(find.text('Body'), findsOneWidget);
    expect(find.text('THIS DEVICE'), findsOneWidget);
    expect(find.text('FROM SYNC'), findsOneWidget);
    // 'brave' is the remote-introduced word, rendered as a highlight pill.
    expect(find.text('brave'), findsOneWidget);
  });

  testWidgets(
    'each field renders on a level02 card with a decorative hairline border '
    'so it lifts off the near-black scaffold',
    (tester) async {
      final diff = computeEntryDiff(
        entryOf(text: 'hello world'),
        entryOf(text: 'hello brave world'),
      );

      await _pump(tester, diff);

      const tokens = dsTokensLight;
      final decoration = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(EntryDiffView),
              matching: find.byType(Container),
            ),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere(
            (d) => d.border != null,
            orElse: () => throw StateError('no bordered field card found'),
          );

      expect(decoration.color, tokens.colors.background.level02);
      final side = (decoration.border! as Border).top;
      expect(side.color, tokens.colors.decorative.level01);
    },
  );

  testWidgets('boolean fields render localized Yes/No values', (tester) async {
    final diff = computeEntryDiff(
      entryOf(starred: true),
      entryOf(starred: false),
    );

    await _pump(tester, diff);

    expect(find.text('Starred'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
  });

  testWidgets('flag values are localized, not raw enum names', (tester) async {
    final diff = computeEntryDiff(
      entryOf(flag: EntryFlag.none),
      entryOf(flag: EntryFlag.followUpNeeded),
    );

    await _pump(tester, diff);

    expect(find.text('Flag'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
    expect(find.text('Follow-up needed'), findsOneWidget);
    // The canonical engine value must never leak to the UI.
    expect(find.text('followUpNeeded'), findsNothing);
  });

  testWidgets('the import flag is localized to its human label', (
    tester,
  ) async {
    final diff = computeEntryDiff(
      entryOf(flag: EntryFlag.import),
      entryOf(flag: EntryFlag.none),
    );

    await _pump(tester, diff);

    expect(find.text('Flag'), findsOneWidget);
    expect(find.text('Imported'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
    expect(find.text('import'), findsNothing);
  });

  testWidgets('date fields are formatted, never shown as raw ISO strings', (
    tester,
  ) async {
    final diff = computeEntryDiff(
      entryOf(dateFrom: DateTime(2024, 3, 15, 9)),
      entryOf(dateFrom: DateTime(2024, 3, 16, 14, 30)),
    );

    await _pump(tester, diff);

    expect(find.text('Start'), findsOneWidget);
    // Localized M/D/YYYY + h:mm on each side (intl uses a narrow no-break
    // space before AM/PM, so match on fragments rather than the exact string).
    expect(find.textContaining('3/15/2024'), findsOneWidget);
    expect(find.textContaining('9:00'), findsOneWidget);
    expect(find.textContaining('3/16/2024'), findsOneWidget);
    expect(find.textContaining('2:30'), findsOneWidget);
    // The canonical ISO string must never reach the UI.
    expect(find.textContaining('2024-03-15T'), findsNothing);
  });

  testWidgets('an unparseable date value falls back to the raw string', (
    tester,
  ) async {
    // Defensive path: a date field whose canonical value can't be parsed is
    // shown verbatim rather than crashing the formatter.
    const diff = EntryDiff(
      shape: ConflictShape.edited,
      fields: [
        FieldDiff(
          field: EntryField.dateFrom,
          kind: FieldDiffKind.changed,
          localValue: 'not-a-date',
          remoteValue: '2024-03-16T14:30:00.000',
        ),
      ],
      identicalFieldCount: 0,
    );

    await _pump(tester, diff);

    expect(find.text('not-a-date'), findsOneWidget);
    // The parseable side is still formatted.
    expect(find.textContaining('3/16/2024'), findsOneWidget);
  });

  testWidgets('an emptied text side renders as "Not set", not a blank pill', (
    tester,
  ) async {
    // A whitespace-only title is "present" (non-empty) so it diffs as a
    // change, but tokenizes to nothing — the local word-diff side is empty.
    final diff = computeEntryDiff(
      taskOf(title: '   '),
      taskOf(title: 'Renamed'),
    );

    await _pump(tester, diff);

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);
    expect(find.text('Renamed'), findsOneWidget);
  });

  testWidgets('audio duration is shown formatted on both sides', (
    tester,
  ) async {
    final diff = computeEntryDiff(
      audioOf(duration: const Duration(seconds: 60)),
      audioOf(duration: const Duration(seconds: 90)),
    );

    await _pump(tester, diff);

    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('1:00'), findsOneWidget);
    expect(find.text('1:30'), findsOneWidget);
  });

  testWidgets('the completeness catch-all is surfaced explicitly', (
    tester,
  ) async {
    final diff = computeEntryDiff(
      taskOf(languageCode: 'de'),
      taskOf(languageCode: 'fr'),
    );

    await _pump(tester, diff);

    expect(diff.fields.map((field) => field.field), [EntryField.other]);
    expect(find.text('Other details'), findsOneWidget);
    expect(find.textContaining('differ in details'), findsOneWidget);
  });

  testWidgets("a task's status, priority, estimate and due date are "
      'labelled and shown as the task page shows them', (tester) async {
    final diff = computeEntryDiff(
      taskOf(
        status: TaskStatus.blocked(
          id: 'st-b',
          createdAt: DateTime(2024, 3, 15, 10),
          utcOffset: 0,
          reason: 'waiting on review',
        ),
        estimate: const Duration(minutes: 90),
        priority: TaskPriority.p0Urgent,
        due: DateTime(2024, 4, 2),
      ),
      taskOf(),
    );

    await _pump(tester, diff);

    for (final label in ['Status', 'Priority', 'Estimate', 'Due date']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Blocked: waiting on review'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Urgent'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Other details'), findsNothing);
  });

  testWidgets('identical fields are summarized and no side rows are shown', (
    tester,
  ) async {
    final diff = computeEntryDiff(entryOf(), entryOf());

    await _pump(tester, diff);

    expect(diff.fields, isEmpty);
    // body + dateFrom + dateTo are present and equal.
    expect(find.text('3 fields unchanged'), findsOneWidget);
    expect(find.text('THIS DEVICE'), findsNothing);
  });
}
