import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/agents/util/inference_provider_resolver.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai/speech/sherpa_model_repository.dart';

/// Query dictation uses the current category default's transcription slot,
/// independently of the task/agent's thinking setup. Resolve on each recording
/// submission; missing setup never falls through to automatic model discovery.
final ProviderFamily<ChatTranscriptionTargetResolver, QueryScope>
queryTranscriptionTargetResolverProvider =
    Provider.family<ChatTranscriptionTargetResolver, QueryScope>((ref, scope) {
      final access = ref.watch(querySourceAccessProvider);
      final configs = ref.watch(aiConfigRepositoryProvider);
      return () async {
        final initial = await access.load([scope.id]);
        final categoryId = _categoryId(initial, scope);
        final profileId = initial.categories[categoryId]?.defaultProfileId;
        if (profileId == null) throw _unavailable();
        final profile = await configs.getConfigById(profileId);
        if (profile is! AiConfigInferenceProfile ||
            profile.transcriptionModelId == null) {
          throw _unavailable();
        }
        final target = await resolveInferenceProviderForProfileSlot(
          modelId: profile.transcriptionModelId!,
          aiConfigRepository: configs,
        );
        if (target == null ||
            !target.model.inputModalities.contains(Modality.audio) ||
            !target.model.outputModalities.contains(Modality.text) ||
            (target.provider.inferenceProviderType ==
                    InferenceProviderType.mistral &&
                target.model.providerModelId.contains('transcribe-realtime'))) {
          throw _unavailable();
        }
        if (target.provider.inferenceProviderType ==
                InferenceProviderType.sherpa &&
            !await ref
                .read(sherpaModelRepositoryProvider)
                .isAvailable(target.model.providerModelId)) {
          throw _unavailable();
        }
        final liveProfile = await configs.getConfigById(profileId);
        final current = await access.load([scope.id]);
        if (_categoryId(current, scope) != categoryId ||
            current.categories[categoryId]?.defaultProfileId != profileId ||
            liveProfile is! AiConfigInferenceProfile ||
            liveProfile.transcriptionModelId != profile.transcriptionModelId ||
            (initial.showPrivate && !current.showPrivate)) {
          throw const QueryScopeUnavailable();
        }
        return target;
      };
    });

String? _categoryId(QueryAccessSnapshot snapshot, QueryScope scope) {
  if (scope.kind == QueryScopeKind.category) {
    if (!snapshot.allowsCategory(scope.id)) {
      throw const QueryScopeUnavailable();
    }
    return scope.id;
  }
  final home = snapshot.entries[scope.id];
  if (home == null || !snapshot.allowsEntry(home)) {
    throw const QueryScopeUnavailable();
  }
  return home.meta.categoryId;
}

TranscriptionException _unavailable() => TranscriptionException(
  'No audio-capable models configured for category transcription',
);
