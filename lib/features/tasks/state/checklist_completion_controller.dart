// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';

/// Record type for completion controller parameters.
typedef ChecklistCompletionParams = ({String id, String? taskId});

typedef ChecklistCompletionState = ({int completedCount, int totalCount});

final checklistCompletionControllerProvider = AsyncNotifierProvider.autoDispose
    .family<
      ChecklistCompletionController,
      ChecklistCompletionState,
      ChecklistCompletionParams
    >(
      ChecklistCompletionController.new,
    );

class ChecklistCompletionController
    extends AsyncNotifier<ChecklistCompletionState> {
  ChecklistCompletionController(this.params);

  final ChecklistCompletionParams params;
  ProviderSubscription<AsyncValue<Checklist?>>? _checklistSubscription;
  final Map<String, ProviderSubscription<AsyncValue<ChecklistItem?>>>
  _itemSubscriptions = {};

  String get id => params.id;
  String? get taskId => params.taskId;

  @override
  Future<ChecklistCompletionState> build() async {
    ref.onDispose(() {
      _checklistSubscription?.close();
      for (final sub in _itemSubscriptions.values) {
        sub.close();
      }
    });

    _checklistSubscription = ref.listen<AsyncValue<Checklist?>>(
      checklistControllerProvider((id: id, taskId: taskId)),
      (_, _) => _updateState(),
    );

    return _computeState();
  }

  ChecklistCompletionState _computeState() {
    final checklistData = ref
        .read(checklistControllerProvider((id: id, taskId: taskId)))
        .value
        ?.data;

    final linkedIds = checklistData?.linkedChecklistItems ?? <String>[];

    // Subscribe to any new item providers
    for (final itemId in linkedIds) {
      if (!_itemSubscriptions.containsKey(itemId)) {
        _itemSubscriptions[itemId] = ref.listen<AsyncValue<ChecklistItem?>>(
          checklistItemControllerProvider((id: itemId, taskId: taskId)),
          (_, _) => _updateState(),
        );
      }
    }

    final activeItems = linkedIds
        .map(
          (itemId) => ref
              .read(
                checklistItemControllerProvider((id: itemId, taskId: taskId)),
              )
              .value,
        )
        .nonNulls
        .where((item) => !item.isDeleted && !item.data.isArchived)
        .toList();
    final totalCount = activeItems.length;
    final completedCount = activeItems
        .where((item) => item.data.isChecked)
        .length;

    return (completedCount: completedCount, totalCount: totalCount);
  }

  void _updateState() {
    state = AsyncData(_computeState());
  }
}

final checklistCompletionRateControllerProvider = AsyncNotifierProvider
    .autoDispose
    .family<
      ChecklistCompletionRateController,
      double,
      ChecklistCompletionParams
    >(
      ChecklistCompletionRateController.new,
    );

class ChecklistCompletionRateController extends AsyncNotifier<double> {
  ChecklistCompletionRateController(this.params);

  final ChecklistCompletionParams params;
  ProviderSubscription<AsyncValue<ChecklistCompletionState>>? _subscription;

  String get id => params.id;
  String? get taskId => params.taskId;

  @override
  Future<double> build() async {
    ref.onDispose(() {
      _subscription?.close();
    });

    _subscription = ref.listen<AsyncValue<ChecklistCompletionState>>(
      checklistCompletionControllerProvider((id: id, taskId: taskId)),
      (_, next) {
        final res = next.value;
        final totalCount = res?.totalCount ?? 0;
        final completedCount = res?.completedCount ?? 0;
        state = AsyncData(totalCount == 0 ? 0.0 : completedCount / totalCount);
      },
    );

    final res = ref
        .read(checklistCompletionControllerProvider((id: id, taskId: taskId)))
        .value;
    final totalCount = res?.totalCount ?? 0;
    final completedCount = res?.completedCount ?? 0;
    return totalCount == 0 ? 0.0 : completedCount / totalCount;
  }
}
