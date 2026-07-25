import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../ai_consumption/test_utils.dart';

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
Future<void> setUpEvalGetIt(AiInteractionCaptureTestBench attribution) async {
  final persistenceLogic = MockPersistenceLogic();
  // `create_task_from_phrase` materialises through this. Null is a clean
  // "no task was created" the tool handler already copes with.
  when(
    () => persistenceLogic.createTaskEntry(
      data: any(named: 'data'),
      entryText: any(named: 'entryText'),
      linkedId: any(named: 'linkedId'),
      categoryId: any(named: 'categoryId'),
      labelIds: any(named: 'labelIds'),
      private: any(named: 'private'),
    ),
  ).thenAnswer((_) async => null);

  await setUpTestGetIt(
    additionalSetup: () {
      getIt
        ..registerSingleton<PersistenceLogic>(persistenceLogic)
        ..registerSingleton<TimeService>(TimeService());
      attribution.register();
    },
  );
}
