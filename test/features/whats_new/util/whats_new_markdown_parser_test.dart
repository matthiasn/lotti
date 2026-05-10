import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    show
        Any,
        AnyUtils,
        BoolAny,
        CombinableAny,
        ExploreConfig,
        Generator,
        Glados,
        IntAnys,
        ListAnys,
        any;
import 'package:lotti/features/whats_new/model/whats_new_release.dart';
import 'package:lotti/features/whats_new/util/whats_new_markdown_parser.dart';

enum _GeneratedImagePathKind {
  relative,
  relativeStartingHttp,
  httpAbsolute,
  httpsAbsolute,
  uppercaseHttpAbsolute,
  dataUri,
  fileUri,
  protocolRelative,
}

class _GeneratedImagePath {
  const _GeneratedImagePath({
    required this.kind,
    required this.seed,
  });

  final _GeneratedImagePathKind kind;
  final int seed;

  String get rawPath {
    return switch (kind) {
      _GeneratedImagePathKind.relative => 'images/generated-$seed.png',
      _GeneratedImagePathKind.relativeStartingHttp =>
        'http-assets/generated-$seed.png',
      _GeneratedImagePathKind.httpAbsolute =>
        'http://cdn.example.com/generated-$seed.png',
      _GeneratedImagePathKind.httpsAbsolute =>
        'https://cdn.example.com/generated-$seed.png',
      _GeneratedImagePathKind.uppercaseHttpAbsolute =>
        'HTTPS://cdn.example.com/generated-$seed.png',
      _GeneratedImagePathKind.dataUri => 'data:image/png;base64,AAAA$seed',
      _GeneratedImagePathKind.fileUri => 'file:///tmp/generated-$seed.png',
      _GeneratedImagePathKind.protocolRelative =>
        '//cdn.example.com/generated-$seed.png',
    };
  }

  String expectedResolvedPath({
    required String baseUrl,
    required String folder,
  }) {
    return switch (kind) {
      _GeneratedImagePathKind.httpAbsolute ||
      _GeneratedImagePathKind.httpsAbsolute ||
      _GeneratedImagePathKind.uppercaseHttpAbsolute ||
      _GeneratedImagePathKind.dataUri ||
      _GeneratedImagePathKind.fileUri ||
      _GeneratedImagePathKind.protocolRelative => rawPath,
      _ => '$baseUrl/$folder/$rawPath',
    };
  }

  @override
  String toString() {
    return '_GeneratedImagePath(kind: $kind, seed: $seed)';
  }
}

class _GeneratedWhatsNewMarkdown {
  const _GeneratedWhatsNewMarkdown({
    required this.headerImage,
    required this.sectionImages,
    required this.useCrLf,
  });

  final _GeneratedImagePath headerImage;
  final List<_GeneratedImagePath> sectionImages;
  final bool useCrLf;

  String get markdown {
    final lines = [
      '# Generated Update',
      '',
      '![Header image](${headerImage.rawPath})',
      for (var index = 0; index < sectionImages.length; index++) ...[
        '',
        '---',
        '',
        '## Section $index',
        '![Section image $index](${sectionImages[index].rawPath})',
      ],
    ];
    final value = lines.join('\n');
    return useCrLf ? value.replaceAll('\n', '\r\n') : value;
  }

  @override
  String toString() {
    return '_GeneratedWhatsNewMarkdown('
        'headerImage: $headerImage, '
        'sectionImages: $sectionImages, '
        'useCrLf: $useCrLf)';
  }
}

extension _AnyWhatsNewMarkdown on Any {
  Generator<_GeneratedImagePathKind> get imagePathKind =>
      choose(_GeneratedImagePathKind.values);

  Generator<_GeneratedImagePath> get imagePath => combine2(
    imagePathKind,
    intInRange(0, 10000),
    (_GeneratedImagePathKind kind, int seed) => _GeneratedImagePath(
      kind: kind,
      seed: seed,
    ),
  );

  Generator<_GeneratedWhatsNewMarkdown> get whatsNewMarkdown => combine3(
    imagePath,
    listWithLengthInRange(0, 5, imagePath),
    this.bool,
    (
      _GeneratedImagePath headerImage,
      List<_GeneratedImagePath> sectionImages,
      bool useCrLf,
    ) => _GeneratedWhatsNewMarkdown(
      headerImage: headerImage,
      sectionImages: sectionImages,
      useCrLf: useCrLf,
    ),
  );
}

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
          '![Feature Image]($baseUrl/${release.folder}/images/feature.png)',
        ),
      );
    });

    test('preserves non-HTTP absolute URIs and protocol-relative URLs', () {
      const markdown = '''
# Update

![Inline data](data:image/png;base64,iVBORw0KGgo=)

---

## File

![Local file](file:///tmp/local.png)

---

## Protocol relative

![CDN](//cdn.example.com/image.png)

---

## Mailto

![Mail](mailto:hello@example.com)
''';

      final content = WhatsNewMarkdownParser.parse(
        markdown: markdown,
        release: release,
        baseUrl: baseUrl,
      );

      expect(
        content.headerMarkdown,
        contains('![Inline data](data:image/png;base64,iVBORw0KGgo=)'),
      );
      expect(
        content.sections[0],
        contains('![Local file](file:///tmp/local.png)'),
      );
      expect(
        content.sections[1],
        contains('![CDN](//cdn.example.com/image.png)'),
      );
      expect(
        content.sections[2],
        contains('![Mail](mailto:hello@example.com)'),
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

    Glados(any.whatsNewMarkdown, ExploreConfig(numRuns: 160)).test(
      'resolves generated image paths and preserves absolute HTTP URLs',
      (scenario) {
        final content = WhatsNewMarkdownParser.parse(
          markdown: scenario.markdown,
          release: release,
          baseUrl: baseUrl,
        );

        expect(
          content.headerMarkdown,
          contains(
            '![Header image](${scenario.headerImage.expectedResolvedPath(
              baseUrl: baseUrl,
              folder: release.folder,
            )})',
          ),
          reason: '$scenario',
        );
        expect(content.sections, hasLength(scenario.sectionImages.length));

        for (var index = 0; index < scenario.sectionImages.length; index++) {
          expect(
            content.sections[index],
            contains(
              '![Section image $index](${scenario.sectionImages[index].expectedResolvedPath(
                baseUrl: baseUrl,
                folder: release.folder,
              )})',
            ),
            reason: '$scenario',
          );
        }
      },
      tags: 'glados',
    );
  });
}
