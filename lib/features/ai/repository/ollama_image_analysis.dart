part of 'ollama_inference_repository.dart';

/// Image-analysis path of [OllamaInferenceRepository].
extension OllamaImageAnalysis on OllamaInferenceRepository {
  /// Generate image analysis using Ollama's chat API
  ///
  /// This method handles the specific requirements for Ollama image analysis:
  /// - Validates input parameters
  /// - Uses the unified /api/chat endpoint with image support
  /// - Handles Ollama-specific response format
  /// - Provides comprehensive error handling
  Stream<CreateChatCompletionStreamResponse> generateWithImagesImpl({
    required String prompt,
    required String model,
    required double temperature,
    required List<String> images,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    String? systemMessage,
  }) {
    // Validate inputs
    _validateOllamaRequest(
      prompt: prompt,
      model: model,
      temperature: temperature,
      maxCompletionTokens: maxCompletionTokens,
    );
    if (images.isEmpty) {
      throw Exception('At least one image is required');
    }

    // Warm up the model if this is an image analysis request
    if (images.isNotEmpty) {
      warmUpModel(model, provider.baseUrl);
    }

    // Build messages with images for chat endpoint
    final messages = [
      if (systemMessage != null)
        {
          'role': 'system',
          'content': systemMessage,
        },
      {
        'role': 'user',
        'content': prompt,
        'images': images,
      },
    ];

    final requestBody = {
      'model': model,
      'messages': messages,
      'stream': true, // Use streaming for consistency
      'options': {
        'temperature': temperature,
        'num_predict': ?maxCompletionTokens,
      },
    };

    final timeout = Duration(
      seconds: images.isNotEmpty
          ? ollamaImageAnalysisTimeoutSeconds
          : ollamaDefaultTimeoutSeconds,
    );

    return _streamChatRequest(
      requestBody: requestBody,
      timeout: timeout,
      retryContext: 'Ollama image analysis',
      timeoutErrorMessage:
          'Request timed out after ${timeout.inSeconds} seconds. This can happen when the model is loading for the first time or is very large. Please try again - subsequent requests should be faster.',
      provider: provider,
      model: model,
    );
  }

  /// Generate text using Ollama's unified chat API
  ///
  /// This method uses the /api/chat endpoint for all text generation,
  /// with optional tool support for models that have function calling capabilities.
}
