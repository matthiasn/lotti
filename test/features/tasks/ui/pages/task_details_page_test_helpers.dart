import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/tasks/state/task_link_groups_controller.dart';

import '../../../../helpers/stub_audio_recorder_controller.dart';
import '../../../../test_data/test_data.dart';
import '../../../agents/test_data/change_set_factories.dart';
import '../../../agents/test_data/entity_factories.dart';

List<Override> hTaskDetailsPageOverrides() => [
  audioRecorderControllerProvider.overrideWith(
    StubAudioRecorderController.new,
  ),
];

/// Text entries linked below the AI card, plus the overrides that make them
/// render.
///
/// The below-card sliver has to be taller than the viewport before the card can
/// scroll fully past the viewport top, which is the precondition for the
/// off-screen stabilization path. [count] entries of [linesEach] lines each are
/// linked from [testTask].
///
/// The link list and each row's entry are overridden at the provider level
/// rather than through the Drift mock graph: the widgets under test here are
/// the page's stabilization anchors, not the linked-entries query.
List<Override> hLinkedEntriesOverrides({int count = 6, int linesEach = 6}) {
  final entries = [
    for (var i = 0; i < count; i++)
      testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(id: 'linked-entry-$i'),
        entryText: EntryText(
          plainText: List.generate(
            linesEach,
            (line) => 'Linked entry $i, line $line.',
          ).join('\n'),
        ),
      ),
  ];

  return [
    linkedEntriesControllerProvider(testTask.meta.id).overrideWith(
      () => _StaticLinkedEntriesController([
        for (final entry in entries)
          EntryLink.basic(
            id: 'link-to-${entry.meta.id}',
            fromId: testTask.meta.id,
            toId: entry.meta.id,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          ),
      ]),
    ),
    for (final entry in entries)
      entryControllerProvider(entry.meta.id).overrideWith(
        () => _StaticEntryController(entry),
      ),
  ];
}

/// Serves a fixed link list, bypassing the repository fetch and its
/// update-stream subscription.
class _StaticLinkedEntriesController extends LinkedEntriesController {
  _StaticLinkedEntriesController(this._links);

  final List<EntryLink> _links;

  @override
  Future<List<EntryLink>> build() async => _links;
}

/// Resolves a linked entry straight from memory, so the below-card list has
/// real height without a Drift-level mock graph behind every row.
class _StaticEntryController extends EntryController {
  _StaticEntryController(this._entry);

  final JournalEntity _entry;

  @override
  Future<EntryState?> build() async => EntryState.saved(
    entryId: id,
    entry: _entry,
    showMap: false,
    isFocused: false,
    shouldShowEditorToolBar: false,
  );
}

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

/// Drives the number of tasks linked to [testTask], so a test can add one the
/// way a confirmed `create_follow_up_task` eventually does.
class LinkedTaskCountNotifier extends Notifier<int> {
  @override
  int build() => 0;

  // ignore: use_setters_to_change_properties
  void set(int value) => state = value;
}

final NotifierProvider<LinkedTaskCountNotifier, int>
controllableLinkedTaskCountProvider =
    NotifierProvider<LinkedTaskCountNotifier, int>(
      LinkedTaskCountNotifier.new,
    );

/// Makes `LinkedTasksWidget`'s content follow
/// [controllableLinkedTaskCountProvider].
///
/// A follow-up task links itself only after its agent content has been
/// generated, so in the real flow this band can grow long after the resolve
/// window closed — which is the case these overrides exist to reproduce.
List<Override> hControllableLinkedTasksOverrides() => [
  taskLinkGroupsControllerProvider(testTask.meta.id).overrideWith(
    _ControllableTaskLinkGroupsController.new,
  ),
];

class _ControllableTaskLinkGroupsController extends TaskLinkGroupsController {
  @override
  Future<TaskLinkGroups> build() async {
    final count = ref.watch(controllableLinkedTaskCountProvider);
    return TaskLinkGroups(
      flat: [
        for (var i = 0; i < count; i++)
          TaskLinkEntry(
            linkId: 'follow-up-link-$i',
            task: testTask.copyWith(
              meta: testTask.meta.copyWith(id: 'follow-up-task-$i'),
              data: testTask.data.copyWith(title: 'Follow-up task $i'),
            ),
            kind: TaskLinkKind.basic,
            direction: TaskLinkDirection.outgoing,
          ),
      ],
      typed: const [],
    );
  }
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

/// A single-item change set carrying [toolName], for tests that need the
/// page's response to one specific suggestion type.
List<ChangeItem> hSingleSuggestion(String toolName) => [
  switch (toolName) {
    'set_task_language' => const ChangeItem(
      toolName: 'set_task_language',
      args: {'languageCode': 'de', 'confidence': 'high'},
      humanSummary: 'Set language to "de"',
    ),
    'add_checklist_item' => const ChangeItem(
      toolName: 'add_checklist_item',
      args: {'title': 'Add a checklist item'},
      humanSummary: 'Add a checklist item',
    ),
    _ => const ChangeItem(
      toolName: 'update_task_estimate',
      args: {'minutes': 30},
      humanSummary: 'Set estimate to 30 minutes',
    ),
  },
];

/// Like [hTaskDetailsPageAgentOverrides] but the open-proposal list size is
/// driven by [controllableOpenSuggestionCountProvider], so a test can lower it
/// mid-run to exercise the "a proposal was confirmed" path.
///
/// [items] picks which tools the proposals carry, so a test can exercise the
/// page's geometry response per suggestion type. The default two-item set keeps
/// existing callers unchanged.
List<Override> hControllableSuggestionOverrides({List<ChangeItem>? items}) {
  final identity = makeTestIdentity();
  final changeSet = makeTestChangeSet(
    taskId: testTask.id,
    items:
        items ??
        const [
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
      // Clamped to the item count so a caller can pass a single-item set
      // without the notifier's default of 2 running off the end.
      final open = count < changeSet.items.length
          ? count
          : changeSet.items.length;
      return UnifiedSuggestionList(
        open: [for (var i = 0; i < open; i++) suggestionAt(i)],
        activity: const [],
      );
    }),
    configFlagProvider.overrideWith((ref, flagName) => Stream.value(false)),
  ];
}
