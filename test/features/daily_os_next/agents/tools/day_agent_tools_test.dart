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
      // Pin the exact tool count so a tool added to dayAgentTools but missing
      // from the expected list below (or vice versa) is caught: containsAll
      // alone tolerates extras, hasLength closes that gap.
      expect(names, hasLength(18));
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
          DayAgentToolNames.commitDay,
          DayAgentToolNames.uncommitDay,
          DayAgentToolNames.proposeKnowledge,
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

    test(
      'propose_plan_diff documents action-specific required fields in the '
      'reason field (no JSON-Schema if/then/allOf because Gemini rejects '
      'those keywords in tool definitions)',
      () {
        final changeSchema =
            ((parametersFor(DayAgentToolNames.proposePlanDiff)['properties']
                        as Map<String, dynamic>)['changes']
                    as Map<String, dynamic>)['items']
                as Map<String, dynamic>;
        expect(changeSchema.containsKey('allOf'), isFalse);
        expect(changeSchema.containsKey('if'), isFalse);
        expect(changeSchema.containsKey('then'), isFalse);

        final reasonProp =
            (changeSchema['properties'] as Map<String, dynamic>)['reason']
                as Map<String, dynamic>;
        final description = reasonProp['description'] as String;
        expect(description, contains('moved'));
        expect(description, contains('dropped'));
        expect(description, contains('added'));
        expect(description, contains('blockId'));
        expect(description, contains('from'));
        expect(description, contains('to'));
      },
    );

    test('set_next_wake requires at and reason as ISO-8601 string fields', () {
      final params = parametersFor(DayAgentToolNames.setNextWake);
      expect(params['type'], 'object');
      expect(params['additionalProperties'], isFalse);
      expect(params['required'], ['at', 'reason']);

      final properties = params['properties'] as Map<String, dynamic>;
      expect(properties.keys, containsAll(['at', 'reason']));
      expect((properties['at'] as Map<String, dynamic>)['type'], 'string');
      expect((properties['reason'] as Map<String, dynamic>)['type'], 'string');
    });

    test('commit_day and uncommit_day require dayId only', () {
      for (final name in const [
        DayAgentToolNames.commitDay,
        DayAgentToolNames.uncommitDay,
      ]) {
        final params = parametersFor(name);
        expect(params['type'], 'object', reason: name);
        expect(params['required'], ['dayId'], reason: name);
        expect(params['additionalProperties'], isFalse, reason: name);
        final properties = params['properties'] as Map<String, dynamic>;
        expect(properties.keys, ['dayId'], reason: name);
        expect(
          (properties['dayId'] as Map<String, dynamic>)['type'],
          'string',
          reason: name,
        );
      }
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
    test(
      'recordObservations pins the oneOf item shape and its enum contracts',
      () {
        final params = parametersFor(DayAgentToolNames.recordObservations);
        expect(params['required'], ['observations']);

        final items =
            ((params['properties']! as Map<String, dynamic>)['observations']!
                    as Map<String, dynamic>)['items']!
                as Map<String, dynamic>;
        final oneOf = items['oneOf']! as List<dynamic>;
        expect(oneOf, hasLength(2));
        expect((oneOf[0] as Map<String, dynamic>)['type'], 'string');

        final objectShape = oneOf[1] as Map<String, dynamic>;
        expect(objectShape['type'], 'object');
        expect(objectShape['required'], ['text']);
        expect(objectShape['additionalProperties'], isFalse);

        final props = objectShape['properties']! as Map<String, dynamic>;
        expect(
          (props['priority']! as Map<String, dynamic>)['enum'],
          ['routine', 'notable', 'critical'],
        );
        expect(
          (props['category']! as Map<String, dynamic>)['enum'],
          ['grievance', 'excellence', 'templateImprovement', 'operational'],
        );
      },
    );

    test('applyTriage pins the action enum and the conditional deferTo', () {
      final params = parametersFor(DayAgentToolNames.applyTriage);
      expect(params['required'], ['taskId', 'action']);

      final props = params['properties']! as Map<String, dynamic>;
      expect(
        (props['action']! as Map<String, dynamic>)['enum'],
        ['today', 'doNow', 'defer', 'done', 'drop'],
      );
      // deferTo exists as an optional field — required only by the defer
      // action per the tool description, so it must NOT be in required.
      expect(props.containsKey('deferTo'), isTrue);
      expect(params['required'], isNot(contains('deferTo')));
    });
    test('nested item schemas keep their own strict contracts', () {
      // setNextWake: both fields required.
      expect(
        requiredFor(DayAgentToolNames.setNextWake),
        containsAll(['at', 'reason']),
      );

      // matchToCorpus: phrase required, categoryHint optional.
      final matchParams = parametersFor(DayAgentToolNames.matchToCorpus);
      expect(matchParams['required'], ['phrase']);
      expect(
        (matchParams['properties']! as Map<String, dynamic>).containsKey(
          'categoryHint',
        ),
        isTrue,
      );

      // parseCaptureToItems: the nested item object is itself strict.
      final parseParams = parametersFor(DayAgentToolNames.parseCaptureToItems);
      final parseItem =
          ((parseParams['properties']! as Map<String, dynamic>)['items']!
                  as Map<String, dynamic>)['items']!
              as Map<String, dynamic>;
      expect(parseItem['additionalProperties'], isFalse);
      expect(
        parseItem['required'],
        ['kind', 'title', 'categoryId', 'confidenceScore'],
      );

      // proposePlanDiff: the from/to sub-objects are strict too.
      final diffParams = parametersFor(DayAgentToolNames.proposePlanDiff);
      final changeProps =
          (((diffParams['properties']! as Map<String, dynamic>)['changes']!
                      as Map<String, dynamic>)['items']!
                  as Map<String, dynamic>)['properties']!
              as Map<String, dynamic>;
      expect(
        (changeProps['from']! as Map<String, dynamic>)['additionalProperties'],
        isFalse,
      );
      expect(
        (changeProps['to']! as Map<String, dynamic>)['additionalProperties'],
        isFalse,
      );
    });
  });
}
