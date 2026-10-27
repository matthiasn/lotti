import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/cloud/voxtral_tts_service.dart';
import 'package:lotti/features/tts/cloud/voxtral_voice_catalog_repository.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:path_provider/path_provider.dart';

/// Speaks text on a [TtsCloudRoute] and hands back a temporary WAV, the same
/// artifact the on-device engine produces, so playback, cancellation and
/// cleanup stay one code path.
class CloudSpeechSynthesizer {
  CloudSpeechSynthesizer({
    required this._service,
    required this._catalogs,
    Future<Directory> Function()? tempDirectory,
  }) : _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  final VoxtralTtsService _service;
  final VoxtralVoiceCatalogRepository _catalogs;
  final Future<Directory> Function() _tempDirectory;
  int _counter = 0;

  /// Synthesizes [text] with the voice [voiceByLanguage] names for the
  /// route's language, or that language's default voice. The caller owns,
  /// and deletes, the returned file.
  ///
  /// Throws [VoxtralTtsException] — [VoxtralTtsFailure.noVoice] when the
  /// language has no voice, before any text leaves the device.
  Future<File> synthesizeToFile({
    required TtsCloudRoute route,
    required String text,
    required Map<String, String> voiceByLanguage,
  }) async {
    final catalog = await _catalogs.catalogFor(route.provider);
    final voice = catalog.resolve(
      languageCode: route.languageCode,
      preferredVoiceId: voiceByLanguage[route.languageCode],
    );
    if (voice == null) {
      throw VoxtralTtsException(
        VoxtralTtsFailure.noVoice,
        'No voice for language ${route.languageCode}',
      );
    }
    final bytes = await _service.synthesize(
      text: text,
      voiceId: voice.id,
      baseUrl: route.provider.baseUrl,
      apiKey: route.provider.apiKey,
      model: route.model.providerModelId,
    );
    final directory = await _tempDirectory();
    final file = File('${directory.path}/tts_cloud_${_counter++}.wav');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}

/// The Voxtral client, closed with the provider scope.
final voxtralTtsServiceProvider = Provider<VoxtralTtsService>((ref) {
  final service = VoxtralTtsService(
    domainLogger: ref.watch(domainLoggerProvider),
  );
  ref.onDispose(service.close);
  return service;
}, name: 'voxtralTtsServiceProvider');

final voxtralVoiceCatalogRepositoryProvider =
    Provider<VoxtralVoiceCatalogRepository>(
      (ref) => VoxtralVoiceCatalogRepository(
        settingsDb: ref.watch(settingsDbProvider),
        service: ref.watch(voxtralTtsServiceProvider),
      ),
      name: 'voxtralVoiceCatalogRepositoryProvider',
    );

final cloudSpeechSynthesizerProvider = Provider<CloudSpeechSynthesizer>(
  (ref) => CloudSpeechSynthesizer(
    service: ref.watch(voxtralTtsServiceProvider),
    catalogs: ref.watch(voxtralVoiceCatalogRepositoryProvider),
  ),
  name: 'cloudSpeechSynthesizerProvider',
);
