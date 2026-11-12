import 'dart:typed_data';

import 'package:lotti/features/tts/cloud/cloud_tts_exception.dart';
import 'package:lotti/features/tts/cloud/cloud_voice_catalog.dart';

/// One provider's text-to-speech API, as the read-aloud path uses it: a
/// voice catalog to choose from, and speech in one of its voices.
///
/// The key and base URL are passed per call rather than held, the same way
/// the transcription repositories take them, so the key stays in the
/// inference-provider config and rotating it needs no re-wiring here.
/// Every failure after the request is built is a [CloudTtsException].
abstract interface class CloudTtsClient {
  /// Speaks [text] with [voiceId] on [model] and returns a WAV file's bytes,
  /// the artifact the on-device engine produces too.
  Future<Uint8List> synthesize({
    required String text,
    required String voiceId,
    required String baseUrl,
    required String apiKey,
    required String model,
  });

  /// Every voice the account can speak [model] with, and the languages each
  /// is offered for.
  Future<CloudVoiceCatalog> fetchVoices({
    required String baseUrl,
    required String apiKey,
    required String model,
  });

  /// Closes the underlying HTTP client.
  void close();
}

/// A [CloudTtsClient] that can also send its speech while it is making it.
abstract interface class StreamingCloudTtsClient implements CloudTtsClient {
  /// Speaks [text] with [voiceId] on [model] as one synthesis, and emits
  /// the WAV file's bytes in order as they are made: the header first, its
  /// length fields not filled in, since the length is not known yet.
  ///
  /// The stream ends without a byte for a text the provider makes no audio
  /// of that way — a single short word, on Voxtral — which is no failure:
  /// [synthesize] speaks it.
  Stream<Uint8List> synthesizeStream({
    required String text,
    required String voiceId,
    required String baseUrl,
    required String apiKey,
    required String model,
  });
}
