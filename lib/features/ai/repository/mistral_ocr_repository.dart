import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

/// Repository for Mistral OCR via the dedicated `/v1/ocr` endpoint.
///
/// Mistral OCR models (`mistral-ocr-*`) are NOT chat-completion models —
/// posting them to `/v1/chat/completions` returns `invalid_model`. They take a
/// document (here, a base64-encoded image) on `/v1/ocr` and return per-page
/// Markdown. This repository adapts that response into the streamed
/// chat-completion shape the skill runner already consumes, so running the
/// "Analyze Image" skill with an OCR model yields the extracted text appended
/// to the image entry instead of a 400.
class MistralOcrRepository {
  MistralOcrRepository({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client(),
      _shouldCloseClient = httpClient == null;

  final http.Client _httpClient;

  /// Whether this repository created [_httpClient] itself. An injected client
  /// (e.g. the one shared across the sibling repositories in
  /// `CloudInferenceRepository`) is owned by the caller and must not be closed
  /// here.
  final bool _shouldCloseClient;

  static const _providerName = 'MistralOcrRepository';
  static const _uuid = Uuid();

  /// Default timeout applied to each individual `/v1/ocr` request (i.e. per
  /// image), not to the whole [extractText] call. OCR over a document image can
  /// take a while, so this is generous. The dominant "Analyze Image" path sends
  /// a single image; a multi-image entry runs its requests concurrently, so the
  /// worst-case wall time is a single `timeout` rather than the sum.
  static const defaultTimeout = Duration(seconds: 120);

  /// Closes [_httpClient], but only when this repository created it. An
  /// injected client is the caller's to dispose.
  void close() {
    if (_shouldCloseClient) {
      _httpClient.close();
    }
  }

  /// Whether [model] is a Mistral OCR model that must use `/v1/ocr` rather than
  /// chat completions. The caller also gates on `InferenceProviderType.mistral`,
  /// so this name check can't misfire on a same-named model from another
  /// provider.
  static bool isMistralOcrModel(String model) =>
      model.toLowerCase().contains('ocr');

  /// Runs OCR over [images] (base64-encoded JPEG) and emits the combined
  /// Markdown as a single streamed chat-completion chunk.
  ///
  /// Each image is sent as its own `/v1/ocr` request (concurrently across
  /// images), and the per-page Markdown is concatenated in image order, with
  /// figure placeholders like `![img-0.jpeg](img-0.jpeg)` stripped (see
  /// [_stripImageReferences]). The prompt/system message from the calling
  /// skill is intentionally ignored — the OCR endpoint only extracts text and
  /// takes no instructions.
  ///
  /// Error surface (matches the sibling transcription/inference repositories):
  /// argument validation throws [ArgumentError] **synchronously**, before the
  /// stream is created; operational failures (HTTP, parse, timeout) surface as
  /// a [MistralOcrException] **on the returned stream**. A caller that only
  /// attaches `handleError` must therefore also guard the synchronous case.
  Stream<CreateChatCompletionStreamResponse> extractText({
    required String model,
    required List<String> images,
    required String baseUrl,
    required String apiKey,
    Duration timeout = defaultTimeout,
  }) {
    final trimmedModel = model.trim();
    if (trimmedModel.isEmpty) {
      throw ArgumentError('Model name cannot be empty');
    }
    if (images.isEmpty) {
      throw ArgumentError('No image data to OCR');
    }
    if (baseUrl.trim().isEmpty) {
      throw ArgumentError('Base URL cannot be empty');
    }
    if (apiKey.trim().isEmpty) {
      throw ArgumentError('API key cannot be empty');
    }

    return Stream.fromFuture(
      _extractAll(
        model: trimmedModel,
        images: images,
        baseUrl: baseUrl.trim(),
        apiKey: apiKey.trim(),
        timeout: timeout,
      ),
    ).asBroadcastStream();
  }

  Future<CreateChatCompletionStreamResponse> _extractAll({
    required String model,
    required List<String> images,
    required String baseUrl,
    required String apiKey,
    required Duration timeout,
  }) async {
    final uri = _ocrUri(baseUrl);
    developer.log(
      'Running Mistral OCR on ${images.length} image(s) via '
      '${_redactedEndpoint(uri)} with model $model',
      name: _providerName,
    );

    // Each image's OCR request is independent, so run them concurrently and
    // keep the results in image order (Future.wait preserves input order).
    final results = await Future.wait(
      images.map(
        (image) => _extractOne(
          uri: uri,
          model: model,
          apiKey: apiKey,
          image: image,
          timeout: timeout,
        ),
      ),
    );

    final sections = results
        .map((markdown) => markdown.trim())
        .where((markdown) => markdown.isNotEmpty)
        .toList();

    return CreateChatCompletionStreamResponse(
      id: 'mistral-ocr-${_uuid.v4()}',
      choices: [
        ChatCompletionStreamResponseChoice(
          delta: ChatCompletionStreamResponseDelta(
            content: sections.join('\n\n'),
          ),
          index: 0,
        ),
      ],
      object: 'chat.completion.chunk',
      created: 0,
    );
  }

  Future<String> _extractOne({
    required Uri uri,
    required String model,
    required String apiKey,
    required String image,
    required Duration timeout,
  }) async {
    try {
      final response = await _httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              'document': {
                'type': 'image_url',
                'image_url': 'data:image/jpeg;base64,$image',
              },
              'include_image_base64': false,
            }),
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MistralOcrException(
          _extractErrorMessage(response.body, response.statusCode),
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const MistralOcrException(
          'Mistral OCR response must be a JSON object',
        );
      }
      final pages = decoded['pages'];
      if (pages is! List) {
        throw const MistralOcrException(
          'Mistral OCR response is missing a pages[] array',
        );
      }

      final markdown = <String>[];
      for (final page in pages) {
        if (page is Map<String, dynamic>) {
          final text = page['markdown'];
          if (text is String) {
            final stripped = _stripImageReferences(text);
            if (stripped.isNotEmpty) {
              markdown.add(stripped);
            }
          }
        }
      }
      return markdown.join('\n\n');
    } on MistralOcrException {
      rethrow;
    } on TimeoutException catch (e) {
      throw MistralOcrException(
        'Mistral OCR request timed out',
        originalError: e,
      );
    } on FormatException catch (e) {
      throw MistralOcrException(
        'Mistral OCR response was not valid JSON',
        originalError: e,
      );
    } on Exception catch (e) {
      // Keep transport details (which can carry the request URI) out of the
      // user-facing message. `originalError` retains the exception for
      // diagnostics/logging only.
      throw MistralOcrException(
        'Failed to run Mistral OCR',
        originalError: e,
      );
    }
  }

  /// Figure regions the OCR model detects inside the page are referenced in
  /// the markdown as image placeholders, e.g. `![img-0.jpeg](img-0.jpeg)`,
  /// resolved by the response's `pages[].images[]` entries. The request sets
  /// `include_image_base64: false` and those entries are never processed, so
  /// the placeholders would land in the journal text as broken image links.
  static final _imageRefPattern = RegExp(r'!\[[^\]]*\]\([^)]*\)');
  static final _multiNewlinePattern = RegExp(r'(?:\r?\n){3,}');

  /// Removes figure placeholders (see [_imageRefPattern]) and collapses the
  /// blank lines they leave behind.
  static String _stripImageReferences(String markdown) => markdown
      .replaceAll(_imageRefPattern, '')
      .replaceAll(_multiNewlinePattern, '\n\n')
      .trim();

  static Uri _ocrUri(String baseUrl) {
    final baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');
    return baseUri.resolve('ocr');
  }

  /// Host + path only — never the full URI, which from a user-configured base
  /// URL could carry credentials/tokens.
  static String _redactedEndpoint(Uri uri) => '${uri.host}${uri.path}';

  static String _extractErrorMessage(String body, int statusCode) {
    final fallback = 'Mistral OCR error (HTTP $statusCode)';
    if (body.isEmpty) return fallback;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          if (message is String && message.isNotEmpty) return message;
        }
        if (error is String && error.isNotEmpty) return error;
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } catch (_) {
      // Fall through to a clipped raw body.
    }
    return body.length > 160 ? '${body.substring(0, 160)}…' : body;
  }
}

class MistralOcrException implements Exception {
  const MistralOcrException(
    this.message, {
    this.statusCode,
    this.originalError,
  });

  final String message;
  final int? statusCode;
  final Object? originalError;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' (HTTP $statusCode)';
    final cause = originalError == null ? '' : ': $originalError';
    return 'MistralOcrException$status: $message$cause';
  }
}
