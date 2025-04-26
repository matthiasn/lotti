import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ai_config_repository.g.dart';

@Riverpod(keepAlive: true)
AiConfigRepository aiConfigRepository(Ref ref) {
  return getIt<AiConfigRepository>();
}

class AiConfigRepository {
  AiConfigRepository(this._db);

  final AiConfigDb _db;

  /// Save or update an AI configuration
  Future<void> saveConfig(AiConfig config) async {
    await _db.saveConfig(config);

    await getIt<OutboxService>().enqueueMessage(
      SyncMessage.aiConfig(
        aiConfig: config,
        status: SyncEntryStatus.initial,
      ),
    );
  }

  /// Delete an AI configuration by its ID
  Future<void> deleteConfig(String id) async {
    await _db.deleteConfig(id);
  }

  /// Get an AI configuration by its ID
  Future<AiConfig?> getConfigById(String id) async {
    return _db.getConfigById(id);
  }

  /// Stream of all AI configurations of a specific type
  Future<List<AiConfig>> getConfigsByType(String type) async {
    final dbEntities = await _db.getConfigsByType(type);
    return dbEntities
        .map(
          (entity) => AiConfig.fromJson(
            Map<String, dynamic>.from(_jsonDecode(entity.serialized)),
          ),
        )
        .toList();
  }

  /// Stream of all AI configurations of a specific type
  Stream<List<AiConfig>> watchConfigsByType(String type) {
    return _db.watchConfigsByType(type).map(
          (entities) => entities
              .map(
                (entity) => AiConfig.fromJson(
                  Map<String, dynamic>.from(_jsonDecode(entity.serialized)),
                ),
              )
              .toList(),
        );
  }

  /// Stream of all AI configurations
  Stream<List<AiConfig>> watchAllConfigs() {
    return _db.watchAllConfigs().map(
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
    return Map<String, dynamic>.from(
      const JsonDecoder().convert(serialized) as Map,
    );
  }
}
