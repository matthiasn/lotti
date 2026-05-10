import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    show
        Any,
        BoolAny,
        CombinableAny,
        ExploreConfig,
        Generator,
        Glados,
        IntAnys,
        any;
import 'package:lotti/features/agents/ui/report_content_parser.dart';

class _GeneratedHeadingReport {
  const _GeneratedHeadingReport({
    required this.hasLeadingH1,
    required this.preludeLineCount,
    required this.tldrLineCount,
    required this.additionalSectionCount,
    required this.seed,
  });

  final bool hasLeadingH1;
  final int preludeLineCount;
  final int tldrLineCount;
  final int additionalSectionCount;
  final int seed;

  List<String> get _preludeLines => [
    for (var index = 0; index < preludeLineCount; index++)
      'Status line ${seed + index}',
  ];

  List<String> get _tldrLines => [
    for (var index = 0; index < tldrLineCount; index++)
      'TLDR generated line ${seed + index}',
  ];

  List<List<String>> get _additionalSections => [
    for (var index = 0; index < additionalSectionCount; index++)
      [
        '## Generated Section ${seed + index}',
        '- Generated item ${seed + index}',
      ],
  ];

  String get content {
    return [
      if (hasLeadingH1) '# Generated Report $seed',
      ..._preludeLines,
      '## 📋 TLDR',
      ..._tldrLines,
      for (final section in _additionalSections) ...[
        '',
        ...section,
      ],
    ].join('\n');
  }

  String get expectedTldr {
    return [
      ..._preludeLines,
      '## 📋 TLDR',
      ..._tldrLines,
    ].join('\n').trim();
  }

  String? get expectedAdditional {
    if (_additionalSections.isEmpty) return null;
    return [
      for (final section in _additionalSections) section.join('\n'),
    ].join('\n\n').trim();
  }

  @override
  String toString() {
    return '_GeneratedHeadingReport('
        'hasLeadingH1: $hasLeadingH1, '
        'preludeLineCount: $preludeLineCount, '
        'tldrLineCount: $tldrLineCount, '
        'additionalSectionCount: $additionalSectionCount, '
        'seed: $seed)';
  }
}

class _GeneratedBoldReport {
  const _GeneratedBoldReport({
    required this.hasLeadingH1,
    required this.preludeLineCount,
    required this.continuationLineCount,
    required this.hasAdditional,
    required this.seed,
  });

  final bool hasLeadingH1;
  final int preludeLineCount;
  final int continuationLineCount;
  final bool hasAdditional;
  final int seed;

  List<String> get _preludeLines => [
    for (var index = 0; index < preludeLineCount; index++)
      'Status line ${seed + index}',
  ];

  List<String> get _boldLines => [
    '**TLDR:** Generated summary $seed.',
    for (var index = 0; index < continuationLineCount; index++)
      'Continuation line ${seed + index}.',
  ];

  String get _additional => '## Details\n- Detail item $seed';

  String get content {
    return [
      if (hasLeadingH1) '# Generated Report $seed',
      ..._preludeLines,
      ..._boldLines,
      if (hasAdditional) ...['', _additional],
    ].join('\n');
  }

  String get expectedTldr =>
      [..._preludeLines, ..._boldLines].join('\n').trim();

  String? get expectedAdditional => hasAdditional ? _additional : null;

  @override
  String toString() {
    return '_GeneratedBoldReport('
        'hasLeadingH1: $hasLeadingH1, '
        'preludeLineCount: $preludeLineCount, '
        'continuationLineCount: $continuationLineCount, '
        'hasAdditional: $hasAdditional, '
        'seed: $seed)';
  }
}

class _GeneratedParagraphReport {
  const _GeneratedParagraphReport({
    required this.hasLeadingH1,
    required this.paragraphCount,
    required this.seed,
  });

  final bool hasLeadingH1;
  final int paragraphCount;
  final int seed;

  List<String> get _paragraphs => [
    for (var index = 0; index < paragraphCount; index++)
      'Generated paragraph ${seed + index}.\nStill paragraph ${seed + index}.',
  ];

  String get content {
    return [
      if (hasLeadingH1) '# Generated Report $seed',
      ..._paragraphs,
    ].join('\n\n');
  }

  String get expectedTldr => _paragraphs.first;

  String? get expectedAdditional {
    if (_paragraphs.length == 1) return null;
    return _paragraphs.skip(1).join('\n\n').trim();
  }

  @override
  String toString() {
    return '_GeneratedParagraphReport('
        'hasLeadingH1: $hasLeadingH1, '
        'paragraphCount: $paragraphCount, '
        'seed: $seed)';
  }
}

extension _AnyGeneratedReport on Any {
  Generator<_GeneratedHeadingReport> get headingReport => combine5(
    this.bool,
    intInRange(0, 3),
    intInRange(1, 5),
    intInRange(0, 4),
    intInRange(0, 10000),
    (
      bool hasLeadingH1,
      int preludeLineCount,
      int tldrLineCount,
      int additionalSectionCount,
      int seed,
    ) => _GeneratedHeadingReport(
      hasLeadingH1: hasLeadingH1,
      preludeLineCount: preludeLineCount,
      tldrLineCount: tldrLineCount,
      additionalSectionCount: additionalSectionCount,
      seed: seed,
    ),
  );

  Generator<_GeneratedBoldReport> get boldReport => combine5(
    this.bool,
    intInRange(0, 3),
    intInRange(0, 4),
    this.bool,
    intInRange(0, 10000),
    (
      bool hasLeadingH1,
      int preludeLineCount,
      int continuationLineCount,
      bool hasAdditional,
      int seed,
    ) => _GeneratedBoldReport(
      hasLeadingH1: hasLeadingH1,
      preludeLineCount: preludeLineCount,
      continuationLineCount: continuationLineCount,
      hasAdditional: hasAdditional,
      seed: seed,
    ),
  );

  Generator<_GeneratedParagraphReport> get paragraphReport => combine3(
    this.bool,
    intInRange(1, 6),
    intInRange(0, 10000),
    (bool hasLeadingH1, int paragraphCount, int seed) =>
        _GeneratedParagraphReport(
          hasLeadingH1: hasLeadingH1,
          paragraphCount: paragraphCount,
          seed: seed,
        ),
  );
}

void main() {
  group('parseReportContent', () {
    test('returns empty tldr and null additional for empty content', () {
      final result = parseReportContent('');
      expect(result.tldr, '');
      expect(result.additional, isNull);
    });

    group('## 📋 TLDR heading pattern', () {
      test('extracts TLDR and additional when both present', () {
        const content =
            '## 📋 TLDR\n'
            'Task is on track.\n'
            '\n'
            '## ✅ Achieved\n'
            '- Did something\n'
            '\n'
            '## 📌 What is left to do\n'
            '- More stuff';

        final result = parseReportContent(content);

        expect(result.tldr, contains('TLDR'));
        expect(result.tldr, contains('Task is on track.'));
        expect(result.tldr, isNot(contains('Achieved')));
        expect(result.additional, isNotNull);
        expect(result.additional, contains('Achieved'));
        expect(result.additional, contains('What is left to do'));
      });

      test('returns full content as tldr when TLDR is the only section', () {
        const content =
            '## 📋 TLDR\n'
            'Everything is done. No remaining work.';

        final result = parseReportContent(content);

        expect(result.tldr, contains('TLDR'));
        expect(result.tldr, contains('Everything is done.'));
        expect(result.additional, isNull);
      });

      test('strips a leading h1 headline before the TLDR heading', () {
        const content =
            '# My Report\n'
            'Status: Active\n'
            '\n'
            '## 📋 TLDR\n'
            'Summary here.\n'
            '\n'
            '## ✅ Achieved\n'
            '- Item';

        final result = parseReportContent(content);

        expect(result.tldr, isNot(contains('My Report')));
        expect(result.tldr, contains('Status: Active'));
        expect(result.tldr, contains('Summary here.'));
        expect(result.tldr, isNot(contains('Achieved')));
        expect(result.additional, contains('Achieved'));
      });

      Glados(any.headingReport, ExploreConfig(numRuns: 160)).test(
        'matches generated heading-section splits',
        (report) {
          final result = parseReportContent(report.content);

          expect(result.tldr, report.expectedTldr, reason: '$report');
          expect(
            result.additional,
            report.expectedAdditional,
            reason: '$report',
          );
          expect(result.tldr, isNot(contains('# Generated Report')));
        },
        tags: 'glados',
      );
    });

    group('**TLDR:** bold prefix pattern', () {
      test('extracts bold TLDR and additional content', () {
        const content =
            '**TLDR:** Quick summary of the task.\n'
            '\n'
            '## Details\n'
            '- More info here';

        final result = parseReportContent(content);

        expect(result.tldr, contains('TLDR:'));
        expect(result.tldr, contains('Quick summary'));
        expect(result.additional, isNotNull);
        expect(result.additional, contains('Details'));
      });

      test(
        'returns all as tldr when no additional content after bold TLDR',
        () {
          const content = '**TLDR:** Just this one line.';

          final result = parseReportContent(content);

          expect(result.tldr, contains('Just this one line.'));
          expect(result.additional, isNull);
        },
      );

      Glados(any.boldReport, ExploreConfig(numRuns: 160)).test(
        'matches generated bold-prefix splits',
        (report) {
          final result = parseReportContent(report.content);

          expect(result.tldr, report.expectedTldr, reason: '$report');
          expect(
            result.additional,
            report.expectedAdditional,
            reason: '$report',
          );
          expect(result.tldr, isNot(contains('# Generated Report')));
        },
        tags: 'glados',
      );
    });

    group('first paragraph fallback', () {
      test('uses first paragraph as tldr when no TLDR markers found', () {
        const content =
            'This is a plain report.\n'
            '\n'
            'Second paragraph with details.\n'
            '\n'
            'Third paragraph.';

        final result = parseReportContent(content);

        expect(result.tldr, 'This is a plain report.');
        expect(result.additional, isNotNull);
        expect(result.additional, contains('Second paragraph'));
        expect(result.additional, contains('Third paragraph'));
      });

      test('returns single paragraph as tldr with null additional', () {
        const content = 'Just one paragraph, no breaks.';

        final result = parseReportContent(content);

        expect(result.tldr, 'Just one paragraph, no breaks.');
        expect(result.additional, isNull);
      });

      Glados(any.paragraphReport, ExploreConfig(numRuns: 160)).test(
        'matches generated paragraph fallback splits',
        (report) {
          final result = parseReportContent(report.content);

          expect(result.tldr, report.expectedTldr, reason: '$report');
          expect(
            result.additional,
            report.expectedAdditional,
            reason: '$report',
          );
          expect(result.tldr, isNot(contains('# Generated Report')));
        },
        tags: 'glados',
      );
    });

    group('precedence', () {
      test('heading pattern takes priority over bold prefix', () {
        const content =
            '**TLDR:** Bold version.\n'
            '\n'
            '## 📋 TLDR\n'
            'Heading version.\n'
            '\n'
            '## ✅ Achieved\n'
            '- Done';

        final result = parseReportContent(content);

        // Heading pattern matches first, includes everything before it
        expect(result.tldr, contains('Heading version.'));
        expect(result.additional, contains('Achieved'));
      });
    });
  });
}
