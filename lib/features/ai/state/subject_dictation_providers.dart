import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai/services/audio_transcription_service.dart';
import 'package:lotti/features/ai/speech/sherpa_model_repository.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/ai/util/inference_provider_resolver.dart';
import 'package:lotti/features/ai/util/speech_to_text_route.dart';
import 'package:lotti/providers/service_providers.dart'
    show domainLoggerProvider;
import 'package:lotti/services/domain_logging.dart';

const _logTag = 'SubjectDictation';

/// Dictation for a surface that takes the words back instead of keeping a
/// recording — a goal's or a person's agent chat, a goal's charter sheet —
/// on the profile that subject's recordings transcribe through.
///
/// Both halves follow `ProfileAutomationResolver.resolveTranscriptionProfile`
/// for the subject's category: the category's profile when it can
/// transcribe, else the device's Settings default. No model is chosen here,
/// and none is discovered: a subject whose profiles cannot transcribe gets
/// the chat's "no audio model" error rather than a model the user never
/// picked.
class SubjectDictation {
  const SubjectDictation({
    required this.resolveTarget,
    required this.correct,
  });

  /// The transcription slot's provider and model, resolved when a take
  /// stops. Throws a [TranscriptionException] when nothing can transcribe.
  final Future<ResolvedInferenceProvider> Function() resolveTarget;

  /// The words `heardBy` produced, corrected against the speech dictionary
  /// by the profile's post-processing model — the step a check-in's
  /// recording gets. Only a speech-to-text engine is corrected: a multimodal
  /// model spelled the dictionary's terms as given. Never throws; anything
  /// that fails keeps the words as heard.
  final Future<String> Function(
    String transcript,
    ResolvedInferenceProvider heardBy,
  )
  correct;
}

/// The [SubjectDictation] for the subject `subjectId` (a goal's journal
/// entry, a person). Everything is read when a take needs it, not when a
/// chat builds: a category or a profile changed meanwhile is the one that
/// runs, and a surface that is never dictated into resolves nothing.
final ProviderFamily<SubjectDictation, String> subjectDictationProvider =
    Provider.family<SubjectDictation, String>((ref, subjectId) {
      Future<({ResolvedProfile? profile, String? categoryId})> resolve() async {
        final resolver = ref.read(profileAutomationResolverProvider);
        final categoryId = await resolver.categoryOfSubject(subjectId);
        return (
          profile: await resolver.resolveTranscriptionProfile(
            categoryId: categoryId,
          ),
          categoryId: categoryId,
        );
      }

      return SubjectDictation(
        resolveTarget: () async {
          final profile = (await resolve()).profile;
          final provider = profile?.transcriptionProvider;
          final model = profile?.transcriptionModel;
          if (provider == null ||
              model == null ||
              !model.inputModalities.contains(Modality.audio) ||
              !model.outputModalities.contains(Modality.text) ||
              (provider.inferenceProviderType ==
                      InferenceProviderType.mistral &&
                  isRealtimeOnlyTranscriptionModel(model.providerModelId))) {
            throw _unavailable();
          }
          if (provider.inferenceProviderType == InferenceProviderType.sherpa &&
              !await ref
                  .read(sherpaModelRepositoryProvider)
                  .isAvailable(model.providerModelId)) {
            throw _unavailable();
          }
          return (model: model, provider: provider);
        },
        correct: (transcript, heardBy) async {
          if (!routesToSpeechToText(
            heardBy.provider,
            heardBy.model.providerModelId,
          )) {
            return transcript;
          }
          try {
            final (:profile, :categoryId) = await resolve();
            final route = profile?.transcriptCorrectionRoute;
            if (route == null) return transcript;
            return await ref
                .read(audioTranscriptionServiceProvider)
                .correctTranscript(
                  transcript,
                  target: route,
                  dictionaryCategoryId: categoryId,
                );
          } catch (error, stackTrace) {
            ref
                .read(domainLoggerProvider)
                .error(
                  LogDomain.speech,
                  error,
                  stackTrace: stackTrace,
                  subDomain: _logTag,
                  message:
                      'Could not correct dictation for '
                      '${DomainLogger.sanitizeId(subjectId)}',
                );
            return transcript;
          }
        },
      );
    }, name: 'subjectDictationProvider');

// The chat recorder reads "No audio-capable models" as its no-model error.
TranscriptionException _unavailable() => TranscriptionException(
  'No audio-capable models configured for this transcription',
);
