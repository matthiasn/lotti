import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

/// Riverpod store sharing one native MLX Audio progress stream across all
/// model rows / detail pages / modals. Split out of `mlx_audio_channel.dart`
/// so the channel file stays a thin platform bridge.
///
final mlxAudioModelProgressStoreProvider =
    NotifierProvider<
      MlxAudioModelProgressStore,
      Map<String, MlxAudioModelDownloadProgress>
    >(MlxAudioModelProgressStore.new);

final FutureProviderFamily<void, String> _mlxAudioInitialModelStatusProvider =
    FutureProvider.family<void, String>(
      (ref, modelId) async {
        final store = ref.read(mlxAudioModelProgressStoreProvider.notifier);
        await store.refreshModelStatus(modelId);
      },
    );

/// Shared MLX Audio model status for one model id.
///
/// The native EventChannel only owns a single event sink. Keeping one Dart-side
/// subscription in [MlxAudioModelProgressStore] avoids model rows, detail pages,
/// and the modal racing each other for the stream listener.
final ProviderFamily<MlxAudioModelDownloadProgress?, String>
mlxAudioModelProgressProvider =
    Provider.family<MlxAudioModelDownloadProgress?, String>((ref, modelId) {
      ref.watch(_mlxAudioInitialModelStatusProvider(modelId));
      return ref.watch(
        mlxAudioModelProgressStoreProvider.select(
          (progressByModel) => progressByModel[modelId],
        ),
      );
    });

class MlxAudioModelProgressStore
    extends Notifier<Map<String, MlxAudioModelDownloadProgress>> {
  StreamSubscription<MlxAudioModelDownloadProgress>? _subscription;
  final Set<String> _refreshingModelIds = <String>{};
  final Set<String> _installingModelIds = <String>{};

  @override
  Map<String, MlxAudioModelDownloadProgress> build() {
    final channel = ref.watch(mlxAudioChannelProvider);
    _subscription = channel.downloadProgressStream.listen(
      _setProgress,
      onError: (Object error, StackTrace stackTrace) {
        _logProgressStoreError('downloadProgressStream', error, stackTrace);
      },
    );
    ref.onDispose(() => unawaited(_subscription?.cancel()));
    return const <String, MlxAudioModelDownloadProgress>{};
  }

  Future<void> refreshModelStatus(String modelId) async {
    if (!_refreshingModelIds.add(modelId)) return;
    try {
      final progress = await ref
          .read(mlxAudioChannelProvider)
          .getModelStatus(
            modelId,
          );
      _setProgressIfNewer(progress);
    } catch (error, stackTrace) {
      _logProgressStoreError('getModelStatus', error, stackTrace);
      _setProgress(
        MlxAudioModelDownloadProgress(
          modelId: modelId,
          status: MlxAudioModelStatus.failed,
          message: error.toString(),
        ),
      );
    } finally {
      _refreshingModelIds.remove(modelId);
    }
  }

  Future<void> installModel(String modelId) async {
    if (!_installingModelIds.add(modelId)) return;
    _setProgress(
      MlxAudioModelDownloadProgress(
        modelId: modelId,
        status: MlxAudioModelStatus.downloading,
      ),
    );
    try {
      await ref.read(mlxAudioChannelProvider).installModel(modelId);
    } catch (error, stackTrace) {
      _logProgressStoreError('installModel', error, stackTrace);
      _setProgress(
        MlxAudioModelDownloadProgress(
          modelId: modelId,
          status: MlxAudioModelStatus.failed,
          message: error.toString(),
        ),
      );
    } finally {
      _installingModelIds.remove(modelId);
      await refreshModelStatus(modelId);
    }
  }

  void _setProgressIfNewer(MlxAudioModelDownloadProgress progress) {
    final current = state[progress.modelId];
    if (current?.status == MlxAudioModelStatus.downloading &&
        progress.status == MlxAudioModelStatus.notInstalled) {
      return;
    }
    if (current?.status == MlxAudioModelStatus.installed &&
        (progress.status == MlxAudioModelStatus.notInstalled ||
            progress.status == MlxAudioModelStatus.downloading)) {
      return;
    }
    _setProgress(progress);
  }

  void _setProgress(MlxAudioModelDownloadProgress progress) {
    state = <String, MlxAudioModelDownloadProgress>{
      ...state,
      progress.modelId: progress,
    };
  }

  void _logProgressStoreError(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    try {
      getIt<DomainLogger>().error(
        LogDomain.speech,
        error,
        stackTrace: stackTrace,
        subDomain: operation,
      );
    } catch (_) {
      // LoggingService may not be registered in tests.
    }
  }
}
