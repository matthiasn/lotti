import 'package:flutter_test/flutter_test.dart';

import '../harness/eval_harness.dart';
import 'eval_scenarios.dart';

void main() {
  test('catalog exposes unique scenario ids across both agents', () {
    final ids = [for (final scenario in allEvalScenarios) scenario.id];

    expect(ids.toSet(), hasLength(ids.length));
    expect(planningEvalScenarios, hasLength(2));
    expect(taskEvalScenarios, hasLength(2));
    expect(
      allEvalScenarios.every(
        (scenario) => scenario.userInput.triggerTokens.isNotEmpty,
      ),
      isTrue,
      reason: 'runner needs concrete wake trigger tokens for every scenario',
    );
  });

  test(
    'catalog scenarios round-trip through JSON without app entity types',
    () {
      for (final scenario in allEvalScenarios) {
        final roundTripped = EvalScenario.fromJson(scenario.toJson());

        expect(roundTripped.id, scenario.id);
        expect(roundTripped.agentKind, scenario.agentKind);
        expect(
          roundTripped.userInput.transcript,
          scenario.userInput.transcript,
        );
        expect(
          roundTripped.appState.knownTaskIds,
          scenario.appState.knownTaskIds,
        );
      }
    },
  );
}
