import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_input.dart';

/// Full JSON round-trip through encode/decode so nested freezed objects are
/// serialized to plain maps (the models do not use explicitToJson).
Map<String, dynamic> _roundTrip(Object value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

void main() {
  group('AiInput model JSON round-trips', () {
    final actionItem = AiActionItem(
      title: 'Write tests',
      completed: true,
      isArchived: true,
      id: 'item-1',
      deadline: DateTime(2024, 3, 20),
      completionDate: DateTime(2024, 3, 18),
      checkedBy: 'agent',
      checkedAt: DateTime(2024, 3, 18, 9),
    );

    test('AiActionItem survives a JSON round-trip', () {
      expect(AiActionItem.fromJson(_roundTrip(actionItem)), actionItem);
    });

    test('AiInputLogEntryObject survives a round-trip', () {
      final entry = AiInputLogEntryObject(
        creationTimestamp: DateTime(2024, 3, 15, 8, 30),
        loggedDuration: '00:45',
        text: 'Did some work',
        audioTranscript: 'transcript',
        transcriptLanguage: 'en',
        entryType: 'text',
      );
      expect(AiInputLogEntryObject.fromJson(_roundTrip(entry)), entry);
    });

    test('AiInputActionItemsList survives a round-trip', () {
      final list = AiInputActionItemsList(items: [actionItem]);
      final decoded = AiInputActionItemsList.fromJson(_roundTrip(list));
      expect(decoded, list);
      expect(decoded.items.single.title, 'Write tests');
    });

    test('AiInputTaskObject survives a round-trip with nested items', () {
      final task = AiInputTaskObject(
        title: 'Ship feature',
        status: 'IN PROGRESS',
        priority: 'HIGH',
        estimatedDuration: '02:00',
        timeSpent: '01:15',
        creationDate: DateTime(2024, 3, 10, 12),
        actionItems: [actionItem],
        logEntries: [
          AiInputLogEntryObject(
            creationTimestamp: DateTime(2024, 3, 11),
            loggedDuration: '00:30',
            text: 'progress',
          ),
        ],
        dueDate: DateTime(2024, 3, 25),
        languageCode: 'en',
      );

      final decoded = AiInputTaskObject.fromJson(_roundTrip(task));
      expect(decoded, task);
      expect(decoded.actionItems.single.id, 'item-1');
      expect(decoded.logEntries.single.text, 'progress');
    });

    test('AiLinkedTaskContext survives a round-trip', () {
      final context = AiLinkedTaskContext(
        id: 'task-9',
        title: 'Parent task',
        status: 'OPEN',
        statusSince: DateTime(2024, 3),
        priority: 'LOW',
        estimate: '03:00',
        timeSpent: '00:00',
        createdAt: DateTime(2024, 2, 28),
        labels: const [
          {'name': 'backend'},
        ],
        languageCode: 'de',
        latestSummary: 'a summary',
      );
      expect(AiLinkedTaskContext.fromJson(_roundTrip(context)), context);
    });
  });
}
