import 'package:lotti/features/ai/model/inference.dart';

/// A chat-completion client, in Lotti's own terms.
///
/// Providers that speak the OpenAI wire protocol get an implementation backed
/// by `openai_dart` (see `openai_compat_adapter.dart`); the point of the
/// interface is that nothing above it — and no test double — has to name the
/// client library.
abstract class LottiInferenceClient {
  /// Streams the response to [request].
  Stream<LottiInferenceChunk> createChatCompletionStream(
    LottiInferenceRequest request,
  );

  /// Releases any connections held by the client.
  void close();
}
