import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/audio_transcript_timing.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_text_inference.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/mistral_transcription_repository.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:lotti/get_it.dart';
import 'package:openai_dart/openai_dart.dart';

/// Timing uses the explicitly configured transcription slot. No provider or
/// model is substituted, and no model is configured on the user's behalf.
class QueryAudioTimingUnavailable implements Exception {
  const QueryAudioTimingUnavailable();
}

class QueryAudioTimingService {
  QueryAudioTimingService({
    MistralTranscriptionRepository Function()? createRepository,
    this.capture,
  }) : createRepository =
           createRepository ?? MistralTranscriptionRepository.new;

  final MistralTranscriptionRepository Function() createRepository;
  final AiInteractionCapture? capture;

  /// Dedicated Voxtral transcription models have timed output. Instruction
  /// following and realtime models are not silently rerouted to another model.
  static bool supports(ResolvedProfile? profile) {
    final model = profile?.transcriptionModelId;
    return profile?.transcriptionProvider?.inferenceProviderType ==
            InferenceProviderType.mistral &&
        model != null &&
        (model == 'voxtral-mini-latest' ||
            model.startsWith('voxtral-mini-transcribe-')) &&
        !model.contains('realtime');
  }

  /// Produces a separate timing sidecar for the exact bytes submitted. The
  /// caller rechecks the source and persists it without modifying note text.
  Future<AudioTranscriptTiming> generate({
    required ResolvedProfile profile,
    required Uint8List audioBytes,
    required QueryEvidence evidence,
    required QueryCancellation cancellation,
    required Future<void> Function() authorize,
    required String agentId,
    required String chatId,
  }) async {
    if (!supports(profile)) throw const QueryAudioTimingUnavailable();
    cancellation.check();
    final provider = profile.transcriptionProvider!;
    final model = profile.transcriptionModelId!;
    final repository = createRepository();
    final detach = cancellation.onCancel(repository.close);
    List<AudioTimedSegment>? segments;
    Stream<CreateChatCompletionStreamResponse> invoke() async* {
      await authorize();
      cancellation.check();
      yield* repository.transcribeAudio(
        model: model,
        audioBase64: base64Encode(audioBytes),
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        onSegments: (value) => segments = value,
      );
    }

    try {
      final stream = capture == null
          ? invoke()
          : capture!.captureStream(
              workType: AiWorkType.audioTranscription,
              interactionKind: AiInteractionKind.audioTranscription,
              responseType: AiConsumptionResponseType.audioTranscription,
              providerType: provider.inferenceProviderType,
              modelId: model,
              requestText:
                  'Timestamp alignment|audioBytes:${audioBytes.length}',
              invoke: invoke,
              responseText: (chunk) =>
                  chunk.choices?.firstOrNull?.delta?.content ?? '',
              interactionContext: AiCapturedContext(
                entryId: evidence.source.id,
                agentId: agentId,
                threadId: chatId,
                providerConfigId: provider.id,
                modelConfigId: profile.transcriptionModel?.id,
              ),
              categoryId: evidence.source.categoryId,
            );
      // The text is attributed but never added to the chat or its memory.
      await cancellation.collect(stream.map((_) => ''));
      await authorize();
      cancellation.check();
      if (segments == null || segments!.isEmpty) {
        throw const FormatException('No usable transcript timing');
      }
      return AudioTranscriptTiming(
        createdAt: clock.now(),
        audioSha256: sha256.convert(audioBytes).toString(),
        sourceFingerprint: evidence.fingerprint,
        sourceVersion: evidence.textVersion,
        providerId: provider.id,
        model: model,
        segments: segments!,
      );
    } finally {
      detach();
      repository.close();
    }
  }
}

final queryAudioTimingServiceProvider = Provider<QueryAudioTimingService>(
  (ref) => QueryAudioTimingService(
    capture: getIt.isRegistered<AiInteractionCapture>()
        ? getIt<AiInteractionCapture>()
        : null,
  ),
);
