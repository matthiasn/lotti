import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';

import '../../../helpers/fallbacks.dart';
import 'support/penguin_wake_world_seed.dart';
import 'support/task_agent_workflow_eval_harness.dart';

/// Covers the real-database eval harness without needing a provider.
///
/// The live workflow eval is tagged `eval-live` and never runs in CI, so
/// without this the seeding, the GetIt wiring and the real context builder
/// would only ever be exercised by hand. A break in any of them would surface
/// as a confusing live-run failure attributed to the model.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAllFallbackValues);

  late ProviderContainer container;
  late TaskAgentWorkflowEvalHarness harness;

  setUp(() async {
    container = ProviderContainer();
    harness = await TaskAgentWorkflowEvalHarness.start(container: container);
  });

  tearDown(() async {
    await harness.dispose();
    container.dispose();
  });

  group('TaskAgentWorkflowEvalHarness', () {
    test(
      'seeds the wake task with its full checklist into a real db',
      () async {
        final stored = await harness.journalDb.journalEntityById(
          harness.world.taskId,
        );

        expect(stored, isA<Task>());
        final task = stored! as Task;
        expect(task.data.status, isA<TaskBlocked>());
        expect(task.data.due, penguinWakeDueDate);
        // Three lists, fourteen items, six of them already done by the user.
        expect(task.data.checklistIds, hasLength(3));
        expect(harness.world.checkedItemIds, hasLength(6));
        expect(harness.world.pendingItemIds, hasLength(8));
      },
    );

    test(
      'links every note to the task so the context can reach them',
      () async {
        final linked = await harness.journalDb.getLinkedEntities(
          harness.world.taskId,
        );
        final linkedIds = linked.map((entity) => entity.meta.id).toSet();

        for (final noteId in harness.world.noteIds) {
          expect(
            linkedIds,
            contains(noteId),
            reason: 'note $noteId must be reachable from the task',
          );
        }
      },
    );

    test('the real context builder produces a mid-sized wake', () async {
      final context = await harness.buildTaskContextJson();

      expect(context, isNotNull);
      final json = context!;

      // The whole point of the harness. The hand-written fixture it replaces
      // was 921-2,207 characters with an empty checklist; a real wake carries
      // the description, three checklists and three weeks of notes.
      // Measured at 9,004 characters against the 921-2,207 the synthetic
      // scenarios carry. The floor is what matters: if a change to the context
      // builder quietly drops the checklists or the linked notes, the suite
      // goes back to measuring models on a quarter of a real wake without
      // anyone noticing.
      expect(
        json.length,
        greaterThan(6000),
        reason: 'a real context should dwarf the old hand-written fixture',
      );

      // Built, not declared: these strings exist only in the seeded rows.
      expect(json, contains('Bay C'));
      expect(json, contains('Run a 24-hour hold test'));
      expect(
        json,
        contains('Reseat the door gasket'),
        reason: 'checklist items must reach the model through the real builder',
      );
    });

    test('the context carries the contradiction the wake turns on', () async {
      final json = (await harness.buildTaskContextJson())!;

      // The superseded request and the instruction that overrides it must both
      // be present, or the restraint trap tests nothing.
      expect(
        json,
        contains('August 14'),
        reason: 'the superseded deadline request must be visible',
      );
      expect(
        json,
        contains('still holds'),
        reason: 'the instruction overriding it must be visible',
      );
    });

    test(
      'the agent and its state are stored in a real agent database',
      () async {
        final agent = await harness.agentRepository.getEntity(harness.agentId);

        expect(agent, isNotNull);
        expect(
          agent,
          isA<AgentIdentityEntity>().having(
            (entity) => entity.allowedCategoryIds,
            'allowedCategoryIds',
            contains(harness.world.categoryId),
          ),
          reason:
              'category policy must permit the seeded task, or every '
              'mutation is denied and the run measures nothing',
        );
      },
    );
  });
}
