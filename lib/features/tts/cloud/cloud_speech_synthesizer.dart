import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/tts/cloud/cloud_tts_client.dart';
import 'package:lotti/features/tts/cloud/cloud_tts_exception.dart';
import 'package:lotti/features/tts/cloud/cloud_voice_catalog_repository.dart';
import 'package:lotti/features/tts/cloud/elevenlabs_tts_service.dart';
import 'package:lotti/features/tts/cloud/growing_speech_clip.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/cloud/voxtral_tts_service.dart';
import 'package:lotti/features/tts/engine/speech_text.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:path_provider/path_provider.dart';

/// Speaks text on a [TtsCloudRoute] and hands back a temporary WAV, the same
/// artifact the on-device engine produces, so playback, cancellation and
/// cleanup stay one code path.
class CloudSpeechSynthesizer {
  CloudSpeechSynthesizer({
    required this._clients,
    required this._catalogs,
    Future<Directory> Function()? tempDirectory,
  }) : _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  final Map<InferenceProviderType, CloudTtsClient> _clients;
  final CloudVoiceCatalogRepository _catalogs;
  final Future<Directory> Function() _tempDirectory;
  int _counter = 0;

  /// Synthesizes [text] with the route's own voice when it names one, else
  /// the voice [chosenVoices] names for the route's provider and language
  /// ([cloudVoiceChoiceKey]), else that language's default voice.
  /// The caller owns, and deletes, the returned file.
  ///
  /// [canSend] is asked once the voice is known, immediately before the text
  /// is uploaded: resolving the catalog may wait on the network, and an
  /// utterance stopped — or content hidden — in the meantime must not be
  /// sent. A `false` answer returns `null` without any request.
  ///
  /// The voice gets [text] without its emoji ([withoutEmoji]); text that is
  /// nothing but emoji has nothing to say and returns `null` without any
  /// request, as a stop does.
  ///
  /// Throws [CloudTtsException] — [CloudTtsFailure.noVoice] when the
  /// language has no voice, before any text leaves the device — and
  /// [ArgumentError] for a route whose provider has no speech client.
  Future<File?> synthesizeToFile({
    required TtsCloudRoute route,
    required String text,
    required Map<String, String> chosenVoices,
    required Future<bool> Function() canSend,
  }) async {
    final request = await _request(route, text, chosenVoices, canSend);
    if (request == null) return null;
    final bytes = await request.client.synthesize(
      text: request.spoken,
      voiceId: request.voiceId,
      baseUrl: route.provider.baseUrl,
      apiKey: route.provider.apiKey,
      model: route.model.providerModelId,
    );
    final file = await _newFile();
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Whether [route]'s provider can send its speech while it makes it, so
  /// [synthesizeToGrowingFile] is worth asking for.
  bool canStream(TtsCloudRoute route) =>
      _clients[route.provider.inferenceProviderType] is StreamingCloudTtsClient;

  /// As [synthesizeToFile], for a [route] that [canStream], but returns as
  /// soon as the request is made: the file is written while the voice still
  /// speaks into it, and can be played before it is whole (see
  /// [GrowingSpeechClip]). The caller owns the clip: it cancels one it
  /// gives up on, and deletes its file.
  ///
  /// Null, as there, when nothing may be sent or there is nothing to say.
  Future<GrowingSpeechClip?> synthesizeToGrowingFile({
    required TtsCloudRoute route,
    required String text,
    required Map<String, String> chosenVoices,
    required Future<bool> Function() canSend,
  }) async {
    final request = await _request(route, text, chosenVoices, canSend);
    if (request == null) return null;
    final client = request.client as StreamingCloudTtsClient;
    // Asked once more as the request is made — when the clip starts
    // reading: preparing its file waits on the file system, and a stop or
    // a withdrawn permission meanwhile must keep the text on the device.
    // A no is a stream without audio, which the caller ends quietly.
    Stream<Uint8List> gated() async* {
      if (!await canSend()) return;
      yield* client.synthesizeStream(
        text: request.spoken,
        voiceId: request.voiceId,
        baseUrl: route.provider.baseUrl,
        apiKey: route.provider.apiKey,
        model: route.model.providerModelId,
      );
    }

    return GrowingSpeechClip.start(await _newFile(), gated());
  }

  /// What is sent for [text] on [route] — its client, its voice and the
  /// words — or null when nothing may be, or there is nothing to say.
  Future<({CloudTtsClient client, String voiceId, String spoken})?> _request(
    TtsCloudRoute route,
    String text,
    Map<String, String> chosenVoices,
    Future<bool> Function() canSend,
  ) async {
    final type = route.provider.inferenceProviderType;
    final client = _clients[type];
    if (client == null) {
      throw ArgumentError.value(type, 'route', 'has no speech client');
    }
    final catalog = await _catalogs.catalogFor(route.provider, route.model);
    final voice = catalog.resolve(
      languageCode: route.languageCode,
      preferredVoiceId:
          route.voiceId ??
          chosenVoices[cloudVoiceChoiceKey(route.provider, route.languageCode)],
    );
    if (voice == null) {
      throw CloudTtsException(
        CloudTtsFailure.noVoice,
        'No voice for language ${route.languageCode}',
      );
    }
    final spoken = withoutEmoji(text);
    if (spoken.isEmpty || !await canSend()) return null;
    return (client: client, voiceId: voice.id, spoken: spoken);
  }

  Future<File> _newFile() async {
    final directory = await _tempDirectory();
    return File('${directory.path}/tts_cloud_${_counter++}.wav');
  }
}

/// The speech client of every provider type in [cloudSpeechProviderTypes],
/// each closed with the provider scope.
final cloudTtsClientsProvider =
    Provider<Map<InferenceProviderType, CloudTtsClient>>((ref) {
      final logger = ref.watch(domainLoggerProvider);
      final clients = <InferenceProviderType, CloudTtsClient>{
        InferenceProviderType.mistral: VoxtralTtsService(domainLogger: logger),
        InferenceProviderType.elevenLabs: ElevenLabsTtsService(
          domainLogger: logger,
        ),
      };
      ref.onDispose(() {
        for (final client in clients.values) {
          client.close();
        }
      });
      return clients;
    }, name: 'cloudTtsClientsProvider');

final cloudVoiceCatalogRepositoryProvider =
    Provider<CloudVoiceCatalogRepository>(
      (ref) => CloudVoiceCatalogRepository(
        settingsDb: ref.watch(settingsDbProvider),
        clients: ref.watch(cloudTtsClientsProvider),
      ),
      name: 'cloudVoiceCatalogRepositoryProvider',
    );

final cloudSpeechSynthesizerProvider = Provider<CloudSpeechSynthesizer>(
  (ref) => CloudSpeechSynthesizer(
    clients: ref.watch(cloudTtsClientsProvider),
    catalogs: ref.watch(cloudVoiceCatalogRepositoryProvider),
  ),
  name: 'cloudSpeechSynthesizerProvider',
);
