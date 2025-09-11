import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/repository/gemini_utils.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  group('GeminiUtils.isFlashModel', () {
    test('detects flash variants case-insensitively', () {
      expect(GeminiUtils.isFlashModel('gemini-1.5-FLASH'), isTrue);
      expect(GeminiUtils.isFlashModel('GEMINI-2.0-FLASH-LITE'), isTrue);
      expect(GeminiUtils.isFlashModel('gemini-2.0-pro'), isFalse);
      expect(GeminiUtils.isFlashModel('pro-exp-0806'), isFalse);
    });
  });

  group('GeminiUtils.build* URIs', () {
    test('stream URI ignores baseUrl path and preserves port', () {
      final uri = GeminiUtils.buildStreamGenerateContentUri(
        baseUrl: 'http://localhost:8080/openai/v1beta',
        model: 'gemini-2.0-pro-exp-02-05',
        apiKey: 'abc',
      );
      expect(uri.scheme, 'http');
      expect(uri.host, 'localhost');
      expect(uri.port, 8080);
      expect(
        uri.path,
        '/v1beta/models/gemini-2.0-pro-exp-02-05:streamGenerateContent',
      );
      expect(uri.queryParameters['key'], 'abc');
    });

    test('non-stream URI handles models/ prefix and trailing slash', () {
      final uri = GeminiUtils.buildGenerateContentUri(
        baseUrl: 'https://generativelanguage.googleapis.com',
        model: 'models/gemini-2.0-flash/ ',
        apiKey: 'xyz',
      );
      expect(
        uri.path,
        '/v1beta/models/gemini-2.0-flash:generateContent',
      );
      expect(uri.queryParameters['key'], 'xyz');
    });
  });

  group('GeminiUtils.buildRequestBody', () {
    test('includes prompt, temperature, thinking and optional fields', () {
      final body = GeminiUtils.buildRequestBody(
        prompt: 'Hello',
        temperature: 0.2,
        thinkingConfig: const GeminiThinkingConfig(
          thinkingBudget: 256,
          includeThoughts: true,
        ),
        systemMessage: 'System prompt',
        maxTokens: 123,
      );
      expect(body['contents'], isA<List<dynamic>>());
      final contents = (body['contents'] as List).cast<Map<String, dynamic>>();
      final firstParts =
          (contents.first['parts'] as List).cast<Map<String, dynamic>>();
      expect(firstParts[0]['text'], 'Hello');

      final generationConfig = body['generationConfig'] as Map<String, dynamic>;
      expect(generationConfig['temperature'], 0.2);
      expect(generationConfig['maxOutputTokens'], 123);
      expect(generationConfig['thinkingConfig'], isA<Map<String, dynamic>>());

      final systemInstruction =
          body['systemInstruction'] as Map<String, dynamic>;
      final systemParts =
          (systemInstruction['parts'] as List).cast<Map<String, dynamic>>();
      expect(systemParts[0]['text'], 'System prompt');
      expect(body.containsKey('tools'), isFalse);
    });

    test('maps ChatCompletionTool list to functionDeclarations', () {
      const tools = [
        ChatCompletionTool(
          type: ChatCompletionToolType.function,
          function: FunctionObject(
            name: 'lookup',
            description: 'lookup something',
          ),
        ),
        ChatCompletionTool(
          type: ChatCompletionToolType.function,
          function: FunctionObject(
            name: 'search',
          ),
        ),
      ];

      final body = GeminiUtils.buildRequestBody(
        prompt: 'Hello',
        temperature: 1,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 64),
        tools: tools,
      );

      expect(body['tools'], isA<List<dynamic>>());
      final toolsArr = (body['tools'] as List).cast<Map<String, dynamic>>();
      final toolsList = toolsArr.first;
      final fns = toolsList['functionDeclarations'] as List<dynamic>;
      expect(fns.length, 2);
      final fn0 = fns[0] as Map<String, dynamic>;
      final fn1 = fns[1] as Map<String, dynamic>;
      expect(fn0['name'], 'lookup');
      expect(fn0['description'], 'lookup something');
      expect(fn1['name'], 'search');
      // parameters omitted when null
      expect(fn0.containsKey('parameters'), isFalse);
    });
  });

  group('GeminiUtils.stripLeadingFraming', () {
    test('removes SSE data: lines and JSON array wrappers', () {
      const input = 'data: test\n  data: ignore\n [ {"a":1} , {"b":2}]';
      final out = GeminiUtils.stripLeadingFraming(input);
      expect(out.startsWith('{'), isTrue);
      // Verify we stripped at least one opening bracket
      expect(out, startsWith('{"a"'));
    });

    test('returns partial data unchanged when no newline', () {
      const input = 'data: partial line without newline';
      final out = GeminiUtils.stripLeadingFraming(input);
      expect(out, input.trimLeft());
    });
  });
}
