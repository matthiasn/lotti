import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';

import '../../../../helpers/stub_audio_recorder_controller.dart';
import '../../../../test_data/test_data.dart';
import '../../../agents/test_data/change_set_factories.dart';
import '../../../agents/test_data/entity_factories.dart';

List<Override> hTaskDetailsPageOverrides() => [
  audioRecorderControllerProvider.overrideWith(
    StubAudioRecorderController.new,
  ),
];

List<Override> hTaskDetailsPageAgentOverrides() {
  final identity = makeTestIdentity();
  final changeSet = makeTestChangeSet(
    taskId: testTask.id,
    items: const [
      ChangeItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 30},
        humanSummary: 'Set estimate to 30 minutes',
      ),
    ],
  );
  final pending = PendingSuggestion(
    changeSet: changeSet,
    itemIndex: 0,
    item: changeSet.items.first,
    fingerprint: ChangeItem.fingerprint(changeSet.items.first),
  );

  return [
    taskAgentProvider.overrideWith((ref, id) async => identity),
    agentReportProvider.overrideWith((ref, agentId) async => null),
    templateForAgentProvider.overrideWith((ref, agentId) async => null),
    agentIsRunningProvider.overrideWith((ref, agentId) => Stream.value(false)),
    agentStateProvider.overrideWith((ref, agentId) async => null),
    unifiedSuggestionListProvider.overrideWith(
      (ref, taskId) async => UnifiedSuggestionList(
        open: [pending],
        activity: const [],
      ),
    ),
    configFlagProvider.overrideWith((ref, flagName) => Stream.value(false)),
  ];
}

/// Drives the number of open AI proposals for [testTask] so a test can shrink
/// it (simulating a confirm) and observe the page's response.
class OpenSuggestionCountNotifier extends Notifier<int> {
  @override
  int build() => 2;

  // ignore: use_setters_to_change_properties
  void set(int value) => state = value;
}

final NotifierProvider<OpenSuggestionCountNotifier, int>
controllableOpenSuggestionCountProvider =
    NotifierProvider<OpenSuggestionCountNotifier, int>(
      OpenSuggestionCountNotifier.new,
    );

/// Like [hTaskDetailsPageAgentOverrides] but the open-proposal list size is
/// driven by [controllableOpenSuggestionCountProvider], so a test can lower it
/// mid-run to exercise the "a proposal was confirmed" path.
List<Override> hControllableSuggestionOverrides() {
  final identity = makeTestIdentity();
  final changeSet = makeTestChangeSet(
    taskId: testTask.id,
    items: const [
      ChangeItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 30},
        humanSummary: 'Set estimate to 30 minutes',
      ),
      ChangeItem(
        toolName: 'add_checklist_item',
        args: {'title': 'Add a checklist item'},
        humanSummary: 'Add a checklist item',
      ),
    ],
  );
  PendingSuggestion suggestionAt(int index) => PendingSuggestion(
    changeSet: changeSet,
    itemIndex: index,
    item: changeSet.items[index],
    fingerprint: ChangeItem.fingerprint(changeSet.items[index]),
  );

  return [
    taskAgentProvider.overrideWith((ref, id) async => identity),
    agentReportProvider.overrideWith((ref, agentId) async => null),
    templateForAgentProvider.overrideWith((ref, agentId) async => null),
    agentIsRunningProvider.overrideWith((ref, agentId) => Stream.value(false)),
    agentStateProvider.overrideWith((ref, agentId) async => null),
    unifiedSuggestionListProvider.overrideWith((ref, taskId) async {
      final count = ref.watch(controllableOpenSuggestionCountProvider);
      return UnifiedSuggestionList(
        open: [for (var i = 0; i < count; i++) suggestionAt(i)],
        activity: const [],
      );
    }),
    configFlagProvider.overrideWith((ref, flagName) => Stream.value(false)),
  ];
}
