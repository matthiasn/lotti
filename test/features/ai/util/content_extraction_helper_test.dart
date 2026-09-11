import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/inference.dart';
import 'package:lotti/features/ai/repository/openai_compat_adapter.dart';
import 'package:lotti/features/ai/util/content_extraction_helper.dart';

enum _GeneratedContentPartShape {
  text,
  paddedText,
  emptyText,
  whitespace,
  image,
}

class _GeneratedContentPartSpec {
  const _GeneratedContentPartSpec({
    required this.shape,
    required this.seed,
  });

  final _GeneratedContentPartShape shape;
  final int seed;

  String get text => switch (shape) {
    _GeneratedContentPartShape.text => 'generated-text-$seed',
    _GeneratedContentPartShape.paddedText => ' generated-text-$seed ',
    _GeneratedContentPartShape.emptyText => '',
    _GeneratedContentPartShape.whitespace => '   ',
    _GeneratedContentPartShape.image => '',
  };

  String get expectedText => text.trim().isEmpty ? '' : text;

  LottiContentPart toPart() => switch (shape) {
    _GeneratedContentPartShape.image => LottiContentPart.image(
      'data:image/jpeg;base64,generated-$seed',
    ),
    _ => LottiContentPart.text(text),
  };

  @override
  String toString() {
    return '_GeneratedContentPartSpec(shape: $shape, seed: $seed)';
  }
}

class _GeneratedUserContentScenario {
  const _GeneratedUserContentScenario({
    required this.asString,
    required this.stringSeed,
    required this.parts,
  });

  final bool asString;
  final int stringSeed;
  final List<_GeneratedContentPartSpec> parts;

  LottiUserContent get content => asString
      ? LottiUserContent.text('generated-string-$stringSeed')
      : LottiUserContent.parts(
          parts.map((part) => part.toPart()).toList(),
        );

  String get expected => asString
      ? 'generated-string-$stringSeed'
      : parts.map((part) => part.expectedText).join();

  @override
  String toString() {
    return '_GeneratedUserContentScenario('
        'asString: $asString, stringSeed: $stringSeed, parts: $parts)';
  }
}

extension _AnyGeneratedUserContentScenario on glados.Any {
  glados.Generator<_GeneratedContentPartShape> get contentPartShape =>
      glados.AnyUtils(this).choose(_GeneratedContentPartShape.values);

  glados.Generator<_GeneratedContentPartSpec> get contentPartSpec =>
      glados.CombinableAny(this).combine2(
        contentPartShape,
        glados.IntAnys(this).intInRange(0, 10000),
        (
          _GeneratedContentPartShape shape,
          int seed,
        ) => _GeneratedContentPartSpec(shape: shape, seed: seed),
      );

  glados.Generator<_GeneratedUserContentScenario> get userContentScenario =>
      glados.CombinableAny(this).combine3(
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(0, 10000),
        glados.ListAnys(this).listWithLengthInRange(0, 8, contentPartSpec),
        (
          bool asString,
          int stringSeed,
          List<_GeneratedContentPartSpec> parts,
        ) => _GeneratedUserContentScenario(
          asString: asString,
          stringSeed: stringSeed,
          parts: parts,
        ),
      );
}

void main() {
  group('ContentExtractionHelper', () {
    group('extractTextFromUserContent', () {
      test('should extract text from string content', () {
        const content = LottiUserContent.text('Hello world');
        final result = ContentExtractionHelper.extractTextFromUserContent(
          content,
        );
        expect(result, 'Hello world');
      });

      test('should extract and join text from multiple content parts', () {
        const content = LottiUserContent.parts([
          LottiContentPart.text('Hello'),
          LottiContentPart.text(
            ' ',
          ), // This will be skipped as it's only whitespace
          LottiContentPart.text('world'),
        ]);
        final result = ContentExtractionHelper.extractTextFromUserContent(
          content,
        );
        expect(result, 'Helloworld');
      });

      test('should skip empty text parts', () {
        const content = LottiUserContent.parts([
          LottiContentPart.text('Hello'),
          LottiContentPart.text(''),
          LottiContentPart.text('   '), // Only whitespace
          LottiContentPart.text('world'),
        ]);
        final result = ContentExtractionHelper.extractTextFromUserContent(
          content,
        );
        expect(result, 'Helloworld');
      });

      test('should preserve spacing in non-empty text parts', () {
        const content = LottiUserContent.parts([
          LottiContentPart.text('Hello '), // Trailing space preserved
          LottiContentPart.text(' world'), // Leading space preserved
        ]);
        final result = ContentExtractionHelper.extractTextFromUserContent(
          content,
        );
        expect(result, 'Hello  world');
      });

      test('should join parts with meaningful spacing', () {
        const content = LottiUserContent.parts([
          LottiContentPart.text('The quick brown fox'),
          LottiContentPart.text(' jumps over '),
          LottiContentPart.text('the lazy dog'),
        ]);
        final result = ContentExtractionHelper.extractTextFromUserContent(
          content,
        );
        expect(result, 'The quick brown fox jumps over the lazy dog');
      });

      test('should handle empty parts list', () {
        const content = LottiUserContent.parts([]);
        final result = ContentExtractionHelper.extractTextFromUserContent(
          content,
        );
        expect(result, '');
      });

      test('should handle mixed content types (skip non-text parts)', () {
        // Create a content with mixed types (text and image)
        const content = LottiUserContent.parts([
          LottiContentPart.text('Describe this image:'),
          LottiContentPart.image('data:image/jpeg;base64,somebase64data'),
          LottiContentPart.text(' Please be detailed.'),
        ]);
        final result = ContentExtractionHelper.extractTextFromUserContent(
          content,
        );
        expect(result, 'Describe this image: Please be detailed.');
      });

      test('should handle content with only non-text parts', () {
        const content = LottiUserContent.parts([
          LottiContentPart.image('data:image/jpeg;base64,somebase64data'),
        ]);
        final result = ContentExtractionHelper.extractTextFromUserContent(
          content,
        );
        expect(result, '');
      });

      test('should handle content with newlines and special characters', () {
        const content = LottiUserContent.parts([
          LottiContentPart.text('Line 1\n'),
          LottiContentPart.text('Line 2\t'),
          LottiContentPart.text(r'Special: @#$%'),
        ]);
        final result = ContentExtractionHelper.extractTextFromUserContent(
          content,
        );
        expect(result, 'Line 1\nLine 2\tSpecial: @#\$%');
      });

      test('should return toString() for unknown content value types', () {
        // This is a edge case test for the fallback behavior
        // In practice, the value should always be String or List
        // but we test the fallback just in case
        const content = LottiUserContent.text(
          'Test fallback',
        );
        final result = ContentExtractionHelper.extractTextFromUserContent(
          content,
        );
        expect(result, 'Test fallback');
      });

      test('content parts serialize to a stable OpenAI wire schema', () {
        // The wire schema lives in the adapter now, but downstream providers
        // still depend on it, so it is asserted through the adapter rather
        // than dropped.
        Map<String, dynamic> partJson(LottiContentPart part) {
          final message = openAiMessagesJson([
            LottiMessage.userParts([part]),
          ]).single;
          return (message['content']! as List).single as Map<String, dynamic>;
        }

        final json = partJson(const LottiContentPart.text('Hello world'));
        expect(json['type'], 'text');
        expect(json['text'], 'Hello world');

        final emptyJson = partJson(const LottiContentPart.text(''));
        expect(emptyJson['type'], 'text');
        expect(emptyJson['text'], '');

        final specialJson = partJson(
          const LottiContentPart.text('Line 1\nLine 2\t@#\$%'),
        );
        expect(specialJson['type'], 'text');
        expect(specialJson['text'], 'Line 1\nLine 2\t@#\$%');
      });

      glados.Glados(
        glados.any.userContentScenario,
        glados.ExploreConfig(numRuns: 180),
      ).test('matches generated mixed content extraction semantics', (
        scenario,
      ) {
        expect(
          ContentExtractionHelper.extractTextFromUserContent(scenario.content),
          scenario.expected,
          reason: '$scenario',
        );
      }, tags: 'glados');
    });
  });
}
