import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/query/query_task_action_context.dart';

import 'penguin_query_eval.dart';
import 'query_action_eval.dart';
import 'query_action_eval_fixture.dart';

void main() {
  test(
    'fixed overlay supplies owned targets and excludes the cross-category link',
    () async {
      final corpus = PenguinQueryCorpus();
      final before = corpus.inventory.toString();
      final database = PenguinQueryDatabase(corpus);
      addTearDown(database.close);
      await database.seed();
      final fixture = QueryActionEvalFixture(database);
      final hash = fixture.hash;
      await fixture.seed();
      final loader = QueryTaskActionContextLoader(access: database.access);
      final context = await loader.load(
        corpus.task.meta.id,
        runningTimerId: ActionEvalIds.timer,
      );
      expect(context.checklistIds, {
        ActionEvalIds.feeder,
        ActionEvalIds.sensor,
      });
      expect(context.taskIds, contains(ActionEvalIds.target));
      expect(context.taskIds, isNot(contains(ActionEvalIds.foreign)));
      expect(context.labelIds, contains(ActionEvalIds.label));
      expect(context.timeEntryIds, contains(ActionEvalIds.session));
      expect(context.timeEntryIds, isNot(contains(ActionEvalIds.timer)));
      expect(context.runningTimerId, ActionEvalIds.timer);
      expect(
        context.input.toString(),
        isNot(contains('Private medical appointment')),
      );
      expect(corpus.inventory.toString(), before);
      expect(fixture.hash, hash);

      await fixture.reset(
        queryActionEvalCases.singleWhere((c) => c.id == 'language_already_set'),
      );
      final configured = await loader.load(corpus.task.meta.id);
      expect((configured.input['task']! as Map)['languageCode'], 'en');
      expect(configured.runningTimerId, isNull);
      await fixture.reset(queryActionEvalCases.first);
      final reset = await loader.load(corpus.task.meta.id);
      expect((reset.input['task']! as Map)['languageCode'], isNull);
      expect(fixture.hash, hash);
    },
  );
}
