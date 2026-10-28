part of 'melious_inference_repository.dart';

/// Chat-completion transport for Melious: the non-streaming request, the POST itself and tool-call parsing.
extension _MeliousChat on MeliousInferenceRepository {
  /// Non-streaming Melious chat: one raw POST that returns the full body
  /// (`usage` + `environment_impact` + `billing_cost`), buffered and re-emitted
  /// as a single synthetic stream so streaming consumers are unchanged. The
  /// parsed [MeliousCallImpact] is written to [impactCollector].
  ///
  /// Deliberate trade-off: because the whole response is buffered, callers see
  /// no incremental deltas — `onProgress` in the unified path fires only once,
  /// when the call completes (or [_chatCompletionTimeout] trips). Melious only
  /// reports impact/cost on non-streaming responses, and streaming display is
  /// not needed for the measured call sites. Cancelling the stream aborts only
  /// its HTTP request, so a query deadline does not wait for the longer backend
  /// timeout or close the shared client used by sibling requests.
  Stream<CreateChatCompletionStreamResponse> _nonStreamingChat({
    required List<ChatCompletionMessage> messages,
    required String model,
    required String baseUrl,
    required String apiKey,
    required InferenceImpactCollector impactCollector,
    double? temperature,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    ReasoningEffort? reasoningEffort,
  }) {
    final abort = Completer<void>();
    var cancelled = false;
    late final StreamController<CreateChatCompletionStreamResponse> controller;
    Future<void> run() async {
      try {
        final result = await _postChatCompletion(
          baseUrl: baseUrl,
          apiKey: apiKey,
          abortTrigger: abort.future,
          request: _helpers.createBaseRequest(
            messages: messages,
            model: model,
            temperature: temperature,
            maxCompletionTokens: maxCompletionTokens,
            tools: tools,
            toolChoice: MeliousInferenceRepository.resolveToolChoice(
              model,
              tools,
              toolChoice,
            ),
            reasoningEffort: MeliousInferenceRepository.resolveReasoningEffort(
              model,
              reasoningEffort,
            ),
            stream: false,
          ),
        );
        if (result.impact.hasData) {
          impactCollector.impact = result.impact;
        }
        if (cancelled) return;

        final id = 'melious-chat-${const Uuid().v4()}';
        controller.add(
          CreateChatCompletionStreamResponse(
            id: id,
            created: 0,
            model: model,
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                finishReason: result.finishReason,
                delta: ChatCompletionStreamResponseDelta(
                  content: result.content.isEmpty ? null : result.content,
                  toolCalls: result.toolCalls.isEmpty ? null : result.toolCalls,
                ),
              ),
            ],
          ),
        );
        // Trailing usage-only chunk, mirroring the streaming API's final usage
        // frame that consumers read token counts from.
        final usage = result.usage;
        if (usage != null) {
          controller.add(
            CreateChatCompletionStreamResponse(
              id: id,
              created: 0,
              model: model,
              choices: const [],
              usage: usage,
            ),
          );
        }
      } catch (error, stack) {
        if (!cancelled) controller.addError(error, stack);
      } finally {
        unawaited(controller.close());
      }
    }

    controller = StreamController<CreateChatCompletionStreamResponse>(
      onListen: () => unawaited(run()),
      onCancel: () {
        cancelled = true;
        if (!abort.isCompleted) abort.complete();
      },
    );
    return controller.stream;
  }

  Future<_MeliousChatResult> _postChatCompletion({
    required String baseUrl,
    required String apiKey,
    required Future<void> abortTrigger,
    required CreateChatCompletionRequest request,
    Duration timeout = MeliousInferenceRepository._chatCompletionTimeout,
  }) async {
    final uri = MeliousInferenceRepository._buildEndpointUri(
      baseUrl,
      'chat/completions',
    );
    try {
      final upload =
          http.AbortableRequest('POST', uri, abortTrigger: abortTrigger)
            ..headers.addAll({
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${apiKey.trim()}',
            })
            ..body = jsonEncode(request.toJson());
      final response = await httpClient
          .send(upload)
          .then(http.Response.fromStream)
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw InferenceHttpException(
          provider: _exceptionProvider,
          ModelCatalogMapping.extractErrorMessage(
            response.body,
            response.statusCode,
            providerLabel: 'Melious',
            maxLength: 240,
            ellipsis: '...',
          ),
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const InferenceHttpException(
          provider: _exceptionProvider,
          'Melious chat completion response must be a JSON object',
        );
      }

      final choices = decoded['choices'];
      final firstChoice =
          choices is List && choices.isNotEmpty && choices.first is Map
          ? (choices.first as Map).cast<String, dynamic>()
          : const <String, dynamic>{};
      final messageMap = firstChoice['message'] is Map
          ? (firstChoice['message'] as Map).cast<String, dynamic>()
          : const <String, dynamic>{};
      final content = messageMap['content'];

      return _MeliousChatResult(
        content: content is String ? content : '',
        finishReason: MeliousInferenceRepository._parseFinishReason(
          firstChoice['finish_reason'],
        ),
        toolCalls: _parseToolCalls(messageMap['tool_calls']),
        usage: parseCompletionUsage(decoded['usage']),
        impact: MeliousCallImpact.fromResponseJson(
          decoded,
          costCreditsDecimal: MeliousCallImpact.costDecimalFromResponseBody(
            response.body,
          ),
        ),
      );
    } on InferenceHttpException {
      rethrow;
    } on TimeoutException catch (e) {
      throw InferenceHttpException(
        provider: _exceptionProvider,
        'Melious chat completion request timed out',
        originalError: e,
      );
    } on FormatException catch (e) {
      throw InferenceHttpException(
        provider: _exceptionProvider,
        'Melious chat completion response was not valid JSON',
        originalError: e,
      );
    } on Exception catch (e) {
      throw InferenceHttpException(
        provider: _exceptionProvider,
        'Failed to complete Melious chat: $e',
        originalError: e,
      );
    }
  }

  /// Parses `message.tool_calls` into one complete chunk per call.
  ///
  /// An entry without a name is a fragment of an earlier call, not a call of
  /// its own: Melious-hosted DeepSeek can return a call as its streaming
  /// deltas — the name with empty arguments, then nameless entries carrying
  /// the JSON piece by piece. Each fragment is appended to the call with the
  /// same provider `index`, or to the previous call when it gives none. Read
  /// as one call per entry, the name lands on a call with no arguments and
  /// the caller sees only nameless calls.
  static List<ChatCompletionStreamMessageToolCallChunk> _parseToolCalls(
    Object? raw,
  ) {
    if (raw is! List) return const [];
    final calls =
        <({int position, Object? providerIndex, String id, String? name})>[];
    final arguments = <StringBuffer>[];
    for (final (position, item) in raw.indexed) {
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      final fn = map['function'] is Map
          ? (map['function'] as Map).cast<String, dynamic>()
          : const <String, dynamic>{};
      final providerIndex = map['index'];
      final id = map['id'];
      final name = fn['name'];
      final fragment = fn['arguments'];
      final hasName = name is String && name.isNotEmpty;
      final owner = hasName
          ? -1
          : providerIndex == null
          ? calls.length - 1
          : calls.lastIndexWhere((c) => c.providerIndex == providerIndex);
      if (owner >= 0) {
        if (fragment is String) arguments[owner].write(fragment);
        continue;
      }
      calls.add((
        position: position,
        providerIndex: providerIndex,
        id: id is String ? id : 'tool_$position',
        name: hasName ? name : null,
      ));
      arguments.add(StringBuffer(fragment is String ? fragment : ''));
    }
    return [
      for (final (slot, call) in calls.indexed)
        ChatCompletionStreamMessageToolCallChunk(
          index: call.position,
          id: call.id,
          function: ChatCompletionStreamMessageFunctionCall(
            name: call.name,
            arguments: arguments[slot].toString(),
          ),
        ),
    ];
  }
}
