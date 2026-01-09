import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/whats_new/model/whats_new_release.dart';
import 'package:lotti/features/whats_new/util/whats_new_markdown_parser.dart';

void main() {
  group('WhatsNewMarkdownParser', () {
    const baseUrl = 'https://example.com/whats-new';
    final release = WhatsNewRelease(
      version: '0.9.980',
      date: DateTime(2026, 1, 7),
      title: 'January Update',
      folder: '0.9.980',
    );

    test('parses markdown with header and sections', () {
      const markdown = '''
# January Update
*Released: January 7, 2026*

---

## New Feature

This is the first section.

---

## Bug Fixes

This is the second section.
''';

      final content = WhatsNewMarkdownParser.parse(
        markdown: markdown,
        release: release,
        baseUrl: baseUrl,
      );

      expect(content.release, equals(release));
      expect(content.headerMarkdown, contains('January Update'));
      expect(content.headerMarkdown, contains('Released: January 7, 2026'));
      expect(content.sections, hasLength(2));
      expect(content.sections[0], contains('New Feature'));
      expect(content.sections[1], contains('Bug Fixes'));
    });

    test('handles markdown with no sections (header only)', () {
      const markdown = '''
# Simple Update
Just a header with no sections.
''';

      final content = WhatsNewMarkdownParser.parse(
        markdown: markdown,
        release: release,
        baseUrl: baseUrl,
      );

      expect(content.headerMarkdown, contains('Simple Update'));
      expect(content.sections, isEmpty);
    });

    test('resolves relative image URLs to absolute URLs', () {
      const markdown = '''
# Update

![Screenshot](screenshot.png)

---

## Feature

![Feature Image](images/feature.png)
''';

      final content = WhatsNewMarkdownParser.parse(
        markdown: markdown,
        release: release,
        baseUrl: baseUrl,
      );

      expect(
        content.headerMarkdown,
        contains('![Screenshot]($baseUrl/${release.folder}/screenshot.png)'),
      );
      expect(
        content.sections[0],
        contains(
            '![Feature Image]($baseUrl/${release.folder}/images/feature.png)'),
      );
    });

    test('preserves absolute URLs', () {
      const markdown = '''
# Update

![External](https://external.com/image.png)

---

## Content

![HTTP Image](http://example.com/img.png)
''';

      final content = WhatsNewMarkdownParser.parse(
        markdown: markdown,
        release: release,
        baseUrl: baseUrl,
      );

      expect(
        content.headerMarkdown,
        contains('![External](https://external.com/image.png)'),
      );
      expect(
        content.sections[0],
        contains('![HTTP Image](http://example.com/img.png)'),
      );
    });

    test('filters empty sections', () {
      const markdown = '''
# Header

---

---

## Valid Section

---

''';

      final content = WhatsNewMarkdownParser.parse(
        markdown: markdown,
        release: release,
        baseUrl: baseUrl,
      );

      expect(content.sections, hasLength(1));
      expect(content.sections[0], contains('Valid Section'));
    });

    test('handles CRLF line endings', () {
      const markdown = '# Header\r\n\r\n---\r\n\r\n## Section';

      final content = WhatsNewMarkdownParser.parse(
        markdown: markdown,
        release: release,
        baseUrl: baseUrl,
      );

      expect(content.headerMarkdown, equals('# Header'));
      expect(content.sections, hasLength(1));
      expect(content.sections[0], contains('Section'));
    });

    test('constructs banner image URL', () {
      const markdown = '# Header';

      final content = WhatsNewMarkdownParser.parse(
        markdown: markdown,
        release: release,
        baseUrl: baseUrl,
      );

      expect(
        content.bannerImageUrl,
        equals('$baseUrl/${release.folder}/banner.jpg'),
      );
    });

    test('handles empty markdown', () {
      const markdown = '';

      final content = WhatsNewMarkdownParser.parse(
        markdown: markdown,
        release: release,
        baseUrl: baseUrl,
      );

      expect(content.headerMarkdown, isEmpty);
      expect(content.sections, isEmpty);
    });

    test('trims whitespace from sections', () {
      const markdown = '''
   # Header with leading space

---

   ## Section with spaces

''';

      final content = WhatsNewMarkdownParser.parse(
        markdown: markdown,
        release: release,
        baseUrl: baseUrl,
      );

      expect(content.headerMarkdown, equals('# Header with leading space'));
      expect(content.sections[0], equals('## Section with spaces'));
    });
  });
}
