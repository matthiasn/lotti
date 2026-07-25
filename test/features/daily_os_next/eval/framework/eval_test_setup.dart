import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../ai_consumption/test_utils.dart';
import 'eval_journal_fixture.dart';

/// Shared `getIt` setup for any eval run, live or scripted.
///
/// Exists because of what the first live run found: a drafting wake offers the
/// model far more than `draft_day_plan` — the whole capture/reconcile set is
/// enabled whenever a capture service is wired — and glm-5.2 used it,
/// reaching for `parse_capture_to_items`, `surface_pending_decisions`,
/// `summarize_recent_patterns` and `create_task_from_phrase` before drafting.
///
/// Every one of those lands on a collaborator the eval mocks. An unstubbed
/// mocktail method returns a bare `null` where a `Future<...>` is expected, so
/// the tool call came back to the model as
/// `type 'Null' is not a subtype of type 'Future<Task?>'` — a **harness defect
/// delivered as a rejection**, which is exactly the signal
/// `compliedWithoutRejection` scores. The first run read 13% on that
/// constraint, most of it this.
///
/// So the rule for this file: any collaborator a model-reachable tool can hit
/// must answer, even if the answer is "nothing". Returning null from a stubbed
/// `createTaskEntry` tells the model the creation did not happen, which it can
/// act on; throwing a Dart type error tells it nothing and corrupts the score.
int _createdTaskCount = 0;

Future<void> setUpEvalGetIt(AiInteractionCaptureTestBench attribution) async {
  _createdTaskCount = 0;
  final persistenceLogic = MockPersistenceLogic();
  // `create_task_from_phrase` materialises through this. It returns a real
  // Task rather than null: null makes the tool answer "failed to create
  // task", which reaches the model as a rejection and is indistinguishable in
  // the score from the model having done something wrong. In the app the
  // creation succeeds, so the faithful stub is one that succeeds.
  when(
    () => persistenceLogic.createTaskEntry(
      data: any(named: 'data'),
      entryText: any(named: 'entryText'),
      linkedId: any(named: 'linkedId'),
      categoryId: any(named: 'categoryId'),
      labelIds: any(named: 'labelIds'),
      private: any(named: 'private'),
    ),
  ).thenAnswer((invocation) async {
    final data = invocation.namedArguments[#data] as TaskData;
    final entryText = invocation.namedArguments[#entryText] as EntryText;
    final categoryId = invocation.namedArguments[#categoryId] as String?;
    final createdAt = data.dateFrom;
    final task = Task(
      meta: Metadata(
        // Sequential, not title-derived: two tasks with the same title would
        // otherwise collapse onto one id and the second would overwrite the
        // first. Stable across a run, so a report stays readable.
        id: 'eval-created-${++_createdTaskCount}',
        createdAt: createdAt,
        updatedAt: createdAt,
        dateFrom: data.dateFrom,
        dateTo: data.dateTo,
        categoryId: categoryId,
      ),
      data: data,
      entryText: entryText,
    );
    // Into the cell's journal, or the model is handed an id and then told it
    // does not exist: `DayAgentPlanWriter` resolves allowed task references
    // through `journalEntityMapForIds`, so an unstored task makes
    // `draft_day_plan` reject a placement the app would have accepted.
    currentEvalJournal.add(task);
    return task;
  });

  await setUpTestGetIt(
    additionalSetup: () {
      getIt
        ..registerSingleton<PersistenceLogic>(persistenceLogic)
        ..registerSingleton<TimeService>(TimeService());
      attribution.register();
    },
  );
}
