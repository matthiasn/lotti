import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  group('ChecklistCompletionFunctions', () {
    group('getTools', () {
      test(
          'returns both suggest_checklist_completion and add_checklist_item tools',
          () {
        final tools = ChecklistCompletionFunctions.getTools();

        expect(tools.length, 2);
        expect(tools[0].type, ChatCompletionToolType.function);
        expect(tools[1].type, ChatCompletionToolType.function);

        // Check suggest_checklist_completion tool
        expect(tools[0].function.name,
            ChecklistCompletionFunctions.suggestChecklistCompletion);
        expect(
            tools[0].function.description,
            contains(
                'Suggest that a checklist item should be marked as completed'));

        final suggestParams = tools[0].function.parameters;
        expect(suggestParams, isA<Map<String, dynamic>>());
        final suggestParamsMap = suggestParams!;
        expect(suggestParamsMap['type'], 'object');
        expect(suggestParamsMap['required'],
            ['checklistItemId', 'reason', 'confidence']);

        final suggestProps = suggestParamsMap['properties'];
        expect(suggestProps, isA<Map<String, dynamic>>());
        final suggestPropsMap = suggestProps as Map<String, dynamic>;
        expect(suggestPropsMap.containsKey('checklistItemId'), true);
        expect(suggestPropsMap.containsKey('reason'), true);
        expect(suggestPropsMap.containsKey('confidence'), true);

        // Check add_checklist_item tool
        expect(tools[1].function.name,
            ChecklistCompletionFunctions.addChecklistItem);
        expect(tools[1].function.description,
            contains('Add a new checklist item to the task'));

        final addParams = tools[1].function.parameters;
        expect(addParams, isA<Map<String, dynamic>>());
        final addParamsMap = addParams!;
        expect(addParamsMap['type'], 'object');
        expect(addParamsMap['required'], ['actionItemDescription']);

        final addProps = addParamsMap['properties'];
        expect(addProps, isA<Map<String, dynamic>>());
        final addPropsMap = addProps as Map<String, dynamic>;
        expect(addPropsMap.containsKey('actionItemDescription'), true);
        final actionItemDescProp = addPropsMap['actionItemDescription'];
        expect(actionItemDescProp, isA<Map<String, dynamic>>());
        final actionItemDescMap = actionItemDescProp as Map<String, dynamic>;
        expect(actionItemDescMap['type'], 'string');
      });
    });

    group('ChecklistCompletionSuggestion', () {
      test('creates instance with all fields', () {
        const suggestion = ChecklistCompletionSuggestion(
          checklistItemId: 'item-123',
          reason: 'Task completed based on discussion',
          confidence: ChecklistCompletionConfidence.high,
        );

        expect(suggestion.checklistItemId, 'item-123');
        expect(suggestion.reason, 'Task completed based on discussion');
        expect(suggestion.confidence, ChecklistCompletionConfidence.high);
      });

      test('serializes to and from JSON', () {
        const suggestion = ChecklistCompletionSuggestion(
          checklistItemId: 'item-456',
          reason: 'Mentioned as done',
          confidence: ChecklistCompletionConfidence.medium,
        );

        final json = suggestion.toJson();
        expect(json['checklistItemId'], 'item-456');
        expect(json['reason'], 'Mentioned as done');
        expect(json['confidence'], 'medium');

        final decoded = ChecklistCompletionSuggestion.fromJson(json);
        expect(decoded.checklistItemId, suggestion.checklistItemId);
        expect(decoded.reason, suggestion.reason);
        expect(decoded.confidence, suggestion.confidence);
      });
    });

    group('AddChecklistItemResult', () {
      test('creates instance with all fields', () {
        const result = AddChecklistItemResult(
          checklistId: 'checklist-123',
          checklistItemId: 'item-789',
          checklistCreated: true,
        );

        expect(result.checklistId, 'checklist-123');
        expect(result.checklistItemId, 'item-789');
        expect(result.checklistCreated, true);
      });

      test('serializes to and from JSON', () {
        const result = AddChecklistItemResult(
          checklistId: 'checklist-456',
          checklistItemId: 'item-012',
          checklistCreated: false,
        );

        final json = result.toJson();
        expect(json['checklistId'], 'checklist-456');
        expect(json['checklistItemId'], 'item-012');
        expect(json['checklistCreated'], false);

        final decoded = AddChecklistItemResult.fromJson(json);
        expect(decoded.checklistId, result.checklistId);
        expect(decoded.checklistItemId, result.checklistItemId);
        expect(decoded.checklistCreated, result.checklistCreated);
      });
    });
  });
}
