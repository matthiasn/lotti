import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/settings/constants/theming_settings_keys.dart';
import 'package:lotti/features/sync/actor/inbound_processor.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

class MockJournalDb extends Mock implements JournalDb {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockEvent extends Mock implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      JournalEntity.journalEntry(
        meta: Metadata(
          id: 'fallback-entry',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        entryText: const EntryText(plainText: ''),
      ),
    );
    registerFallbackValue(
      TagEntity.genericTag(
        id: 'fallback-tag',
        tag: 'fallback',
        private: false,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: const VectorClock({}),
      ),
    );
  });

  group('InboundProcessor', () {
    late Directory documentsDirectory;
    late MockJournalDb journalDb;
    late MockSettingsDb settingsDb;

    setUp(() {
      documentsDirectory = Directory.systemTemp.createTempSync(
        'inbound_processor_test_',
      );
      journalDb = MockJournalDb();
      settingsDb = MockSettingsDb();
    });

    tearDown(() async {
      if (documentsDirectory.existsSync()) {
        documentsDirectory.deleteSync(recursive: true);
      }
    });

    final events = <Map<String, Object?>>[];

    Future<InboundProcessor> createProcessor() async {
      events.clear();
      return InboundProcessor(
        journalDb: journalDb,
        settingsDb: settingsDb,
        documentsDirectory: documentsDirectory,
        emitEvent: events.add,
      );
    }

    test('processes journal entities and emits affected IDs', () async {
      final payloadPath = path.join('sync_payloads', 'entity.json');
      final entry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'entity-1',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        entryText: const EntryText(plainText: 'sync payload'),
      );
      final jsonFile = File(path.join(documentsDirectory.path, payloadPath));
      await jsonFile.parent.create(recursive: true);
      await jsonFile.writeAsString(jsonEncode(entry.toJson()));

      when(() => journalDb.updateJournalEntity(any())).thenAnswer(
        (_) async => JournalUpdateResult.applied(rowsWritten: 1),
      );

      final processor = await createProcessor();
      final syncMessage = SyncMessage.journalEntity(
        id: 'entity-1',
        status: SyncEntryStatus.initial,
        jsonPath: payloadPath,
        vectorClock: const VectorClock({}),
      );

      final mockEvent = MockEvent();
      when(() => mockEvent.type).thenReturn('m.room.message');
      when(() => mockEvent.messageType).thenReturn(syncMessageType);
      when(() => mockEvent.text).thenReturn(
        base64.encode(utf8.encode(jsonEncode(syncMessage.toJson()))),
      );
      when(() => mockEvent.content).thenReturn(<String, dynamic>{});

      await processor.processTimelineEvent(mockEvent);

      final entitiesChanged =
          events.where((event) => event['event'] == 'entitiesChanged');
      expect(entitiesChanged, hasLength(1));
      final entityEvent = entitiesChanged.single;
      expect(entityEvent['ids'], contains('entity-1'));
      expect(entityEvent['notificationKeys'], contains(textEntryNotification));
      expect(
        entityEvent['notificationKeys'],
        contains(labelUsageNotification),
      );

      verify(() => journalDb.updateJournalEntity(any())).called(1);
      verifyNoMoreInteractions(settingsDb);
    });

    test('falls back to message body for payload text', () async {
      when(() => journalDb.upsertTagEntity(any())).thenAnswer((_) async => 1);

      final processor = await createProcessor();
      final syncMessage = SyncMessage.tagEntity(
        tagEntity: TagEntity.genericTag(
          id: 'tag-1',
          tag: 'Test Tag',
          private: false,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: const VectorClock({}),
        ),
        status: SyncEntryStatus.initial,
      );

      final mockEvent = MockEvent();
      when(() => mockEvent.type).thenReturn('m.room.message');
      when(() => mockEvent.messageType).thenReturn(syncMessageType);
      when(() => mockEvent.text).thenReturn('');
      when(() => mockEvent.content).thenReturn(<String, dynamic>{
        'body': base64.encode(utf8.encode(jsonEncode(syncMessage.toJson()))),
      });

      await processor.processTimelineEvent(mockEvent);

      final entitiesChanged =
          events.where((event) => event['event'] == 'entitiesChanged');
      expect(entitiesChanged, hasLength(1));
      final entityEvent = entitiesChanged.single;
      expect(entityEvent['ids'], contains('tag-1'));
      verify(() => journalDb.upsertTagEntity(any())).called(1);
    });

    test('handles outdated theming selection by skipping update', () async {
      when(() => settingsDb.itemByKey(themePrefsUpdatedAtKey))
          .thenAnswer((_) async => '200');
      when(() => settingsDb.saveSettingsItem(any(), any())).thenAnswer(
        (_) async => 1,
      );

      final processor = await createProcessor();
      const syncMessage = SyncThemingSelection(
        lightThemeName: 'light',
        darkThemeName: 'dark',
        themeMode: 'dark',
        updatedAt: 100,
        status: SyncEntryStatus.initial,
      );
      final mockEvent = MockEvent();
      when(() => mockEvent.type).thenReturn('m.room.message');
      when(() => mockEvent.messageType).thenReturn(syncMessageType);
      when(() => mockEvent.text).thenReturn(
        base64.encode(utf8.encode(jsonEncode(syncMessage.toJson()))),
      );
      when(() => mockEvent.content).thenReturn(<String, dynamic>{});

      await processor.processTimelineEvent(mockEvent);

      verifyNever(() => settingsDb.saveSettingsItem(any(), any()));
      expect(events, isEmpty);
    });

    test('stores newer theming selection and emits notification', () async {
      when(() => settingsDb.itemByKey(themePrefsUpdatedAtKey))
          .thenAnswer((_) async => '100');
      when(() => settingsDb.saveSettingsItem(any(), any())).thenAnswer(
        (_) async => 1,
      );

      final processor = await createProcessor();
      const syncMessage = SyncThemingSelection(
        lightThemeName: 'light',
        darkThemeName: 'dark',
        themeMode: 'dark',
        updatedAt: 200,
        status: SyncEntryStatus.initial,
      );
      final mockEvent = MockEvent();
      when(() => mockEvent.type).thenReturn('m.room.message');
      when(() => mockEvent.messageType).thenReturn(syncMessageType);
      when(() => mockEvent.text).thenReturn(
        base64.encode(utf8.encode(jsonEncode(syncMessage.toJson()))),
      );
      when(() => mockEvent.content).thenReturn(<String, dynamic>{});

      await processor.processTimelineEvent(mockEvent);

      expect(
        events.singleWhere(
            (event) => event['event'] == 'entitiesChanged')['notificationKeys'],
        contains(settingsNotification),
      );
      verify(() => settingsDb.saveSettingsItem(lightSchemeNameKey, 'light'))
          .called(
        1,
      );
      verify(() => settingsDb.saveSettingsItem(darkSchemeNameKey, 'dark'))
          .called(1);
      verify(() => settingsDb.saveSettingsItem(themeModeKey, 'dark')).called(1);
      verify(() => settingsDb.saveSettingsItem(themePrefsUpdatedAtKey, '200'))
          .called(
        1,
      );
    });
  });
}
