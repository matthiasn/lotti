import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/services/db_notification.dart';

import '../helpers/entity_factories.dart';

void main() {
  final fixedDate = DateTime(2024, 3, 15, 10);
  final meta = TestMetadataFactory.create(
    id: 'entity-1',
    categoryId: 'cat-1',
  );

  group('AudioTranscript.fromJson', () {
    test('round-trips all fields through JSON', () {
      final transcript = AudioTranscript(
        created: fixedDate,
        library: 'whisper',
        model: 'large-v3',
        detectedLanguage: 'en',
        transcript: 'hello world',
        processingTime: const Duration(seconds: 12),
      );

      final decoded = AudioTranscript.fromJson(
        jsonDecode(jsonEncode(transcript.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.created, fixedDate);
      expect(decoded.library, 'whisper');
      expect(decoded.model, 'large-v3');
      expect(decoded.detectedLanguage, 'en');
      expect(decoded.transcript, 'hello world');
      expect(decoded.processingTime, const Duration(seconds: 12));
      expect(decoded, transcript);
    });

    test('parses minimal JSON with null optional processingTime', () {
      final decoded = AudioTranscript.fromJson(<String, dynamic>{
        'created': fixedDate.toIso8601String(),
        'library': 'lib',
        'model': 'm',
        'detectedLanguage': 'de',
        'transcript': 'hallo',
      });

      expect(decoded.processingTime, isNull);
      expect(decoded.detectedLanguage, 'de');
      expect(decoded.transcript, 'hallo');
    });
  });

  group('JournalEntityExtension simple getters', () {
    test('id, categoryId and isDeleted reflect metadata', () {
      final entry = JournalEntity.journalEntry(meta: meta);
      expect(entry.id, 'entity-1');
      expect(entry.categoryId, 'cat-1');
      expect(entry.isDeleted, isFalse);

      final deleted = JournalEntity.journalEntry(
        meta: TestMetadataFactory.create(id: 'gone').copyWith(
          deletedAt: fixedDate,
        ),
      );
      expect(deleted.isDeleted, isTrue);
    });
  });

  group('JournalEntityExtension affectedIds', () {
    test('checklistItem includes id and linked checklists (line 244)', () {
      final entity = JournalEntity.checklistItem(
        meta: meta,
        data: const ChecklistItemData(
          title: 'Buy milk',
          isChecked: false,
          linkedChecklists: ['cl-a', 'cl-b'],
        ),
      );

      expect(
        entity.affectedIds,
        <String>{'entity-1', 'cl-a', 'cl-b'},
      );
    });

    test('dayPlan includes id and dayPlanNotification (line 279)', () {
      final entity = JournalEntity.dayPlan(
        meta: meta,
        data: DayPlanData(
          planDate: fixedDate,
          status: const DayPlanStatus.draft(),
        ),
      );

      expect(
        entity.affectedIds,
        <String>{'entity-1', dayPlanNotification},
      );
    });

    test('checklist includes linked items and linked tasks', () {
      final entity = JournalEntity.checklist(
        meta: meta,
        data: const ChecklistData(
          title: 'Groceries',
          linkedChecklistItems: ['item-1', 'item-2'],
          linkedTasks: ['task-1'],
        ),
      );

      expect(
        entity.affectedIds,
        <String>{'entity-1', 'item-1', 'item-2', 'task-1'},
      );
    });

    test('journalEntry includes textEntryNotification', () {
      final entity = JournalEntity.journalEntry(meta: meta);

      expect(
        entity.affectedIds,
        <String>{'entity-1', textEntryNotification},
      );
    });
  });
}
