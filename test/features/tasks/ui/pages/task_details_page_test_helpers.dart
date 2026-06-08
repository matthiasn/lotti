import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// Minimal [DropItem] implementation for widget tests that invoke
/// the [DropTarget.onDragDone] callback directly.
class TaskDetailsFakeDropItem extends Fake implements DropItem {
  TaskDetailsFakeDropItem(this._xFile);

  final XFile _xFile;

  @override
  String get name => _xFile.name;

  @override
  String get path => _xFile.path;

  @override
  Future<DateTime> lastModified() => _xFile.lastModified();
}

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
