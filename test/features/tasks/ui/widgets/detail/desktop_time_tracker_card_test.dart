import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/tasks/ui/widgets/detail/desktop_time_tracker_card.dart';

import '../../../../../widget_test_utils.dart';
import 'detail_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(setUpDetailTestGetIt);
  tearDown(tearDownDetailTestGetIt);

  final testTimeEntry = JournalEntry(
    meta: Metadata(
      id: 'time-entry-1',
      createdAt: detailTestDate,
      dateFrom: detailTestDate,
      dateTo: detailTestDate.add(const Duration(minutes: 25)),
      updatedAt: detailTestDate,
    ),
    entryText: const EntryText(plainText: 'Worked on feature'),
  );

  Widget buildSubject({
    List<JournalEntity> linkedEntities = const [],
  }) {
    return makeTestableWidgetWithScaffold(
      SizedBox(
        width: 600,
        child: DesktopTimeTrackerCard(taskId: detailTestTask.meta.id),
      ),
      theme: DesignSystemTheme.dark(),
      overrides: [
        createDetailEntryOverride(detailTestTask),
        resolvedOutgoingLinkedEntriesProvider(
          detailTestTask.meta.id,
        ).overrideWith((ref) => linkedEntities),
      ],
    );
  }

  testWidgets('displays Time Tracker title', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Time Tracker'), findsOneWidget);
  });

  testWidgets('displays Track time button', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Timer'), findsOneWidget);
  });

  testWidgets('shows duration when time entries exist', (tester) async {
    await tester.pumpWidget(
      buildSubject(linkedEntities: [testTimeEntry]),
    );
    await tester.pump();

    // Duration appears in header and in the entry row
    expect(find.text('25m'), findsAtLeastNWidgets(1));
  });

  testWidgets('shows time entry note text', (tester) async {
    await tester.pumpWidget(
      buildSubject(linkedEntities: [testTimeEntry]),
    );
    await tester.pump();

    expect(find.text('Worked on feature'), findsOneWidget);
  });

  testWidgets('collapse hides entries and track button', (tester) async {
    await tester.pumpWidget(
      buildSubject(linkedEntities: [testTimeEntry]),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.expand_less_rounded));
    await tester.pump();

    expect(find.text('Timer'), findsNothing);
    expect(find.text('Worked on feature'), findsNothing);
    expect(find.text('Time Tracker'), findsOneWidget);
  });
}
