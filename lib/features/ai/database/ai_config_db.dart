import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/provider_type_utils.dart';

part 'ai_config_db.g.dart';

const aiConfigDbFileName = 'ai_config.sqlite';

@DriftDatabase(include: {'ai_config_db.drift'})
class AiConfigDb extends _$AiConfigDb {
  AiConfigDb({this.inMemoryDatabase = false})
      : super(
          openDbConnection(
            aiConfigDbFileName,
            inMemoryDatabase: inMemoryDatabase,
          ),
        );

  bool inMemoryDatabase = false;

  @override
  int get schemaVersion => 1;

  Future<int> saveConfig(AiConfig config) async {
    final existingConfig = await configById(config.id).getSingleOrNull();

    final now = DateTime.now();

    final dbEntity = AiConfigDbEntity(
      id: config.id,
      type: config.map(
        inferenceProvider: (_) => 'inferenceProvider',
        model: (_) => 'model',
        prompt: (_) => 'prompt',
      ),
      name: config.name,
      serialized: jsonEncode(config.toJson()),
      createdAt: existingConfig?.createdAt ?? now,
      updatedAt: now,
    );

    return into(aiConfigs).insertOnConflictUpdate(dbEntity);
  }

  Future<void> deleteConfig(String id) async {
    await delete(aiConfigs).delete(AiConfigsCompanion(id: Value(id)));
  }

  Future<List<AiConfigDbEntity>> getConfigsByType(String type) {
    return configsByType(type).get();
  }

  Stream<List<AiConfigDbEntity>> watchConfigsByType(String type) {
    return configsByType(type).watch();
  }

  Stream<List<AiConfigDbEntity>> watchAllConfigs() {
    return allConfigs().watch();
  }

  Future<AiConfig?> getConfigById(String id) async {
    final dbEntity = await configById(id).getSingleOrNull();
    if (dbEntity == null) return null;
    final raw = jsonDecode(dbEntity.serialized) as Map<String, dynamic>;
    final map = Map<String, dynamic>.from(raw);

    // Harden parsing for legacy/unknown provider types to avoid crashes when
    // reading single configs (e.g., during delete actions).
    final dynamic rawType = map['inferenceProviderType'];
    final normalized = normalizeProviderType(
      rawType is String ? rawType : (rawType?.toString() ?? ''),
    );
    map['inferenceProviderType'] = normalized;

    return AiConfig.fromJson(map);
  }

}
