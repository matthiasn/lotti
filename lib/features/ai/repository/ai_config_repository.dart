import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/provider_type_utils.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ai_config_repository.g.dart';

/// Result object for cascade deletion operations
class CascadeDeletionResult {
  const CascadeDeletionResult({
    required this.deletedModels,
    required this.providerName,
  });

  final List<AiConfigModel> deletedModels;
  final String providerName;

  int get deletedModelCount => deletedModels.length;
}

@Riverpod(keepAlive: true)
AiConfigRepository aiConfigRepository(Ref ref) {
  return getIt<AiConfigRepository>();
}

class AiConfigRepository {
  AiConfigRepository(this._db);

  final AiConfigDb _db;

  /// Save or update an AI configuration
  Future<void> saveConfig(
    AiConfig config, {
    bool fromSync = false,
  }) async {
    await _db.saveConfig(config);
    if (!fromSync) {
      await getIt<OutboxService>().enqueueMessage(
        SyncMessage.aiConfig(
          aiConfig: config,
          status: SyncEntryStatus.initial,
        ),
      );
    }
  }

  /// Delete an AI configuration by its ID
  Future<void> deleteConfig(
    String id, {
    bool fromSync = false,
  }) async {
    await _db.deleteConfig(id);
    if (!fromSync) {
      await getIt<OutboxService>().enqueueMessage(
        SyncMessage.aiConfigDelete(id: id),
      );
    }
  }

  /// Delete an inference provider and all its associated models.
  ///
  /// This method performs cascade deletion within a transaction to ensure atomicity:
  /// 1. Fetches all models associated with the provider
  /// 2. Deletes each model
  /// 3. Deletes the provider itself
  ///
  /// If any deletion fails, the entire transaction is rolled back to maintain
  /// data integrity and prevent partial deletions.
  ///
  /// Returns detailed information about the deletion operation.
  Future<CascadeDeletionResult> deleteInferenceProviderWithModels(
    String providerId, {
    bool fromSync = false,
  }) async {
    return _db.transaction(() async {
      try {
        // Get the provider first to capture its name
        final provider =
            await getConfigById(providerId) as AiConfigInferenceProvider?;
        final providerName = provider?.name ?? 'Unknown Provider';

        // Get all models to find those associated with this provider
        final allModels = await getConfigsByType(AiConfigType.model);
        final associatedModels = allModels
            .whereType<AiConfigModel>()
            .where((model) => model.inferenceProviderId == providerId)
            .toList();

        // Delete all associated models with detailed error tracking
        for (final model in associatedModels) {
          try {
            await deleteConfig(model.id, fromSync: fromSync);
          } catch (e) {
            // Re-throw to trigger transaction rollback
            rethrow;
          }
        }

        // Delete the provider itself
        try {
          await deleteConfig(providerId, fromSync: fromSync);
        } catch (e) {
          throw Exception('Failed to delete provider $providerId: $e');
        }

        return CascadeDeletionResult(
          deletedModels: associatedModels,
          providerName: providerName,
        );
      } catch (error, stackTrace) {
        getIt<LoggingService>().captureException(
          error,
          domain: 'AiConfigRepository',
          subDomain: 'deleteInferenceProviderWithModels',
          stackTrace: stackTrace,
        );
        rethrow; // Re-throw to let the caller handle the error
      }
    });
  }

  /// Get an AI configuration by its ID
  Future<AiConfig?> getConfigById(String id) async {
    return _db.getConfigById(id);
  }

  /// Stream of all AI configurations of a specific type
  Future<List<AiConfig>> getConfigsByType(AiConfigType type) async {
    final dbEntities = await _db.getConfigsByType(type.name);
    return dbEntities
        .map(
          (entity) => AiConfig.fromJson(
            Map<String, dynamic>.from(_jsonDecode(entity.serialized)),
          ),
        )
        .toList();
  }

  /// Stream of all AI configurations of a specific type
  Stream<List<AiConfig>> watchConfigsByType(AiConfigType type) {
    return _db.watchConfigsByType(type.name).map(
          (entities) => entities
              .map(
                (entity) => AiConfig.fromJson(
                  Map<String, dynamic>.from(_jsonDecode(entity.serialized)),
                ),
              )
              .toList(),
        );
  }

  /// Helper method to decode JSON
  Map<String, dynamic> _jsonDecode(String serialized) {
    final map = Map<String, dynamic>.from(
      const JsonDecoder().convert(serialized) as Map,
    );

    // Harden parsing for provider type: normalize known aliases and
    // default to OpenAI-compatible when unknown.
    final dynamic rawType = map['inferenceProviderType'];
    if (rawType is String) {
      map['inferenceProviderType'] = normalizeProviderType(rawType);
    }
    return map;
  }
}
