import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/ui/time_entry_update_tile.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  const entryId = 'entry-001';

  JournalEntry makeEntry() {
    return JournalEntry(
      meta: Metadata(
        id: entryId,
        dateFrom: DateTime(2026, 4, 15, 13),
        dateTo: DateTime(2026, 4, 15, 14),
        createdAt: DateTime(2026, 4, 15, 12),
        updatedAt: DateTime(2026, 4, 15, 12),
      ),
      entryText: const EntryText(plainText: 'Original workshop notes'),
    );
  }

  Widget host(
    Map<String, dynamic> args, {
    JournalEntity? entry,
    bool busy = false,
  }) {
    return makeTestableWidgetWithScaffold(
      TimeEntryUpdateTile(args: args, busy: busy),
      overrides: [
        timeEntryUpdateTileEntryProvider(
          (args['entryId'] as String?) ?? entryId,
        ).overrideWith((ref) async => entry),
      ],
    );
  }

  Future<void> pumpTile(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await tester.pump();
  }

  group('TimeEntryUpdateTile', () {
    testWidgets('renders current to proposed diff for touched fields', (
      tester,
    ) async {
      await pumpTile(
        tester,
        host(
          const {
            'entryId': entryId,
            'startTime': '2026-04-15T13:30:00',
            'endTime': '2026-04-15T14:45:00',
            'summary': 'Workshop plus token budgets',
          },
          entry: makeEntry(),
        ),
      );

      expect(find.byIcon(Icons.edit_calendar_outlined), findsOneWidget);
      expect(
        find.textContaining(
          'Current: 2026-04-15 13:00 -> Proposed: 2026-04-15 13:30',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Current: 2026-04-15 14:00 -> Proposed: 2026-04-15 14:45',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Current: Original workshop notes -> Proposed: Workshop plus token budgets',
        ),
        findsOneWidget,
      );
    });

    testWidgets('loads current entry through the journal repository provider', (
      tester,
    ) async {
      final repository = MockJournalRepository();
      when(
        () => repository.getJournalEntityById(entryId),
      ).thenAnswer((_) async => makeEntry());

      await pumpTile(
        tester,
        makeTestableWidgetWithScaffold(
          const TimeEntryUpdateTile(
            args: {
              'entryId': entryId,
              'summary': 'Repository-backed update',
            },
            busy: false,
          ),
          overrides: [journalRepositoryProvider.overrideWithValue(repository)],
        ),
      );

      expect(
        find.textContaining(
          'Current: Original workshop notes -> Proposed: Repository-backed update',
        ),
        findsOneWidget,
      );
      verify(() => repository.getJournalEntityById(entryId)).called(1);
    });

    testWidgets('marks untouched fields as unchanged', (tester) async {
      await pumpTile(
        tester,
        host(
          const {
            'entryId': entryId,
            'summary': 'Revised summary only',
          },
          entry: makeEntry(),
        ),
      );

      expect(
        find.textContaining('Current: 2026-04-15 13:00 (unchanged)'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Current: 2026-04-15 14:00 (unchanged)'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Proposed: Revised summary only'),
        findsOneWidget,
      );
    });

    testWidgets('renders unavailable state when current entry load fails', (
      tester,
    ) async {
      await pumpTile(
        tester,
        makeTestableWidgetWithScaffold(
          const TimeEntryUpdateTile(
            args: {
              'entryId': entryId,
              'summary': 'Fallback proposal',
            },
            busy: false,
          ),
          overrides: [
            timeEntryUpdateTileEntryProvider(
              entryId,
            ).overrideWith((ref) async => throw StateError('load failed')),
          ],
        ),
      );

      expect(find.text('Original entry not available'), findsOneWidget);
      expect(
        find.textContaining('Proposed: Fallback proposal'),
        findsOneWidget,
      );
    });

    testWidgets('renders unavailable state with proposed values only', (
      tester,
    ) async {
      await pumpTile(
        tester,
        host(
          const {
            'entryId': entryId,
            'endTime': '2026-04-15T15:00:00',
          },
        ),
      );

      expect(find.text('Original entry not available'), findsOneWidget);
      expect(
        find.textContaining('Proposed: 2026-04-15 15:00'),
        findsOneWidget,
      );
    });

    testWidgets('shows progress indicator when busy', (tester) async {
      await pumpTile(
        tester,
        host(
          const {
            'entryId': entryId,
            'summary': 'Busy update',
          },
          entry: makeEntry(),
          busy: true,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
