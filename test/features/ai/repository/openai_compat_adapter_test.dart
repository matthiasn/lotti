import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/ai/model/inference.dart';
import 'package:lotti/features/ai/model/inference_error.dart';
import 'package:lotti/features/ai/repository/openai_compat_adapter.dart';
import 'package:openai_dart/openai_dart.dart';

/// The adapter is the only place `openai_dart` is allowed to appear, so this
/// is the only test that imports it. What matters here is the wire shape the
/// providers actually receive, and that nothing Lotti models is dropped on the
/// way out or in.
void main() {
  group('toOpenAiMessage', () {
    test('maps every role onto the matching wire role', () {
      final json = openAiMessagesJson([
        const LottiMessage.system('sys'),
        const LottiMessage.developer('dev'),
        LottiMessage.userText('hi'),
        const LottiMessage.assistant(content: 'hello'),
        const LottiMessage.tool(toolCallId: 'call-1', content: 'result'),
      ]);

      expect(json.map((m) => m['role']), [
        'system',
        'developer',
        'user',
        'assistant',
        'tool',
      ]);
    });

    test(
      'sends text-only user content as a bare string, not a parts array',
      () {
        // Some OpenAI-compatible providers reject a one-element parts array
        // where they accept a string, so the distinction has to survive.
        final asString = openAiMessagesJson([
          LottiMessage.userText('hi'),
        ]).single;
        expect(asString['content'], 'hi');

        final asParts = openAiMessagesJson([
          LottiMessage.userParts(const [LottiContentPart.text('hi')]),
        ]).single;
        expect(asParts['content'], isA<List<dynamic>>());
      },
    );

    test('maps each content part to its wire representation', () {
      final content =
          openAiMessagesJson([
                LottiMessage.userParts(const [
                  LottiContentPart.text('describe'),
                  LottiContentPart.image('data:image/jpeg;base64,abc'),
                  LottiContentPart.audio(
                    base64Data: 'AAAA',
                    format: LottiAudioFormat.wav,
                  ),
                ]),
              ]).single['content']!
              as List<dynamic>;

      final text = content[0] as Map<String, dynamic>;
      expect(text['type'], 'text');
      expect(text['text'], 'describe');

      final image = content[1] as Map<String, dynamic>;
      expect(image['type'], 'image_url');
      expect(
        (image['image_url']! as Map<String, dynamic>)['url'],
        'data:image/jpeg;base64,abc',
      );

      final audio = content[2] as Map<String, dynamic>;
      expect(audio['type'], 'input_audio');
      final inputAudio = audio['input_audio']! as Map<String, dynamic>;
      expect(inputAudio['data'], 'AAAA');
      expect(inputAudio['format'], 'wav');
    });

    test('nests a flattened tool call back into the wire shape', () {
      final assistant = openAiMessagesJson([
        const LottiMessage.assistant(
          toolCalls: [
            LottiToolCall(
              id: 'call-1',
              name: 'lookup',
              arguments: '{"q":"x"}',
            ),
          ],
        ),
      ]).single;

      final toolCall =
          (assistant['tool_calls']! as List<dynamic>).single
              as Map<String, dynamic>;
      expect(toolCall['id'], 'call-1');
      expect(toolCall['type'], 'function');
      final function = toolCall['function']! as Map<String, dynamic>;
      expect(function['name'], 'lookup');
      expect(function['arguments'], '{"q":"x"}');
    });
  });

  group('toOpenAiTool', () {
    test('carries name, description and parameters', () {
      final json = openAiToolsJson([
        const LottiTool(
          name: 'lookup',
          description: 'Looks things up',
          parameters: {'type': 'object'},
        ),
      ]).single;

      expect(json['type'], 'function');
      final function = json['function']! as Map<String, dynamic>;
      expect(function['name'], 'lookup');
      expect(function['description'], 'Looks things up');
      expect(function['parameters'], {'type': 'object'});
    });

    test('omits parameters entirely for a tool that takes none', () {
      // Providers differ on whether they accept an empty schema, so the field
      // is absent rather than `{}`.
      final function =
          openAiToolsJson([const LottiTool(name: 'ping')]).single['function']!
              as Map<String, dynamic>;
      expect(function.containsKey('parameters'), isFalse);
    });
  });

  group('toOpenAiToolChoice', () {
    test('maps each policy to its wire value', () {
      expect(toOpenAiToolChoice(null), isNull);
      expect(
        toOpenAiToolChoice(const LottiToolChoice.auto())?.toJson(),
        'auto',
      );
      expect(
        toOpenAiToolChoice(const LottiToolChoice.none())?.toJson(),
        'none',
      );
      expect(
        toOpenAiToolChoice(const LottiToolChoice.required())?.toJson(),
        'required',
      );
    });

    test('names the single tool a specific choice pins the call to', () {
      final json =
          toOpenAiToolChoice(const LottiToolChoice.specific('lookup'))!.toJson()
              as Map<String, dynamic>;
      expect(json['type'], 'function');
      expect((json['function']! as Map<String, dynamic>)['name'], 'lookup');
    });
  });

  group('toOpenAiRequest', () {
    test('carries the sampling and limit knobs onto the request', () {
      final request = toOpenAiRequest(
        LottiInferenceRequest(
          messages: [LottiMessage.userText('hi')],
          model: 'gpt-4o',
          temperature: 0.3,
          maxCompletionTokens: 128,
          maxTokens: 256,
          reasoningEffort: LottiReasoningEffort.high,
        ),
      );

      expect(request.model, 'gpt-4o');
      expect(request.temperature, 0.3);
      expect(request.maxCompletionTokens, 128);
      expect(request.maxTokens, 256);
      expect(request.reasoningEffort, ReasoningEffort.high);
    });

    test('never sends verbosity, which Gemini rejects', () {
      final json = openAiRequestJson(
        LottiInferenceRequest(
          messages: [LottiMessage.userText('hi')],
          model: 'gemini-2.5-pro',
        ),
      );
      expect(json.containsKey('verbosity'), isFalse);
    });

    test('takes the streaming flag from the caller, not the request', () {
      // The client picks streaming by which method is called, so only the
      // raw-JSON path needs the flag — and it passes it explicitly.
      final request = LottiInferenceRequest(
        messages: [LottiMessage.userText('hi')],
        model: 'gpt-4o',
      );
      expect(openAiRequestJson(request)['stream'], isTrue);
      expect(openAiRequestJson(request, stream: false)['stream'], isFalse);
    });

    test('maps each reasoning effort level', () {
      expect(toOpenAiReasoningEffort(null), isNull);
      expect(
        toOpenAiReasoningEffort(LottiReasoningEffort.minimal),
        ReasoningEffort.minimal,
      );
      expect(
        toOpenAiReasoningEffort(LottiReasoningEffort.low),
        ReasoningEffort.low,
      );
      expect(
        toOpenAiReasoningEffort(LottiReasoningEffort.medium),
        ReasoningEffort.medium,
      );
      expect(
        toOpenAiReasoningEffort(LottiReasoningEffort.high),
        ReasoningEffort.high,
      );
    });
  });

  group('fromOpenAiStreamEvent', () {
    test('carries text, tool-call fragments and finish reason inward', () {
      final chunk = fromOpenAiStreamEvent(
        const ChatStreamEvent(
          id: 'resp-1',
          created: 1710500000,
          model: 'gpt-4o',
          choices: [
            ChatStreamChoice(
              index: 0,
              delta: ChatDelta(
                content: 'hel',
                toolCalls: [
                  ToolCallDelta(
                    index: 0,
                    id: 'call-1',
                    function: FunctionCallDelta(
                      name: 'lookup',
                      arguments: '{"q":',
                    ),
                  ),
                ],
              ),
              finishReason: FinishReason.toolCalls,
            ),
          ],
        ),
      );

      expect(chunk.id, 'resp-1');
      expect(chunk.created, 1710500000);
      expect(chunk.model, 'gpt-4o');

      final choice = chunk.choices!.single;
      expect(choice.index, 0);
      expect(choice.finishReason, LottiFinishReason.toolCalls);
      expect(choice.delta!.content, 'hel');

      final fragment = choice.delta!.toolCalls!.single;
      expect(fragment.id, 'call-1');
      expect(fragment.index, 0);
      expect(fragment.name, 'lookup');
      expect(fragment.arguments, '{"q":');
    });

    test('defaults a missing choice index to 0 for compatible providers', () {
      // The spec makes `index` optional and providers such as OpenRouter omit
      // it; a single-choice stream is the common case.
      final chunk = fromOpenAiStreamEvent(
        const ChatStreamEvent(
          choices: [ChatStreamChoice(delta: ChatDelta(content: 'x'))],
        ),
      );
      expect(chunk.choices!.single.index, 0);
    });

    test('flattens the nested usage details consumers read', () {
      final chunk = fromOpenAiStreamEvent(
        const ChatStreamEvent(
          usage: Usage(
            promptTokens: 10,
            completionTokens: 4,
            totalTokens: 14,
            promptTokensDetails: PromptTokensDetails(
              cachedTokens: 6,
              audioTokens: 2,
            ),
            completionTokensDetails: CompletionTokensDetails(
              reasoningTokens: 3,
              audioTokens: 1,
            ),
          ),
        ),
      );

      final usage = chunk.usage!;
      expect(usage.promptTokens, 10);
      expect(usage.completionTokens, 4);
      expect(usage.totalTokens, 14);
      expect(usage.cachedInputTokens, 6);
      expect(usage.reasoningTokens, 3);
      expect(usage.promptAudioTokens, 2);
      expect(usage.completionAudioTokens, 1);
    });

    test('collapses the legacy function_call finish reason onto toolCalls', () {
      expect(
        fromOpenAiFinishReason(FinishReason.functionCall),
        LottiFinishReason.toolCalls,
      );
      expect(
        fromOpenAiFinishReason(FinishReason.stop),
        LottiFinishReason.stop,
      );
      expect(
        fromOpenAiFinishReason(FinishReason.length),
        LottiFinishReason.length,
      );
      expect(
        fromOpenAiFinishReason(FinishReason.contentFilter),
        LottiFinishReason.contentFilter,
      );
      expect(fromOpenAiFinishReason(null), isNull);
    });
  });

  group('openAiErrorType', () {
    test('classifies each client exception Lotti acts on', () {
      expect(
        openAiErrorType(const AuthenticationException(message: 'bad key')),
        InferenceErrorType.authentication,
      );
      expect(
        openAiErrorType(const PermissionDeniedException(message: 'no')),
        InferenceErrorType.authentication,
      );
      expect(
        openAiErrorType(const RateLimitException(message: 'slow down')),
        InferenceErrorType.rateLimit,
      );
      expect(
        openAiErrorType(const RequestTimeoutException(message: 'too slow')),
        InferenceErrorType.timeout,
      );
      expect(
        openAiErrorType(const ConnectionException(message: 'unreachable')),
        InferenceErrorType.networkConnection,
      );
      expect(
        openAiErrorType(const NotFoundException(message: 'no model')),
        InferenceErrorType.invalidRequest,
      );
      expect(
        openAiErrorType(
          const InternalServerException(message: 'boom', statusCode: 500),
        ),
        InferenceErrorType.serverError,
      );
    });

    test('returns null for anything that did not come from the client', () {
      // Ollama and raw HTTP failures must keep falling through to the
      // message-shaped classification.
      expect(openAiErrorType(Exception('HTTP 500')), isNull);
      expect(openAiErrorType('HTTP 404 Not Found'), isNull);
    });

    test('a status the library does not specialize still reads as a client '
        'failure', () {
      // `unknown` rather than null: the call did fail at the provider, so it
      // must not be mistaken for a local error.
      expect(
        openAiErrorType(
          const ApiException(message: 'teapot', statusCode: 418),
        ),
        InferenceErrorType.unknown,
      );
    });
  });

  group('isUnparseableStreamFrame', () {
    test('recognizes a frame the client could not read', () {
      // Keep-alive frames carry no choices; one of them must not end the
      // stream, which is what the ping filter relies on.
      expect(
        isUnparseableStreamFrame(const ParseException(message: 'bad frame')),
        isTrue,
      );
      expect(
        isUnparseableStreamFrame(const RateLimitException(message: 'slow')),
        isFalse,
      );
      expect(isUnparseableStreamFrame(Exception('boom')), isFalse);
    });
  });

  group('OpenAiCompatInferenceClient', () {
    OpenAIClient clientReturning(String sseBody) => OpenAIClient.withApiKey(
      'test-key',
      baseUrl: 'https://example.invalid/v1',
      httpClient: MockClient.streaming(
        (request, bodyStream) async => http.StreamedResponse(
          Stream.value(utf8.encode(sseBody)),
          200,
          headers: {'content-type': 'text/event-stream'},
        ),
      ),
    );

    test('disposes its transport once the stream completes', () async {
      // Every call site builds one client per request, so a client that
      // outlives its stream leaks a connection pool.
      final client = OpenAiCompatInferenceClient.wrapping(
        clientReturning(
          'data: {"choices":[{"index":0,"delta":{"content":"hi"}}]}\n\n'
          'data: [DONE]\n\n',
        ),
      );

      final chunks = await client
          .createChatCompletionStream(
            LottiInferenceRequest(
              messages: [LottiMessage.userText('hi')],
              model: 'gpt-4o',
            ),
          )
          .toList();
      expect(chunks.single.textDelta, 'hi');

      expect(
        () => client
            .createChatCompletionStream(
              LottiInferenceRequest(
                messages: [LottiMessage.userText('again')],
                model: 'gpt-4o',
              ),
            )
            .toList(),
        throwsA(isA<StateError>()),
      );
    });

    test('disposes its transport when the consumer stops early', () async {
      final client = OpenAiCompatInferenceClient.wrapping(
        clientReturning(
          'data: {"choices":[{"index":0,"delta":{"content":"a"}}]}\n\n'
          'data: {"choices":[{"index":0,"delta":{"content":"b"}}]}\n\n'
          'data: [DONE]\n\n',
        ),
      );

      final first = await client
          .createChatCompletionStream(
            LottiInferenceRequest(
              messages: [LottiMessage.userText('hi')],
              model: 'gpt-4o',
            ),
          )
          .first;
      expect(first.textDelta, 'a');

      expect(
        () => client
            .createChatCompletionStream(
              LottiInferenceRequest(
                messages: [LottiMessage.userText('again')],
                model: 'gpt-4o',
              ),
            )
            .toList(),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('round trip', () {
    test('a conversation survives the trip out to the wire and back', () {
      final messages = [
        const LottiMessage.system('sys'),
        LottiMessage.userText('question'),
        const LottiMessage.assistant(
          content: 'thinking',
          toolCalls: [
            LottiToolCall(id: 'c1', name: 'lookup', arguments: '{}'),
          ],
        ),
        const LottiMessage.tool(toolCallId: 'c1', content: 'answer'),
      ];

      final wire = toOpenAiMessages(messages);
      expect(wire, hasLength(4));
      expect((wire[0] as SystemMessage).content, 'sys');
      expect((wire[1] as UserMessage).text, 'question');

      final assistant = wire[2] as AssistantMessage;
      expect(assistant.content, 'thinking');
      expect(assistant.toolCalls!.single.function.name, 'lookup');

      final tool = wire[3] as ToolMessage;
      expect(tool.toolCallId, 'c1');
      expect(tool.content, 'answer');
    });
  });
}
