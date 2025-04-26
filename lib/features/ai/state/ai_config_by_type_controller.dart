import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ai_config_by_type_controller.g.dart';

/// Controller for getting a list of AiConfig items of a specific type
/// Used in settings list pages to display all configurations of a particular type
@riverpod
class AiConfigByTypeController extends _$AiConfigByTypeController {
  @override
  Stream<List<AiConfig>> build({required String configType}) {
    final repository = ref.watch(aiConfigRepositoryProvider);
    return repository.watchConfigsByType(configType);
  }

  /// Add a new configuration
  Future<void> addConfig(AiConfig config) async {
    final repository = ref.read(aiConfigRepositoryProvider);
    await repository.saveConfig(config);
  }

  /// Update an existing configuration
  Future<void> updateConfig(AiConfig config) async {
    final repository = ref.read(aiConfigRepositoryProvider);
    await repository.saveConfig(config);
  }

  /// Delete a configuration
  Future<void> deleteConfig(String id) async {
    final repository = ref.read(aiConfigRepositoryProvider);
    await repository.deleteConfig(id);
  }
}

/// Provider for getting a specific AiConfig by its ID
@riverpod
Future<AiConfig?> aiConfigById(Ref ref, String id) async {
  final repository = ref.watch(aiConfigRepositoryProvider);
  return repository.getConfigById(id);
}
