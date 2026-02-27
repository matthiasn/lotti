import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/report_content_parser.dart';

void main() {
  group('parseReportContent', () {
    test('returns empty tldr and null additional for empty content', () {
      final result = parseReportContent('');
      expect(result.tldr, '');
      expect(result.additional, isNull);
    });

    group('## 📋 TLDR heading pattern', () {
      test('extracts TLDR and additional when both present', () {
        const content = '## 📋 TLDR\n'
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
        const content = '## 📋 TLDR\n'
            'Everything is done. No remaining work.';

        final result = parseReportContent(content);

        expect(result.tldr, contains('TLDR'));
        expect(result.tldr, contains('Everything is done.'));
        expect(result.additional, isNull);
      });

      test('includes content before TLDR heading in tldr portion', () {
        const content = '# My Report\n'
            'Status: Active\n'
            '\n'
            '## 📋 TLDR\n'
            'Summary here.\n'
            '\n'
            '## ✅ Achieved\n'
            '- Item';

        final result = parseReportContent(content);

        // The tldr includes everything up to the next ## heading
        expect(result.tldr, contains('My Report'));
        expect(result.tldr, contains('Summary here.'));
        expect(result.tldr, isNot(contains('Achieved')));
        expect(result.additional, contains('Achieved'));
      });
    });

    group('**TLDR:** bold prefix pattern', () {
      test('extracts bold TLDR and additional content', () {
        const content = '**TLDR:** Quick summary of the task.\n'
            '\n'
            '## Details\n'
            '- More info here';

        final result = parseReportContent(content);

        expect(result.tldr, contains('TLDR:'));
        expect(result.tldr, contains('Quick summary'));
        expect(result.additional, isNotNull);
        expect(result.additional, contains('Details'));
      });

      test('returns all as tldr when no additional content after bold TLDR',
          () {
        const content = '**TLDR:** Just this one line.';

        final result = parseReportContent(content);

        expect(result.tldr, contains('Just this one line.'));
        expect(result.additional, isNull);
      });
    });

    group('first paragraph fallback', () {
      test('uses first paragraph as tldr when no TLDR markers found', () {
        const content = 'This is a plain report.\n'
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
    });

    group('precedence', () {
      test('heading pattern takes priority over bold prefix', () {
        const content = '**TLDR:** Bold version.\n'
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
