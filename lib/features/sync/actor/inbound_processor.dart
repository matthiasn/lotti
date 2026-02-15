import 'dart:convert';
import 'dart:io';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/settings/constants/theming_settings_keys.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as path;

typedef InboundProcessorEventSink = void Function(Map<String, Object?> event);

class InboundProcessor {
  InboundProcessor({
    required JournalDb journalDb,
    required SettingsDb settingsDb,
    required Directory documentsDirectory,
    required InboundProcessorEventSink emitEvent,
  })  : _journalDb = journalDb,
        _settingsDb = settingsDb,
        _documentsDirectory = documentsDirectory,
        _emitEvent = emitEvent;

  final JournalDb _journalDb;
  final SettingsDb _settingsDb;
  final Directory _documentsDirectory;
  final InboundProcessorEventSink _emitEvent;

  Future<void> processTimelineEvent(Event event) async {
    if (event.messageType != syncMessageType) return;
    final text = _extractPayloadText(event);
    if (text.isEmpty) return;

    final syncMessage = _decodeSyncMessage(text);
    if (syncMessage == null) return;

    try {
      switch (syncMessage) {
        case final SyncJournalEntity msg:
          await _handleJournalEntity(msg);
        case final SyncEntryLink msg:
          await _handleEntryLink(msg);
        case SyncEntityDefinition(entityDefinition: final definition):
          await _handleEntityDefinition(definition);
        case SyncTagEntity(tagEntity: final tagEntity):
          await _handleTagEntity(tagEntity);
        case SyncThemingSelection(
            lightThemeName: final lightThemeName,
            darkThemeName: final darkThemeName,
            themeMode: final themeMode,
            updatedAt: final updatedAt,
          ):
          await _handleThemingSelection(
            lightThemeName: lightThemeName,
            darkThemeName: darkThemeName,
            themeMode: themeMode,
            updatedAt: updatedAt,
          );
        case SyncAiConfig():
        case SyncAiConfigDelete():
        case SyncBackfillRequest():
        case SyncBackfillResponse():
          return;
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[InboundProcessor] failed to process sync message '
        '(eventId=${event.eventId}): $error',
      );
      debugPrint('$stackTrace');
      // Keep actor-side inbound loop stable: inbound processing failures are
      // surfaced only as no-op from the timeline listener.
    }
  }

  String _extractPayloadText(Event event) {
    final text = event.text;
    if (text.isNotEmpty) {
      return text;
    }

    final content = event.content;
    final body = content['body'];
    return body is String ? body : '';
  }

  SyncMessage? _decodeSyncMessage(String text) {
    try {
      final bytes = base64.decode(text);
      final decoded = utf8.decode(bytes);
      final raw = json.decode(decoded);
      if (raw is! Map<String, dynamic>) return null;
      return SyncMessage.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  String _resolveJsonPath(String jsonPath) {
    final trimmed = jsonPath.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('jsonPath is empty');
    }

    final docPath = path.normalize(_documentsDirectory.path);
    final raw = path.normalize(trimmed);
    final relativePath = raw.startsWith(path.separator) ||
            raw.startsWith(r'\') ||
            raw.startsWith('/')
        ? raw.replaceFirst(RegExp(r'^[\\/]+'), '')
        : raw;

    final candidate = path.normalize(path.join(docPath, relativePath));
    if (!path.isWithin(docPath, candidate) && docPath != candidate) {
      throw const FileSystemException(
          'jsonPath resolves outside documents directory');
    }
    return candidate;
  }

  Future<void> _emitChanged({
    required Set<String> ids,
    Set<String> notificationKeys = const <String>{},
  }) async {
    if (ids.isEmpty && notificationKeys.isEmpty) {
      return;
    }
    _emitEvent({
      'event': 'entitiesChanged',
      'ids': ids.toList(),
      'notificationKeys': notificationKeys.toList(),
    });
  }

  Future<JournalEntity> _loadJournalEntity(String jsonPath) async {
    final file = File(_resolveJsonPath(jsonPath));
    final raw = await file.readAsString();
    final decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('journal entity payload is not a JSON map');
    }
    return JournalEntity.fromJson(decoded);
  }

  Future<void> _handleJournalEntity(SyncJournalEntity msg) async {
    final journalEntity = await _loadJournalEntity(msg.jsonPath);
    await _journalDb.updateJournalEntity(journalEntity);

    final affectedIds = <String>{...journalEntity.affectedIds};

    await _processEmbeddedLinks(msg.entryLinks);
    final linkIds = <String>{};
    if (msg.entryLinks != null) {
      for (final link in msg.entryLinks!) {
        linkIds
          ..add(link.fromId)
          ..add(link.toId);
      }
    }

    if (linkIds.isNotEmpty) {
      affectedIds.addAll(linkIds);
    }
    affectedIds.add(labelUsageNotification);

    await _emitChanged(
      ids: affectedIds,
      notificationKeys: {
        labelUsageNotification,
        ...journalEntity.affectedIds,
      },
    );
  }

  Future<void> _processEmbeddedLinks(List<EntryLink>? entryLinks) async {
    if (entryLinks == null || entryLinks.isEmpty) {
      return;
    }

    for (final link in entryLinks) {
      await _journalDb.upsertEntryLink(link);
    }
  }

  Future<void> _handleEntryLink(SyncEntryLink msg) async {
    await _journalDb.upsertEntryLink(msg.entryLink);
    await _emitChanged(ids: {msg.entryLink.fromId, msg.entryLink.toId});
  }

  Future<void> _handleEntityDefinition(EntityDefinition definition) async {
    await _journalDb.upsertEntityDefinition(definition);
    final typeNotification = switch (definition) {
      CategoryDefinition() => categoriesNotification,
      HabitDefinition() => habitsNotification,
      DashboardDefinition() => dashboardsNotification,
      MeasurableDataType() => measurablesNotification,
      LabelDefinition() => labelsNotification,
    };
    await _emitChanged(
      ids: {definition.id, typeNotification},
      notificationKeys: {typeNotification},
    );
  }

  Future<void> _handleTagEntity(TagEntity tagEntity) async {
    await _journalDb.upsertTagEntity(tagEntity);
    await _emitChanged(
      ids: {tagEntity.id},
      notificationKeys: {tagsNotification},
    );
  }

  Future<void> _handleThemingSelection({
    required String lightThemeName,
    required String darkThemeName,
    required String themeMode,
    required int updatedAt,
  }) async {
    final existingUpdatedAtRaw =
        await _settingsDb.itemByKey(themePrefsUpdatedAtKey);
    final existingUpdatedAt = existingUpdatedAtRaw != null
        ? int.tryParse(existingUpdatedAtRaw) ?? 0
        : 0;
    if (updatedAt < existingUpdatedAt) return;

    final normalizedMode =
        EnumToString.fromString(ThemeMode.values, themeMode) ??
            ThemeMode.system;

    await _settingsDb.saveSettingsItem(lightSchemeNameKey, lightThemeName);
    await _settingsDb.saveSettingsItem(darkSchemeNameKey, darkThemeName);
    await _settingsDb.saveSettingsItem(
      themeModeKey,
      EnumToString.convertToString(normalizedMode),
    );
    await _settingsDb.saveSettingsItem(
      themePrefsUpdatedAtKey,
      updatedAt.toString(),
    );

    await _emitChanged(
      ids: {settingsNotification},
      notificationKeys: const {settingsNotification},
    );
  }
}
