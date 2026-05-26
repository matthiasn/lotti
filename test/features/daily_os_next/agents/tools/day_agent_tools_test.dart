import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tools.dart';

void main() {
  group('dayAgentTools', () {
    Map<String, dynamic> parametersFor(String name) {
      return dayAgentTools.singleWhere((tool) => tool.name == name).parameters;
    }

    List<dynamic> requiredFor(String name) {
      return parametersFor(name)['required'] as List<dynamic>;
    }

    test('defines every Daily OS backend tool once', () {
      final names = dayAgentTools.map((tool) => tool.name).toList();

      expect(names.toSet(), hasLength(names.length));
      expect(
        names,
        containsAll(const [
          DayAgentToolNames.recordObservations,
          DayAgentToolNames.setNextWake,
          DayAgentToolNames.submitCapture,
          DayAgentToolNames.parseCaptureToItems,
          DayAgentToolNames.matchToCorpus,
          DayAgentToolNames.linkCapturePhraseToTask,
          DayAgentToolNames.breakCaptureLink,
          DayAgentToolNames.surfacePendingDecisions,
          DayAgentToolNames.applyTriage,
          DayAgentToolNames.createTaskFromPhrase,
          DayAgentToolNames.draftDayPlan,
          DayAgentToolNames.summarizeRecentPatterns,
          DayAgentToolNames.proposePlanDiff,
          DayAgentToolNames.acceptDiff,
          DayAgentToolNames.revertDiff,
        ]),
      );
    });

    test('locks schemas to object inputs with no extra properties', () {
      for (final tool in dayAgentTools) {
        expect(tool.parameters['type'], 'object', reason: tool.name);
        expect(
          tool.parameters['additionalProperties'],
          isFalse,
          reason: tool.name,
        );
      }
    });

    test('requires the fields needed for capture and reconcile mutations', () {
      expect(
        requiredFor(DayAgentToolNames.submitCapture),
        containsAll(['transcript', 'capturedAt']),
      );
      expect(
        requiredFor(DayAgentToolNames.parseCaptureToItems),
        containsAll(['captureId', 'items']),
      );
      expect(
        requiredFor(DayAgentToolNames.linkCapturePhraseToTask),
        containsAll(['captureItemId', 'taskId']),
      );
      expect(
        requiredFor(DayAgentToolNames.breakCaptureLink),
        contains('captureItemId'),
      );
      expect(
        requiredFor(DayAgentToolNames.surfacePendingDecisions),
        contains('dayId'),
      );
      expect(
        requiredFor(DayAgentToolNames.applyTriage),
        containsAll(['taskId', 'action']),
      );
      expect(
        requiredFor(DayAgentToolNames.createTaskFromPhrase),
        containsAll(['phrase', 'category']),
      );
      expect(
        requiredFor(DayAgentToolNames.draftDayPlan),
        containsAll(['dayId', 'blocks']),
      );
    });

    test('parse_capture_to_items documents confidence thresholds', () {
      final items =
          (parametersFor(
                    DayAgentToolNames.parseCaptureToItems,
                  )['properties']
                  as Map<String, dynamic>)['items']
              as Map<String, dynamic>;
      final itemSchema = items['items'] as Map<String, dynamic>;
      final properties = itemSchema['properties'] as Map<String, dynamic>;
      final confidence = properties['confidenceScore'] as Map<String, dynamic>;

      expect(itemSchema['required'], contains('confidenceScore'));
      expect(confidence['minimum'], 0);
      expect(confidence['maximum'], 1);
    });

    test('draft_day_plan documents block and energy-band schemas', () {
      final properties =
          parametersFor(DayAgentToolNames.draftDayPlan)['properties']
              as Map<String, dynamic>;
      final blockSchema =
          (properties['blocks'] as Map<String, dynamic>)['items']
              as Map<String, dynamic>;
      final blockProperties = blockSchema['properties'] as Map<String, dynamic>;
      final energyBandSchema =
          (properties['energyBands'] as Map<String, dynamic>)['items']
              as Map<String, dynamic>;
      final energyBandProperties =
          energyBandSchema['properties'] as Map<String, dynamic>;

      expect(
        blockSchema['required'],
        containsAll(['title', 'categoryId', 'start', 'end', 'type']),
      );
      expect(blockSchema['additionalProperties'], isFalse);
      expect(
        (blockProperties['type'] as Map<String, dynamic>)['enum'],
        ['ai', 'cal', 'buffer', 'manual'],
      );
      expect(
        (blockProperties['state'] as Map<String, dynamic>)['enum'],
        ['drafted', 'committed', 'inProgress', 'completed', 'dropped'],
      );
      expect(
        energyBandSchema['required'],
        containsAll(['start', 'end', 'level', 'label']),
      );
      expect(energyBandSchema['additionalProperties'], isFalse);
      expect(
        (energyBandProperties['level'] as Map<String, dynamic>)['enum'],
        ['high', 'low', 'secondWind'],
      );
    });

    test('draft_day_plan taskId references drafting.decidedTasks', () {
      final properties =
          parametersFor(DayAgentToolNames.draftDayPlan)['properties']
              as Map<String, dynamic>;
      final blockProps =
          ((properties['blocks'] as Map<String, dynamic>)['items']
                  as Map<String, dynamic>)['properties']
              as Map<String, dynamic>;
      final taskIdSchema = blockProps['taskId'] as Map<String, dynamic>;

      expect(taskIdSchema['description'], isA<String>());
      expect(
        taskIdSchema['description'] as String,
        contains('drafting.decidedTasks'),
      );
    });

    test('propose_plan_diff documents change-shape schema', () {
      final properties =
          parametersFor(DayAgentToolNames.proposePlanDiff)['properties']
              as Map<String, dynamic>;
      final changeSchema =
          (properties['changes'] as Map<String, dynamic>)['items']
              as Map<String, dynamic>;
      final changeProperties =
          changeSchema['properties'] as Map<String, dynamic>;

      expect(
        requiredFor(DayAgentToolNames.proposePlanDiff),
        ['dayId', 'changes'],
      );
      expect(
        (properties['changes'] as Map<String, dynamic>)['minItems'],
        1,
      );
      expect(changeSchema['required'], ['action', 'reason']);
      expect(changeSchema['additionalProperties'], isFalse);
      expect(
        (changeProperties['action'] as Map<String, dynamic>)['enum'],
        ['moved', 'added', 'dropped'],
      );
      expect(
        (changeProperties['reason'] as Map<String, dynamic>)['minLength'],
        1,
      );
      final toProps =
          (changeProperties['to'] as Map<String, dynamic>)['properties']
              as Map<String, dynamic>;
      expect(toProps.keys, containsAll(['start', 'end', 'reason']));
    });

    test('accept_diff and revert_diff share the resolution schema', () {
      for (final name in const [
        DayAgentToolNames.acceptDiff,
        DayAgentToolNames.revertDiff,
      ]) {
        final params = parametersFor(name);
        expect(params['required'], ['changeSetId'], reason: name);
        expect(params['additionalProperties'], isFalse, reason: name);
        final indices =
            (params['properties'] as Map<String, dynamic>)['itemIndices']
                as Map<String, dynamic>;
        expect(indices['type'], 'array', reason: name);
        expect(
          (indices['items'] as Map<String, dynamic>)['type'],
          'integer',
          reason: name,
        );
        expect(
          (indices['items'] as Map<String, dynamic>)['minimum'],
          0,
          reason: name,
        );
      }
    });
  });
}
