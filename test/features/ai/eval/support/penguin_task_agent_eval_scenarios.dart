import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/demo/seed/demo_ids.dart';
import 'package:lotti/features/demo/seed/demo_seed_text.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';

import 'local_task_agent_inference_eval.dart';

/// Task-agent wake scenarios built from the penguin demo world.
///
/// The synthetic scenarios in `local_task_agent_inference_eval.dart` were
/// written for the eval alone. These reuse the content demo mode already
/// ships — enriched task descriptions, real checklists, linked notes — so a
/// model is measured against the same material a user sees on their first run.
///
/// English only: the demo world carries reviewed copy in eleven languages, but
/// a localized suite needs the wake instruction to come from that same
/// translated demo content rather than from fixtures authored here.
List<LocalTaskAgentEvalScenario> penguinTaskAgentEvalScenarios({
  List<LocalTaskAgentEvalPromptVariant> variants = const [
    LocalTaskAgentEvalPromptVariant.production,
  ],
}) {
  return [for (final variant in variants) _penguinScrubberScenario(variant)];
}

/// The deadline the wake instruction asks for.
const String _requestedDueDate = '2026-08-20';

const String _wakeInstruction =
    'The CO2 baseline is logged, so check that item off. Push the deadline to '
    'August 20, 2026 — the replacement cartridges only arrive on the 19th. '
    'The used cartridges still have to go back to stores.';

LocalTaskAgentEvalScenario _penguinScrubberScenario(
  LocalTaskAgentEvalPromptVariant variant,
) {
  final world = ManualDemoWorld.penguinLogistics(
    translate: demoSeedTextForLocale(const Locale('en')),
  );
  final task = world.tasks.firstWhere(
    (candidate) => candidate.meta.id == demoAirScrubbersTaskId,
  );
  final items = [
    for (var index = 0; index < 4; index++)
      world.checklistItems.firstWhere(
        (item) => item.meta.id == demoUuid('manual-scrubber-item-$index'),
      ),
  ];
  // Item 2 is the CO2 baseline the instruction reports as done; item 3 is the
  // cartridge return that must survive the wake untouched.
  final baselineItem = items[2];
  final pendingItem = items[3];

  final context = <String, Object?>{
    'id': task.meta.id,
    'title': task.data.title,
    'status': 'IN PROGRESS',
    'priority': 'P0',
    'dueDate': _formatDate(task.data.due),
    'languageCode': 'en',
    'description': task.entryText?.plainText,
    'checklist': [
      for (final item in items)
        {
          'id': item.meta.id,
          'title': item.data.title,
          'isChecked': item.data.isChecked,
          'lastModifiedBy': 'user',
        },
    ],
    'log': [
      {'timestamp': '2026-07-17T09:05:00Z', 'text': _wakeInstruction},
    ],
  };

  return LocalTaskAgentEvalScenario(
    id: 'penguin_scrubber_${variant.name}',
    systemPrompt: buildLocalTaskAgentEvalSystemPrompt(variant),
    userMessage:
        '''
## Current Task Context
```json
${const JsonEncoder.withIndent('  ').convert(context)}
```

## First Wake - No prior report exists. Produce an initial report.

## Changed Since Last Wake
The following entity IDs changed: ${task.meta.id}

Analyze the current state and follow the wake protocol.
''',
    expectedToolCalls: [
      LocalTaskAgentExpectedToolCall(
        name: TaskAgentToolNames.updateChecklistItems,
        expectedArgumentsSubset: {
          'items': [
            {'id': baselineItem.meta.id, 'isChecked': true},
          ],
        },
      ),
      const LocalTaskAgentExpectedToolCall(
        name: TaskAgentToolNames.updateTaskDueDate,
        expectedArgumentsSubset: {'dueDate': _requestedDueDate},
      ),
    ],
    promptVariant: variant,
    currentDueDate: _formatDate(task.data.due),
    currentPriority: 'P0',
    requiredReportTermGroups: const [
      ['cartridge'],
      ['co2'],
      ['2026-08-20', 'august 20', '20 august'],
    ],
    // Internal identifiers never belong in a user-facing report, and the
    // still-pending cartridge return must not be claimed as done.
    forbiddenReportTerms: [
      task.meta.id,
      baselineItem.meta.id,
      pendingItem.meta.id,
    ],
    forbiddenToolArgumentTerms: {
      TaskAgentToolNames.updateChecklistItems: [pendingItem.meta.id],
    },
  );
}

String? _formatDate(DateTime? date) {
  if (date == null) return null;
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
