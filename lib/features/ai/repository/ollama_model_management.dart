part of 'ollama_inference_repository.dart';

/// Model management + warm-up path of [OllamaInferenceRepository],
/// matching the standalone `ollama_model_management_test.dart` mirror.
extension OllamaModelManagement on OllamaInferenceRepository {
  /// Install a model in Ollama with progress tracking
  Stream<OllamaPullProgress> installModelImpl(
    String modelName,
    String baseUrl,
  ) async* {
    // 10 minutes for large models.
    const installTimeout = Duration(minutes: 10);

    final request = http.Request(
      'POST',
      Uri.parse('$baseUrl/api/pull'),
    );
    request.headers['Content-Type'] = ollamaContentType;
    request.body = jsonEncode({'name': modelName});

    // Use a timeout for the entire send operation
    final streamedResponse = await _retryWithExponentialBackoff(
      operation: () async {
        return _httpClient.send(request).timeout(installTimeout);
      },
      maxRetries: 3,
      baseDelay: OllamaInferenceRepository.retryBaseDelay,
      context: 'model installation',
      timeoutErrorMessage:
          'Model installation timed out after ${installTimeout.inMinutes} minutes. This may be due to a slow connection or a large model. Please check your internet connection and try again.',
      networkErrorMessage:
          'Network error during model installation. Please check your connection and that the Ollama server is running.',
    );

    if (streamedResponse.statusCode != httpStatusOk) {
      developer.log(
        'Model installation failed: HTTP ${streamedResponse.statusCode}',
        name: 'OllamaInferenceRepository',
      );
      throw Exception(
        'Failed to start model installation. (HTTP ${streamedResponse.statusCode}) Please check your Ollama installation and try again.',
      );
    }

    await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
      final lines = chunk.split('\n').where((line) => line.trim().isNotEmpty);

      for (final line in lines) {
        Map<String, dynamic> data;
        try {
          data = jsonDecode(line) as Map<String, dynamic>;
        } catch (e) {
          // Skip malformed JSON lines
          continue;
        }

        if (data.containsKey('error')) {
          final errorMessage = data['error'] as String;
          developer.log(
            'Model installation error: $errorMessage',
            name: 'OllamaInferenceRepository',
          );
          // Provide more specific error messages
          if (errorMessage.contains('not found')) {
            throw Exception('Model installation failed: Model not found.');
          } else if (errorMessage.contains('disk full')) {
            throw Exception(
              'Model installation failed: Disk is full. Please free up space and try again.',
            );
          } else if (errorMessage.contains('connection refused')) {
            throw Exception(
              'Model installation failed: Connection refused. Is the Ollama server running?',
            );
          } else {
            throw Exception(
              'Model installation failed. Please check your Ollama installation and try again.',
            );
          }
        }

        final status = data['status'] is String ? data['status'] as String : '';
        final total = data['total'] is int ? data['total'] as int : 0;
        final completed = data['completed'] is int
            ? data['completed'] as int
            : 0;

        yield OllamaPullProgress(
          status: status,
          progress: total > 0 ? (completed / total) : 0.0,
        );
      }
    }
  }

  /// Warm up a model by sending a simple request to load it into memory
  Future<void> warmUpModelImpl(String modelName, String baseUrl) async {
    try {
      developer.log(
        'Warming up model: $modelName',
        name: 'OllamaInferenceRepository',
      );

      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl$ollamaChatEndpoint'),
            headers: {
              'Content-Type': ollamaContentType,
            },
            body: jsonEncode({
              'model': modelName,
              'messages': [
                {'role': 'user', 'content': 'Hello'},
              ],
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != httpStatusOk) {
        developer.log(
          'Warning: Model warm-up failed: HTTP ${response.statusCode}',
          name: 'OllamaInferenceRepository',
        );
        return; // Don't throw, just log warning
      }

      developer.log(
        'Model warmed up successfully: $modelName',
        name: 'OllamaInferenceRepository',
      );
    } catch (e, stackTrace) {
      developer.log(
        'Warning: Model warm-up failed',
        error: e,
        stackTrace: stackTrace,
        name: 'OllamaInferenceRepository',
      );
      // Don't throw, just log warning
    }
  }
}
