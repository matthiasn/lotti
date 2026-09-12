import 'dart:ui' show Tristate;

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
  late PageStorageBucket storage;
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
    storage = PageStorageBucket();
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
          PageStorage(
            bucket: storage,
            child: QueryEvidenceCard(
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
          ),
          overrides: [
            querySourceAccessProvider.overrideWithValue(bench.crawler.access),
          ],
        ),
      );

  testWidgets(
    'quote disclosure marks omitted context and keeps copy verbatim',
    (tester) async {
      await pump(tester);
      expect(find.text('Recording transcript'), findsOneWidget);
      expect(find.text(evidence.summary), findsOneWidget);
      await tester.tap(find.text('Show exact text'));
      await tester.pump();
      expect(find.text('Hide exact text'), findsOneWidget);
      expect(find.text(evidence.summary), findsNothing);
      expect(find.text('Exact stored text'), findsOneWidget);
      final passage = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .textSpan!;
      expect(
        passage.toPlainText(),
        '[Earlier text not shown]\n${evidence.quote}\n[Later text not shown]',
      );
      await tester.ensureVisible(find.text('Copy quote'));
      await tester.pump();
      await tester.tap(find.text('Copy quote'));
      await tester.pump();
      expect(copied, [evidence.quote]);
      await tester.tap(find.text('Hide exact text'));
      await tester.pump();
      expect(find.byType(SelectableText), findsNothing);
      expect(find.text('Show exact text'), findsOneWidget);
    },
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
        '[Earlier text not shown]\n${evidence.quote}\n[Later text not shown]',
      );
      expect(find.text('Version date unavailable'), findsOneWidget);
      await tester.tap(find.text('Show surrounding text'));
      await tester.pump();
      expect(
        tester
            .widget<SelectableText>(find.byType(SelectableText))
            .textSpan!
            .toPlainText(),
        evidence.sourceText,
      );
      expect(
        find.text(
          'This is the saved excerpt, which may not include the full discussion.',
        ),
        findsOneWidget,
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
        '[Earlier text not shown]\n${evidence.quote}\n[Later text not shown]',
      );
      await tester.ensureVisible(find.text('Open current entry'));
      await tester.tap(find.text('Open current entry'));
      expect(opened, ['meeting']);
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
        '[Earlier text not shown]\n${evidence.quote}\n[Later text not shown]',
      );
    },
  );

  testWidgets(
    'returning to a moved source restores its expanded historical context',
    (tester) async {
      await pump(tester);
      await tester.tap(find.text('Show exact text'));
      await tester.pump();
      await tester.tap(find.text('Show surrounding text'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      final source = bench.entries['meeting']!;
      bench.entries['meeting'] = source.copyWith(
        meta: source.meta.copyWith(categoryId: bench.categories.single.id),
      );
      await pump(tester);
      expect(find.text('Source moved to another category'), findsOneWidget);
      expect(
        tester
            .widget<SelectableText>(find.byType(SelectableText))
            .textSpan!
            .toPlainText(),
        evidence.sourceText,
      );
      await tester.tap(find.text('Hide surrounding text'));
      await tester.pump();
      expect(
        tester
            .widget<SelectableText>(find.byType(SelectableText))
            .textSpan!
            .toPlainText(),
        '[Earlier text not shown]\n${evidence.quote}\n[Later text not shown]',
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
  testWidgets('full saved windows disclose their limit without altering copy', (
    tester,
  ) async {
    evidence = evidence.copyWith(start: 0, end: evidence.sourceText.length);
    await pump(tester);
    await tester.tap(find.text('Show exact text'));
    await tester.pump();
    expect(find.text('Show surrounding text'), findsNothing);
    expect(
      find.text(
        'This is the saved excerpt, which may not include the full discussion.',
      ),
      findsOneWidget,
    );
    expect(find.text('Version date unavailable'), findsOneWidget);
    expect(
      find.textContaining(evidence.fingerprint.substring(0, 8)),
      findsNothing,
    );
    await tester.ensureVisible(find.text('Copy quote'));
    await tester.tap(find.text('Copy quote'));
    await tester.pump();
    expect(copied, [evidence.sourceText]);
  });

  testWidgets(
    'source actions expose their target and surrounding disclosure state',
    (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await pump(tester);
        expect(
          find.bySemanticsLabel('Show exact text: Penguin habitat review'),
          findsOneWidget,
        );
        await tester.tap(find.text('Show exact text'));
        await tester.pump();
        Finder disclosure() => find.bySemanticsLabel(
          find.text('Show surrounding text').evaluate().isNotEmpty
              ? 'Show surrounding text: Penguin habitat review'
              : 'Hide surrounding text: Penguin habitat review',
        );
        expect(
          tester.getSemantics(disclosure()).flagsCollection.isExpanded,
          Tristate.isFalse,
        );
        await tester.tap(find.text('Show surrounding text'));
        await tester.pump();
        expect(
          tester.getSemantics(disclosure()).flagsCollection.isExpanded,
          Tristate.isTrue,
        );
        await tester.tap(find.text('Hide surrounding text'));
        await tester.pump();
        expect(
          tester.getSemantics(disclosure()).flagsCollection.isExpanded,
          Tristate.isFalse,
        );
        expect(
          find.bySemanticsLabel('Copy quote: Penguin habitat review'),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final explicitDate in [false, true]) {
    testWidgets(
      'saved version uses its edit or transcript date (explicit=$explicitDate)',
      (tester) async {
        evidence = evidence.copyWith(
          textVersion: explicitDate
              ? 'transcript:mistral:voxtral:stable-id'
              : 'entryText:2026-07-18T09:30:00.000',
          textVersionDate: explicitDate ? DateTime(2026, 7, 18, 9, 30) : null,
        );
        await pump(tester);
        await tester.tap(find.text('Show exact text'));
        await tester.pump();
        expect(
          find.text('Saved version: Jul 18, 2026 09:30:00'),
          findsOneWidget,
        );
        expect(
          find.textContaining(evidence.fingerprint.substring(0, 8)),
          findsNothing,
        );
      },
    );
  }
}
