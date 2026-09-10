import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/ui/query/query_evidence_card.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../query/query_test_utils.dart';

void main() {
  late QueryTestBench bench;
  late QueryEvidence evidence;
  late List<String> copied;
  late List<String> opened;
  setUp(() {
    bench = QueryTestBench()..add('meeting');
    final entry = bench.entries['meeting']!.copyWith(
      entryText: const EntryText(
        plainText: 'Before. Approve the feeder. After.',
      ),
    );
    bench.entries['meeting'] = entry;
    final document = QuerySourceDocument.fromEntry(entry)!;
    evidence = QueryEvidence(
      source: const QuerySourceRef(
        id: 'meeting',
        private: false,
        categoryPrivate: false,
      ),
      kind: QuerySourceKind.recording,
      label: 'Penguin habitat review',
      sourceDate: DateTime(2026, 7, 17),
      textVersion: 'transcript:mistral:voxtral:2026-07-17',
      fingerprint: document.fingerprint,
      sourceText: document.text,
      start: 8,
      end: 27,
      summary: 'Feeder approved.',
      outsideHome: true,
      affiliations: ['Zero-g galley retrofit'],
      relevance: 'The earlier feeder decision.',
    );
    copied = [];
    opened = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  Future<void> pump(WidgetTester tester, {QueryAccessSnapshot? access}) =>
      tester.pumpWidget(
        makeTestableWidget(
          QueryEvidenceCard(
            key: const PageStorageKey('quote'),
            evidence: evidence,
            number: 1,
            access:
                access ??
                QueryAccessSnapshot(
                  showPrivate: false,
                  categories: {for (final c in bench.categories) c.id: c},
                  entries: bench.entries,
                ),
            onOpen: opened.add,
          ),
          overrides: [
            querySourceAccessProvider.overrideWithValue(bench.crawler.access),
          ],
        ),
      );

  testWidgets(
    'expands an exact saved passage, then its full contiguous context',
    (tester) async {
      await pump(tester);
      expect(find.byType(SelectableText), findsNothing);
      await tester.tap(find.text('Show exact text'));
      await tester.pump();
      expect(
        tester
            .widget<SelectableText>(find.byType(SelectableText))
            .textSpan!
            .toPlainText(),
        evidence.quote,
      );
      await tester.tap(find.text('Show surrounding text'));
      await tester.pump();
      expect(
        tester
            .widget<SelectableText>(find.byType(SelectableText))
            .textSpan!
            .toPlainText(),
        evidence.sourceText,
      );
      await tester.ensureVisible(find.text('Copy quote'));
      await tester.tap(find.text('Copy quote'));
      await tester.pump();
      expect(copied, [evidence.quote]);
      expect(find.text('Copied'), findsOneWidget);
      await tester.tap(find.text('Open entry'));
      await tester.pump();
      expect(opened, ['meeting']);
    },
  );

  testWidgets(
    'edited and deleted sources retain the historical passage with a note',
    (tester) async {
      bench.entries['meeting'] = bench.entries['meeting']!.copyWith(
        entryText: const EntryText(plainText: 'Revised wording.'),
      );
      await pump(tester);
      expect(find.text('Source has changed'), findsOneWidget);
      await tester.tap(find.text('Show exact text'));
      await tester.pump();
      expect(
        tester
            .widget<SelectableText>(find.byType(SelectableText))
            .textSpan!
            .toPlainText(),
        evidence.quote,
      );
      final current = bench.entries['meeting']!;
      bench.entries['meeting'] = current.copyWith(
        meta: current.meta.copyWith(deletedAt: DateTime(2026, 9, 10)),
      );
      await pump(tester);
      expect(find.text('Source deleted'), findsOneWidget);
      expect(find.text('Open entry'), findsNothing);
      expect(
        tester
            .widget<SelectableText>(find.byType(SelectableText))
            .textSpan!
            .toPlainText(),
        evidence.quote,
      );
    },
  );

  testWidgets(
    'privacy removes metadata and quotes, and rechecks stale copy actions',
    (tester) async {
      await pump(tester);
      await tester.tap(find.text('Show exact text'));
      await tester.pump();
      bench.add('meeting', private: true);
      await tester.ensureVisible(find.text('Copy quote'));
      await tester.tap(find.text('Copy quote'));
      await tester.pump();
      expect(copied, isEmpty);
      await pump(tester);
      expect(find.textContaining('Penguin habitat'), findsNothing);
      expect(find.text('Zero-g galley retrofit'), findsNothing);
      expect(find.byType(SelectableText), findsNothing);
    },
  );
}
