import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/util/content_extraction_helper.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  group('ContentExtractionHelper', () {
    group('extractTextFromUserContent', () {
      test('should extract text from string content', () {
        const content = ChatCompletionUserMessageContent.string('Hello world');
        final result =
            ContentExtractionHelper.extractTextFromUserContent(content);
        expect(result, 'Hello world');
      });

      test('should extract and join text from multiple content parts', () {
        const content = ChatCompletionUserMessageContent.parts([
          ChatCompletionMessageContentPart.text(text: 'Hello'),
          ChatCompletionMessageContentPart.text(
              text: ' '), // This will be skipped as it's only whitespace
          ChatCompletionMessageContentPart.text(text: 'world'),
        ]);
        final result =
            ContentExtractionHelper.extractTextFromUserContent(content);
        expect(result, 'Helloworld');
      });

      test('should skip empty text parts', () {
        const content = ChatCompletionUserMessageContent.parts([
          ChatCompletionMessageContentPart.text(text: 'Hello'),
          ChatCompletionMessageContentPart.text(text: ''),
          ChatCompletionMessageContentPart.text(text: '   '), // Only whitespace
          ChatCompletionMessageContentPart.text(text: 'world'),
        ]);
        final result =
            ContentExtractionHelper.extractTextFromUserContent(content);
        expect(result, 'Helloworld');
      });

      test('should preserve spacing in non-empty text parts', () {
        const content = ChatCompletionUserMessageContent.parts([
          ChatCompletionMessageContentPart.text(
              text: 'Hello '), // Trailing space preserved
          ChatCompletionMessageContentPart.text(
              text: ' world'), // Leading space preserved
        ]);
        final result =
            ContentExtractionHelper.extractTextFromUserContent(content);
        expect(result, 'Hello  world');
      });

      test('should join parts with meaningful spacing', () {
        const content = ChatCompletionUserMessageContent.parts([
          ChatCompletionMessageContentPart.text(text: 'The quick brown fox'),
          ChatCompletionMessageContentPart.text(text: ' jumps over '),
          ChatCompletionMessageContentPart.text(text: 'the lazy dog'),
        ]);
        final result =
            ContentExtractionHelper.extractTextFromUserContent(content);
        expect(result, 'The quick brown fox jumps over the lazy dog');
      });

      test('should handle empty parts list', () {
        const content = ChatCompletionUserMessageContent.parts([]);
        final result =
            ContentExtractionHelper.extractTextFromUserContent(content);
        expect(result, '');
      });

      test('should handle mixed content types (skip non-text parts)', () {
        // Create a content with mixed types (text and image)
        const content = ChatCompletionUserMessageContent.parts([
          ChatCompletionMessageContentPart.text(text: 'Describe this image:'),
          ChatCompletionMessageContentPart.image(
            imageUrl: ChatCompletionMessageImageUrl(
              url: 'data:image/jpeg;base64,somebase64data',
            ),
          ),
          ChatCompletionMessageContentPart.text(text: ' Please be detailed.'),
        ]);
        final result =
            ContentExtractionHelper.extractTextFromUserContent(content);
        expect(result, 'Describe this image: Please be detailed.');
      });

      test('should handle content with only non-text parts', () {
        const content = ChatCompletionUserMessageContent.parts([
          ChatCompletionMessageContentPart.image(
            imageUrl: ChatCompletionMessageImageUrl(
              url: 'data:image/jpeg;base64,somebase64data',
            ),
          ),
        ]);
        final result =
            ContentExtractionHelper.extractTextFromUserContent(content);
        expect(result, '');
      });

      test('should handle content with newlines and special characters', () {
        const content = ChatCompletionUserMessageContent.parts([
          ChatCompletionMessageContentPart.text(text: 'Line 1\n'),
          ChatCompletionMessageContentPart.text(text: 'Line 2\t'),
          ChatCompletionMessageContentPart.text(text: r'Special: @#$%'),
        ]);
        final result =
            ContentExtractionHelper.extractTextFromUserContent(content);
        expect(result, 'Line 1\nLine 2\tSpecial: @#\$%');
      });

      test('should return toString() for unknown content value types', () {
        // This is a edge case test for the fallback behavior
        // In practice, the value should always be String or List
        // but we test the fallback just in case
        const content =
            ChatCompletionUserMessageContent.string('Test fallback');
        final result =
            ContentExtractionHelper.extractTextFromUserContent(content);
        expect(result, 'Test fallback');
      });
    });
  });
}
