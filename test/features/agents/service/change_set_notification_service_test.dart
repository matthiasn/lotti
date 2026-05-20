import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/service/change_set_notification_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../projects/test_utils.dart' as project_test;
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockNotificationRepository notificationRepository;
  late MockJournalDb journalDb;
  late ChangeSetNotificationService service;

  setUp(() {
    notificationRepository = MockNotificationRepository();
    journalDb = MockJournalDb();

    when(
      () => notificationRepository.notificationIdForTaskSuggestion(any()),
    ).thenAnswer((invocation) {
      final seed = invocation.positionalArguments.single as String;
      return 'notification-$seed';
    });
    when(
      () => notificationRepository.markActedOn(any()),
    ).thenAnswer((_) async => null);
    when(
      () => notificationRepository.markTaskSuggestionsActedOn(any()),
    ).thenAnswer((_) async => const []);
    when(
      () => notificationRepository.retract(any()),
    ).thenAnswer((_) async => null);
    when(
      () => notificationRepository.retractTaskSuggestionsForTask(any()),
    ).thenAnswer((_) async => const []);
    when(
      () => notificationRepository.createTaskSuggestion(
        linkedTaskId: any(named: 'linkedTaskId'),
        suggestionCount: any(named: 'suggestionCount'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledFor: any(named: 'scheduledFor'),
        category: any(named: 'category'),
        idSeed: any(named: 'idSeed'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => journalDb.journalEntityById(any()),
    ).thenAnswer((_) async => null);

    service = ChangeSetNotificationService(
      notificationRepository: notificationRepository,
      journalDb: journalDb,
    );
  });

  test(
    'marks task-suggestion notifications acted-on after user resolution',
    () async {
      final changeSet = makeTestChangeSet(
        id: 'cs-user-done',
        items: const [
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'Done'},
            humanSummary: 'Rename task',
            status: ChangeItemStatus.confirmed,
          ),
        ],
      );

      await service.syncAfterUserDecision(changeSet);

      verify(
        () => notificationRepository.markTaskSuggestionsActedOn('task-001'),
      ).called(1);
      verifyNever(
        () => notificationRepository.createTaskSuggestion(
          linkedTaskId: any(named: 'linkedTaskId'),
          suggestionCount: any(named: 'suggestionCount'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledFor: any(named: 'scheduledFor'),
          category: any(named: 'category'),
          idSeed: any(named: 'idSeed'),
        ),
      );
    },
  );

  test(
    'retracts task-suggestion notifications after agent retraction',
    () async {
      final changeSet = makeTestChangeSet(
        id: 'cs-agent-gone',
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 30},
            humanSummary: 'Set estimate',
            status: ChangeItemStatus.retracted,
          ),
        ],
      );

      await service.syncAfterAgentRetraction(changeSet);

      verify(
        () => notificationRepository.retractTaskSuggestionsForTask('task-001'),
      ).called(1);
      verifyNever(
        () => notificationRepository.markTaskSuggestionsActedOn(any()),
      );
    },
  );

  test(
    'refreshes the seeded notification with the remaining pending count',
    () async {
      when(() => journalDb.journalEntityById('task-partial')).thenAnswer(
        (_) async => project_test.makeTestTask(
          id: 'task-partial',
          title: 'Design Review for Florian',
        ),
      );

      final changeSet = makeTestChangeSet(
        id: 'cs-partial',
        taskId: 'task-partial',
        items: const [
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'Done'},
            humanSummary: 'Rename task',
            status: ChangeItemStatus.confirmed,
          ),
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 30},
            humanSummary: 'Set estimate',
          ),
          ChangeItem(
            toolName: 'update_task_priority',
            args: {'priority': 'P2'},
            humanSummary: 'Set priority',
            status: ChangeItemStatus.rejected,
          ),
        ],
      );

      await service.syncAfterUserDecision(changeSet);

      final captured = verify(
        () => notificationRepository.createTaskSuggestion(
          linkedTaskId: 'task-partial',
          suggestionCount: 1,
          title: captureAny(named: 'title'),
          body: 'Design Review for Florian',
          category: any(named: 'category'),
          idSeed: 'cs-partial',
        ),
      ).captured;
      expect(captured.single, isA<String>());
      expect(captured.single as String, isNotEmpty);
      verifyNever(() => notificationRepository.markActedOn(any()));
      verifyNever(() => notificationRepository.retract(any()));
    },
  );

  test(
    'uses fallback body and no category when task metadata is unavailable',
    () async {
      final changeSet = makeTestChangeSet(
        id: 'cs-missing-task',
        taskId: 'task-missing',
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 30},
            humanSummary: 'Set estimate',
          ),
        ],
      );

      await service.syncAfterUserDecision(changeSet);

      final captured = verify(
        () => notificationRepository.createTaskSuggestion(
          linkedTaskId: 'task-missing',
          suggestionCount: 1,
          title: any(named: 'title'),
          body: captureAny(named: 'body'),
          category: captureAny(named: 'category'),
          idSeed: 'cs-missing-task',
        ),
      ).captured;
      expect(captured, hasLength(2));
      expect(captured[0], isA<String>());
      expect(captured[0] as String, isNotEmpty);
      expect(captured[1], isNull);
    },
  );

  testWidgets(
    'falls back to a supported locale when the platform locale is unsupported',
    (tester) async {
      tester.binding.platformDispatcher.localeTestValue = const ui.Locale('zz');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

      final changeSet = makeTestChangeSet(
        id: 'cs-unsupported-locale',
        taskId: 'task-unsupported-locale',
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 30},
            humanSummary: 'Set estimate',
          ),
        ],
      );

      await service.syncAfterUserDecision(changeSet);

      final captured = verify(
        () => notificationRepository.createTaskSuggestion(
          linkedTaskId: 'task-unsupported-locale',
          suggestionCount: 1,
          title: captureAny(named: 'title'),
          body: captureAny(named: 'body'),
          category: any(named: 'category'),
          idSeed: 'cs-unsupported-locale',
        ),
      ).captured;
      expect(captured, hasLength(2));
      expect(captured[0], '1 suggestion needs your attention');
      expect(captured[1], 'Open the task to review.');
    },
  );
}
