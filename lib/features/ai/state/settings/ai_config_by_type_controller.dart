import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';

/// Controller for getting a list of AiConfig items of a specific type
/// Used in settings list pages to display all configurations of a particular type
final StreamNotifierProviderFamily<
  AiConfigByTypeController,
  List<AiConfig>,
  AiConfigType
>
aiConfigByTypeControllerProvider = StreamNotifierProvider.autoDispose
    .family<AiConfigByTypeController, List<AiConfig>, AiConfigType>(
      AiConfigByTypeController.new,
      name: 'aiConfigByTypeControllerProvider',
    );

class AiConfigByTypeController extends StreamNotifier<List<AiConfig>> {
  AiConfigByTypeController([this.configType = AiConfigType.inferenceProvider]);

  final AiConfigType configType;

  @override
  Stream<List<AiConfig>> build() {
    final repository = ref.watch(aiConfigRepositoryProvider);
    return repository.watchConfigsByType(configType);
  }
}

/// Provider for getting a specific AiConfig by its ID
final FutureProviderFamily<AiConfig?, String> aiConfigByIdProvider =
    FutureProvider.autoDispose.family<AiConfig?, String>(
      aiConfigById,
      name: 'aiConfigByIdProvider',
    );
Future<AiConfig?> aiConfigById(Ref ref, String id) async {
  final repository = ref.watch(aiConfigRepositoryProvider);
  return repository.getConfigById(id);
}
