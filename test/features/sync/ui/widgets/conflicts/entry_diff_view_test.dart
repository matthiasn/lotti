import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/entry_diff_view.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/entry_field_diff.dart';

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
      taskOf(estimate: const Duration(hours: 4)),
      taskOf(estimate: const Duration(hours: 5)),
    );

    await _pump(tester, diff);

    expect(diff.hasOtherDifferences, isTrue);
    expect(find.text('Other details'), findsOneWidget);
    expect(find.textContaining('differ in details'), findsOneWidget);
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
