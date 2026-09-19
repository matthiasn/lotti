// Behaviour of the individual handlers is exercised end to end through
// `TaskToolDispatcher.dispatch` in `task_tool_dispatcher_test.dart`; this file
// pins the contracts of the handler extension that dispatch cannot reach.
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_tool_dispatcher.dart';
import 'package:lotti/features/agents/workflow/task_tool_handlers.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  group('handleProcessToolCall', () {
    test(
      'fails loudly for a tool the estimate/due-date/priority path does not '
      'handle instead of silently dropping it',
      () async {
        final dispatcher = TaskToolDispatcher(
          journalDb: MockJournalDb(),
          journalRepository: MockJournalRepository(),
          checklistRepository: MockChecklistRepository(),
          labelsRepository: MockLabelsRepository(),
          persistenceLogic: MockPersistenceLogic(),
          timeService: MockTimeService(),
        );

        await expectLater(
          dispatcher.handleProcessToolCall(
            testTask,
            TaskAgentToolNames.setTaskTitle,
            {'title': 'Waddle to the feeder'},
            testTask.meta.id,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains(TaskAgentToolNames.setTaskTitle),
            ),
          ),
        );
      },
    );
  });
}
