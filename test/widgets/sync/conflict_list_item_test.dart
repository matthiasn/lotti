import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/conflict_list_item.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConflictListItem', () {
    testWidgets('renders conflict details and handles tap', (tester) async {
      final data = _buildConflictData();
      final localizations = AppLocalizationsEn();
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Material(
            child: ConflictListItem(
              conflict: data.conflict,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final semanticsHandle = tester.ensureSemantics();

      final entityLabel =
          '${localizations.conflictEntityLabel}: ${localizations.entryTypeLabelJournalEntry}';
      expect(find.text(entityLabel), findsOneWidget);
      expect(find.text(data.timestampLabel), findsOneWidget);
      expect(find.text(data.vectorClockLabel), findsOneWidget);
      expect(
        find.text(
          '${localizations.conflictIdLabel}: ${data.conflict.id}',
        ),
        findsOneWidget,
      );
      final semanticsNode = tester.getSemantics(find.byType(ConflictListItem));
      expect(
        semanticsNode.getSemanticsData().label,
        startsWith(data.expectedSemanticsLabel),
      );

      semanticsHandle.dispose();

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });
}

_ConflictTestData _buildConflictData({
  ConflictStatus status = ConflictStatus.unresolved,
}) {
  final createdAt = DateTime(2025, 1, 10, 15, 30, 45);
  final meta = Metadata(
    id: 'conflict-${status.name}',
    createdAt: createdAt,
    updatedAt: createdAt,
    dateFrom: createdAt,
    dateTo: createdAt.add(const Duration(minutes: 5)),
    vectorClock: const VectorClock(<String, int>{'device': 2, 'server': 7}),
  );
  final entity = JournalEntry(
    meta: meta,
    entryText: const EntryText(plainText: 'Test entry'),
  );
  final conflict = Conflict(
    id: meta.id,
    createdAt: createdAt,
    updatedAt: createdAt,
    serialized: json.encode(entity.toJson()),
    schemaVersion: 1,
    status: status.index,
  );
  final timestampLabel = df.format(createdAt);
  final l10n = AppLocalizationsEn();
  final semanticsLabel = '${toBeginningOfSentenceCase(
    l10n.conflictsUnresolved,
    l10n.localeName,
  )}, $timestampLabel, ${l10n.entryTypeLabelJournalEntry}';

  return _ConflictTestData(
    conflict: conflict,
    vectorClockLabel: meta.vectorClock!.toString(),
    expectedSemanticsLabel: semanticsLabel,
    timestampLabel: timestampLabel,
  );
}

class _ConflictTestData {
  const _ConflictTestData({
    required this.conflict,
    required this.vectorClockLabel,
    required this.expectedSemanticsLabel,
    required this.timestampLabel,
  });

  final Conflict conflict;
  final String vectorClockLabel;
  final String expectedSemanticsLabel;
  final String timestampLabel;
}
