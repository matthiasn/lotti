import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/gemini_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';

class _FakeStreamClient extends http.BaseClient {
  _FakeStreamClient(this._statusCode, this._lines);

  final int _statusCode;
  final List<String> _lines;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final data = _lines.map((l) => utf8.encode('$l\n') as List<int>);
    final stream = Stream<List<int>>.fromIterable(data);
    return http.StreamedResponse(stream, _statusCode, headers: {
      'content-type': 'application/json',
    });
  }
}

void main() {
  group('GeminiInferenceRepository streaming', () {
    test('surfaces thinking block then text', () async {
      final line = jsonEncode({
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'thought': 'Consider tasks... '},
                {'thought': 'Check dates.'},
                {'text': 'Here are your tasks.'},
              ],
            }
          }
        ]
      });

      final client = _FakeStreamClient(200, [line]);
      final repo = GeminiInferenceRepository(httpClient: client);

      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'test',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      final stream = repo.generateText(
        prompt: 'Summarize tasks',
        model: 'gemini-2.5-flash',
        temperature: 0.7,
        thinkingConfig: const GeminiThinkingConfig(
          thinkingBudget: 1024,
          includeThoughts: true,
        ),
        provider: provider,
      );

      final events = await stream.toList();
      expect(events.length, 2);
      // First is thinking block
      final firstContent = events[0].choices!.first.delta!.content!;
      expect(firstContent.startsWith('<thinking>'), isTrue);
      expect(firstContent.contains('Consider tasks...'), isTrue);
      expect(firstContent.contains('Check dates.'), isTrue);
      // Second is regular text
      final secondContent = events[1].choices!.first.delta!.content!;
      expect(secondContent, 'Here are your tasks.');
    });

    test('maps functionCall to tool call chunk', () async {
      final line = jsonEncode({
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {
                  'functionCall': {
                    'name': 'get_task_summaries',
                    'args': {
                      'start_date': '2024-01-01',
                      'end_date': '2024-01-02'
                    }
                  }
                }
              ],
            }
          }
        ]
      });

      final client = _FakeStreamClient(200, [line]);
      final repo = GeminiInferenceRepository(httpClient: client);

      final provider = AiConfigInferenceProvider(
        id: 'prov',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'test',
        name: 'Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      final stream = repo.generateText(
        prompt: 'Summarize tasks',
        model: 'gemini-2.5-flash',
        temperature: 0.7,
        thinkingConfig: const GeminiThinkingConfig(
          thinkingBudget: 1024,
        ),
        provider: provider,
      );

      final events = await stream.toList();
      expect(events.length, 1);
      final delta = events.first.choices!.first.delta!;
      expect(delta.toolCalls, isNotNull);
      expect(delta.toolCalls!.length, 1);
      final call = delta.toolCalls!.first;
      expect(call.function!.name, 'get_task_summaries');
      expect(call.function!.arguments, contains('start_date'));
    });
  });
}
