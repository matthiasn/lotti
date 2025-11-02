import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Mock Gemma service for testing purposes
///
/// Provides a controllable mock implementation of the Gemma 3n local service
/// that can simulate various response scenarios for comprehensive testing.
class MockGemmaService {
  // API Configuration Constants
  static const String defaultBaseUrl = 'http://localhost:11343';
  static const String healthEndpoint = '/health';
  static const String chatCompletionsEndpoint = '/v1/chat/completions';
  static const String modelsEndpoint = '/v1/models';
  static const String modelPullEndpoint = '/v1/models/pull';
  static const String modelLoadEndpoint = '/v1/models/load';

  // Service Configuration Constants
  static const int defaultPort = 11343;
  // Allowed test delay: overridable to reduce runtime in tests
  static Duration streamingDelay = const Duration(milliseconds: 5);
  static Duration downloadStepDelay = const Duration(milliseconds: 5);
  static Duration simulatedDownloadDelay = const Duration(milliseconds: 10);

  static void setFastDelays({
    Duration? stream,
    Duration? step,
    Duration? simulate,
  }) {
    if (stream != null) streamingDelay = stream;
    if (step != null) downloadStepDelay = step;
    if (simulate != null) simulatedDownloadDelay = simulate;
  }

  // Response Template Constants
  static const String healthyStatus = 'healthy';
  static const String defaultVersion = '1.0.0';
  static const String modelObjectType = 'model';
  static const String listObjectType = 'list';
  static const String googleOwner = 'google';
  static const String assistantRole = 'assistant';
  static const String stopFinishReason = 'stop';
  static const String chatCompletionObject = 'chat.completion';
  static const String chatCompletionChunkObject = 'chat.completion.chunk';
  static const String testIdPrefix = 'chatcmpl-test-';
  static const String finalChunkId = 'chatcmpl-test-final';
  static const String doneStreamMarker = '[DONE]';

  // Error Message Constants
  static const String modelNotFoundType = 'model_not_found';
  static const String modelNotFoundCode = 'model_not_found';
  static const String modelNotAvailableCode = 'model_not_available';
  static const String modelNotFoundTemplate = 'Model "%s" not found';
  static const String modelNotDownloadedMessage =
      'Model not downloaded. Use /v1/models/pull to download.';
  static const String modelNameRequiredError = 'Model name is required';
  static const String unknownModelTemplate = 'Unknown model: %s';
  static const String notFoundError = 'Not found';
  static const String internalServerError = 'Internal server error';

  // Mock Response Constants
  static const String defaultAudioTranscription =
      'This is a sample transcription of the provided audio content. The speaker mentions important details about the upcoming project deadline.';
  static const String contextualAudioTranscription =
      'Based on the provided context, I can hear someone discussing the meeting scheduled for tomorrow at 3 PM in the conference room.';
  static const String helloResponse = 'Hello! How can I assist you today?';
  static const String testResponse =
      'This is a test response from the Gemma 3n model.';
  static const String defaultTextResponse =
      'I understand your request and am ready to help with any questions or tasks you have.';

  // HTTP Headers Constants
  static const String contentTypeHeader = 'Content-Type';
  static const String jsonContentType = 'application/json';
  static const String eventStreamContentType = 'text/event-stream';
  static const String cacheControlHeader = 'Cache-Control';
  static const String noCacheValue = 'no-cache';
  static const String connectionHeader = 'Connection';
  static const String keepAliveValue = 'keep-alive';

  // Token Usage Constants
  static const int defaultPromptTokens = 50;

  // Model Download Progress Constants
  static const String checkingStatus = 'checking';
  static const String downloadingStatus = 'downloading';
  static const String validatingStatus = 'validating';
  static const String completeStatus = 'complete';
  static const String successStatus = 'success';
  static const String loadedStatus = 'loaded';
  static const String checkingMessage = 'Checking model availability...';
  static const String downloadingMessage = 'Downloading model files...';
  static const String validatingMessage = 'Validating downloaded files...';
  static const String downloadCompleteMessage = 'Model downloaded successfully';
  static const String loadedMessage = 'Model loaded successfully';
  static const String cpuDevice = 'cpu';
  static const String defaultMemoryUsage = '2.1GB';

  // Progress Values
  static const double progressStart = 0;
  static const double progressQuarter = 25;
  static const double progressHalf = 50;
  static const double progressThreeQuarter = 75;
  static const double progressNinetyPercent = 90;
  static const double progressComplete = 100;

  late HttpServer _server;
  late StreamController<String> _sseController;
  late StreamSubscription<HttpRequest> _serverSubscription;
  bool _isRunning = false;
  int _port = defaultPort;

  /// Available models for testing
  static const Map<String, Map<String, dynamic>> availableModels = {
    'google/gemma-3n-E2B-it': {
      'id': 'google/gemma-3n-E2B-it',
      'name': 'Gemma 3n E2B',
      'variant': 'E2B',
      'size_gb': 2.0,
      'is_available': true,
      'is_loaded': false,
    },
    'google/gemma-3n-E4B-it': {
      'id': 'google/gemma-3n-E4B-it',
      'name': 'Gemma 3n E4B',
      'variant': 'E4B',
      'size_gb': 4.0,
      'is_available': false,
      'is_loaded': false,
    },
  };

  Map<String, dynamic> _modelStates = Map.from(availableModels);

  /// Start the mock service
  Future<void> start({int? port}) async {
    if (_isRunning) return;

    _port = port ?? defaultPort;
    _sseController = StreamController<String>.broadcast();

    try {
      _server = await HttpServer.bind('localhost', _port);
      _isRunning = true;

      _serverSubscription = _server.listen((HttpRequest request) async {
        await _handleRequest(request);
      });

      // Mock Gemma service started on port
    } catch (e) {
      // Failed to start mock service on port: $e
      rethrow;
    }
  }

  /// Stop the mock service
  Future<void> stop() async {
    if (!_isRunning) return;

    await _serverSubscription.cancel();
    await _server.close();
    await _sseController.close();
    _isRunning = false;
  }

  /// Reset all model states to defaults
  void resetModelStates() {
    _modelStates = Map.from(availableModels);
  }

  /// Set model availability
  void setModelAvailable(String modelId, {required bool isAvailable}) {
    if (_modelStates.containsKey(modelId)) {
      (_modelStates[modelId]! as Map<String, dynamic>)['is_available'] =
          isAvailable;
    }
  }

  /// Set model loaded state
  void setModelLoaded(String modelId, {required bool isLoaded}) {
    if (_modelStates.containsKey(modelId)) {
      (_modelStates[modelId]! as Map<String, dynamic>)['is_loaded'] = isLoaded;
    }
  }

  /// Get current port
  int get port => _port;

  /// Check if service is running
  bool get isRunning => _isRunning;

  /// Get base URL
  String get baseUrl => 'http://localhost:$_port';

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    // final method = request.method;

    // Mock Gemma: $method $path

    try {
      switch (path) {
        case healthEndpoint:
          await _handleHealthCheck(request);
        case chatCompletionsEndpoint:
          await _handleChatCompletions(request);
        case modelsEndpoint:
          await _handleListModels(request);
        case modelPullEndpoint:
          await _handleModelPull(request);
        case modelLoadEndpoint:
          await _handleModelLoad(request);
        default:
          await _sendResponse(request, 404, {'error': notFoundError});
      }
    } catch (e) {
      // Error handling request: $e
      await _sendResponse(request, 500, {'error': internalServerError});
    }
  }

  Future<void> _handleHealthCheck(HttpRequest request) async {
    final response = {
      'status': healthyStatus,
      'version': defaultVersion,
      'models_available': _modelStates.values
          .where((model) =>
              (model as Map<String, dynamic>)['is_available'] == true)
          .length,
      'models_loaded': _modelStates.values
          .where(
              (model) => (model as Map<String, dynamic>)['is_loaded'] == true)
          .length,
    };

    await _sendResponse(request, 200, response);
  }

  Future<void> _handleChatCompletions(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();

    late final Map<String, dynamic> requestData;
    try {
      requestData = jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      await _sendResponse(request, 400, {
        'error': {
          'message': 'Invalid JSON in request body',
          'type': 'invalid_request',
          'code': 'json_parse_error',
        }
      });
      return;
    }

    final model = requestData['model'] as String?;
    final isStreaming = requestData['stream'] as bool? ?? false;

    // Normalize model name
    final normalizedModel =
        model?.startsWith('google/') ?? false ? model! : 'google/$model';

    // Check if model is available and loaded
    if (!_modelStates.containsKey(normalizedModel)) {
      await _sendResponse(request, 400, {
        'error': {
          'message': modelNotFoundTemplate.replaceFirst('%s', normalizedModel),
          'type': modelNotFoundType,
          'code': modelNotFoundCode,
        }
      });
      return;
    }

    final modelState = _modelStates[normalizedModel] as Map<String, dynamic>?;
    if (modelState?['is_available'] != true) {
      await _sendResponse(request, 400, {
        'error': {
          'message': modelNotDownloadedMessage,
          'type': modelNotFoundType,
          'code': modelNotAvailableCode,
        }
      });
      return;
    }

    if (modelState?['is_loaded'] != true) {
      // Auto-load model for convenience in tests
      modelState?['is_loaded'] = true;
    }

    if (isStreaming) {
      await _handleStreamingResponse(request, requestData);
    } else {
      await _handleNonStreamingResponse(request, requestData);
    }
  }

  Future<void> _handleStreamingResponse(
      HttpRequest request, Map<String, dynamic> requestData) async {
    request.response.headers.set(contentTypeHeader, eventStreamContentType);
    request.response.headers.set(cacheControlHeader, noCacheValue);
    request.response.headers.set(connectionHeader, keepAliveValue);

    // Simulate streaming chunks
    final chunks = _generateResponseChunks(requestData);

    for (final chunk in chunks) {
      request.response.write('data: ${jsonEncode(chunk)}\n\n');
      await Future<void>.delayed(streamingDelay);
    }

    request.response.write('data: $doneStreamMarker\n\n');
    await request.response.close();
  }

  Future<void> _handleNonStreamingResponse(
      HttpRequest request, Map<String, dynamic> requestData) async {
    final response = _generateCompleteResponse(requestData);
    await _sendResponse(request, 200, response);
  }

  List<Map<String, dynamic>> _generateResponseChunks(
      Map<String, dynamic> requestData) {
    final content = _generateResponseContent(requestData);
    final words = content.split(' ');
    final timestamp = DateTime.now();
    final timestampMillis = timestamp.millisecondsSinceEpoch;
    final timestampSeconds = timestampMillis ~/ 1000;
    final model = requestData['model'];

    final chunks = <Map<String, dynamic>>[];
    for (var i = 0; i < words.length; i++) {
      final word = i == 0 ? words[i] : ' ${words[i]}';
      chunks.add({
        'id': '$testIdPrefix$timestampMillis',
        'object': chatCompletionChunkObject,
        'created': timestampSeconds,
        'model': model,
        'choices': [
          {
            'index': 0,
            'delta': {'content': word},
            'finish_reason': null,
          }
        ],
      });
    }

    // Final chunk
    chunks.add({
      'id': finalChunkId,
      'object': chatCompletionChunkObject,
      'created': timestampSeconds,
      'model': model,
      'choices': [
        {
          'index': 0,
          'delta': <String, dynamic>{},
          'finish_reason': stopFinishReason,
        }
      ],
    });

    return chunks;
  }

  Map<String, dynamic> _generateCompleteResponse(
      Map<String, dynamic> requestData) {
    final content = _generateResponseContent(requestData);
    final timestamp = DateTime.now();
    final timestampMillis = timestamp.millisecondsSinceEpoch;
    final timestampSeconds = timestampMillis ~/ 1000;
    final completionTokens = content.split(' ').length;
    final totalTokens = defaultPromptTokens + completionTokens;

    return {
      'id': '$testIdPrefix$timestampMillis',
      'object': chatCompletionObject,
      'created': timestampSeconds,
      'model': requestData['model'],
      'choices': [
        {
          'index': 0,
          'message': {
            'role': assistantRole,
            'content': content,
          },
          'finish_reason': stopFinishReason,
        }
      ],
      'usage': {
        'prompt_tokens': defaultPromptTokens,
        'completion_tokens': completionTokens,
        'total_tokens': totalTokens,
      },
    };
  }

  String _generateResponseContent(Map<String, dynamic> requestData) {
    final hasAudio = requestData.containsKey('audio');
    final messages = requestData['messages'] as List<dynamic>? ?? [];
    final userMessage =
        messages.isNotEmpty ? messages.last as Map<String, dynamic> : null;
    final userContent = userMessage?['content'] as String? ?? '';
    final lowerContent = userContent.toLowerCase();

    if (hasAudio) {
      // Audio transcription
      if (lowerContent.contains('context:')) {
        return contextualAudioTranscription;
      } else {
        return defaultAudioTranscription;
      }
    } else {
      // Text generation
      if (lowerContent.contains('hello')) {
        return helloResponse;
      } else if (lowerContent.contains('test')) {
        return testResponse;
      } else {
        return defaultTextResponse;
      }
    }
  }

  Future<void> _handleListModels(HttpRequest request) async {
    final timestampSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final models = _modelStates.values
        .map((model) => {
              'id': (model as Map<String, dynamic>)['id'],
              'object': modelObjectType,
              'owned_by': googleOwner,
              'created': timestampSeconds,
              'permission': <String>[],
            })
        .toList();

    await _sendResponse(request, 200, {
      'object': listObjectType,
      'data': models,
    });
  }

  Future<void> _handleModelPull(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final requestData = jsonDecode(body) as Map<String, dynamic>;
    final modelName = requestData['model_name'] as String?;
    final isStreaming = requestData['stream'] as bool? ?? true;

    if (modelName == null) {
      await _sendResponse(request, 400, {'error': modelNameRequiredError});
      return;
    }

    final normalizedModel =
        modelName.startsWith('google/') ? modelName : 'google/$modelName';

    if (!_modelStates.containsKey(normalizedModel)) {
      await _sendResponse(request, 400,
          {'error': unknownModelTemplate.replaceFirst('%s', normalizedModel)});
      return;
    }

    if (isStreaming) {
      await _streamModelDownload(request, normalizedModel);
    } else {
      await _completeModelDownload(request, normalizedModel);
    }
  }

  Future<void> _streamModelDownload(HttpRequest request, String modelId) async {
    request.response.headers.set(contentTypeHeader, eventStreamContentType);
    request.response.headers.set(cacheControlHeader, noCacheValue);

    final progressSteps = _getDownloadProgressSteps();

    for (final step in progressSteps) {
      request.response.write('data: ${jsonEncode(step)}\n\n');
      await Future<void>.delayed(downloadStepDelay);
    }

    // Mark model as available
    setModelAvailable(modelId, isAvailable: true);

    await request.response.close();
  }

  /// Get standardized download progress steps
  List<Map<String, dynamic>> _getDownloadProgressSteps() {
    return [
      {
        'status': checkingStatus,
        'message': checkingMessage,
        'progress': progressStart,
      },
      {
        'status': downloadingStatus,
        'message': downloadingMessage,
        'progress': progressQuarter,
      },
      {
        'status': downloadingStatus,
        'message': downloadingMessage,
        'progress': progressHalf,
      },
      {
        'status': downloadingStatus,
        'message': downloadingMessage,
        'progress': progressThreeQuarter,
      },
      {
        'status': validatingStatus,
        'message': validatingMessage,
        'progress': progressNinetyPercent,
      },
      {
        'status': completeStatus,
        'message': downloadCompleteMessage,
        'progress': progressComplete,
      },
    ];
  }

  Future<void> _completeModelDownload(
      HttpRequest request, String modelId) async {
    // Simulate download time
    await Future<void>.delayed(simulatedDownloadDelay);

    setModelAvailable(modelId, isAvailable: true);

    await _sendResponse(request, 200, {
      'status': successStatus,
      'message': downloadCompleteMessage,
      'model_id': modelId,
    });
  }

  Future<void> _handleModelLoad(HttpRequest request) async {
    // For simplicity, just mark all available models as loaded
    for (final modelState in _modelStates.values) {
      if ((modelState as Map<String, dynamic>)['is_available'] == true) {
        modelState['is_loaded'] = true;
      }
    }

    await _sendResponse(request, 200, {
      'status': loadedStatus,
      'message': loadedMessage,
      'device': cpuDevice,
      'memory_usage': defaultMemoryUsage,
    });
  }

  Future<void> _sendResponse(
      HttpRequest request, int statusCode, Map<String, dynamic> data) async {
    request.response.statusCode = statusCode;
    request.response.headers.set(contentTypeHeader, jsonContentType);
    request.response.write(jsonEncode(data));
    await request.response.close();
  }

  /// Mock helpers for unit tests
  void mockHealthCheckSuccess() {
    // This would be used by HTTP client mocks
  }

  void mockHealthCheckFailure() {
    // This would be used by HTTP client mocks
  }

  void mockTranscriptionSuccess(String transcription) {
    // This would be used by HTTP client mocks
  }

  void mockTranscriptionFailure(String error, {int statusCode = 500}) {
    // This would be used by HTTP client mocks
  }

  void mockModelNotFound(String modelId) {
    // This would be used by HTTP client mocks
  }

  void mockModelDownloadProgress() {
    // This would be used by HTTP client mocks
  }
}
