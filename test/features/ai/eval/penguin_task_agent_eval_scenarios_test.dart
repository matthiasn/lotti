import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/demo/seed/demo_ids.dart';
import 'package:lotti/features/demo/seed/demo_seed_text.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';

import 'support/local_task_agent_inference_eval.dart';
import 'support/penguin_task_agent_eval_scenarios.dart';

void main() {
  group('penguinTaskAgentEvalScenarios', () {
    final scenarios = penguinTaskAgentEvalScenarios();
    final scenario = scenarios.single;
    final world = ManualDemoWorld.penguinLogistics(
      translate: demoSeedTextForLocale(const Locale('en')),
    );
    final task = world.tasks.firstWhere(
      (candidate) => candidate.meta.id == demoAirScrubbersTaskId,
    );

    test('reuses the demo world task rather than a bespoke fixture', () {
      expect(scenario.userMessage, contains(task.data.title));
      expect(scenario.userMessage, contains(task.meta.id));
      // The enriched description is what gives the agent enough context to
      // act on; the one-line stub this task used to carry would not.
      final description = task.entryText!.plainText;
      expect(description.length, greaterThan(240));
      expect(scenario.userMessage, contains(description));
    });

    test('presents the full checklist with its real completion state', () {
      final items = [
        for (var index = 0; index < 4; index++)
          world.checklistItems.firstWhere(
            (item) => item.meta.id == demoUuid('manual-scrubber-item-$index'),
          ),
      ];
      for (final item in items) {
        expect(scenario.userMessage, contains(item.data.title));
        expect(scenario.userMessage, contains(item.meta.id));
      }
      // Two done, two open: the wake has to complete exactly one more.
      expect(items.where((item) => item.data.isChecked), hasLength(2));
    });

    test('requires completing the baseline item and moving the deadline', () {
      final byName = {
        for (final call in scenario.expectedToolCalls)
          call.name: call.expectedArgumentsSubset,
      };
      expect(byName[TaskAgentToolNames.updateChecklistItems], {
        'items': [
          {'id': demoUuid('manual-scrubber-item-2'), 'isChecked': true},
        ],
      });
      expect(byName[TaskAgentToolNames.updateTaskDueDate], {
        'dueDate': '2026-08-20',
      });
      // The requested deadline has to actually differ from the seeded one,
      // or the mutation check would pass without the model doing anything.
      expect(scenario.currentDueDate, isNot('2026-08-20'));
    });

    test('protects the item the instruction leaves pending', () {
      final pendingItemId = demoUuid('manual-scrubber-item-3');
      expect(
        scenario.forbiddenToolArgumentTerms[TaskAgentToolNames
            .updateChecklistItems],
        contains(pendingItemId),
      );
      expect(scenario.forbiddenReportTerms, contains(pendingItemId));
      expect(scenario.forbiddenReportTerms, contains(task.meta.id));
    });

    test('builds a production first-wake request', () {
      expect(scenario.isFirstWake, isTrue);
      expect(scenario.requiresReport, isTrue);
      expect(scenario.currentPriority, 'P0');
      expect(scenario.systemPrompt, isNotEmpty);
      expect(
        scenario.promptVariant,
        LocalTaskAgentEvalPromptVariant.production,
      );
      expect(scenario.userMessage, contains('First Wake'));
      expect(scenario.id, 'penguin_scrubber_production');
    });
  });
}
