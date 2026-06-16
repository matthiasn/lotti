// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:meta/meta.dart';

/// Record type for completion controller parameters.
typedef ChecklistCompletionParams = ({String id, String? taskId});

/// Aggregate counts for a checklist: how many active items are checked
/// (`completedCount`) out of how many total (`totalCount`).
typedef ChecklistCompletionState = ({int completedCount, int totalCount});

/// Provider for the per-checklist completion counts. Family key is the
/// `(id, taskId)` of the checklist; auto-disposes when no widget watches it.
final checklistCompletionControllerProvider = AsyncNotifierProvider.autoDispose
    .family<
      ChecklistCompletionController,
      ChecklistCompletionState,
      ChecklistCompletionParams
    >(
      ChecklistCompletionController.new,
    );

/// Derives a checklist's checked/total counts by composing the lower-level
/// controllers rather than reading the DB directly.
///
/// It listens to the parent [ChecklistController] (for the set of linked item
/// ids) and to each [ChecklistItemController] in that set (for checked/archive
/// state), recomputing on any change. Only *active* items — neither deleted
/// nor archived — are counted (see [aggregateCompletion]).
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

    final items = linkedIds
        .map(
          (itemId) => ref
              .read(
                checklistItemControllerProvider((id: itemId, taskId: taskId)),
              )
              .value,
        )
        .nonNulls;

    return aggregateCompletion(items);
  }

  /// Pure aggregation core of [_computeState]: counts checked vs. total
  /// *active* items, where an item is active when it is neither deleted nor
  /// archived. Extracted so the counting/filtering arithmetic can be
  /// property-tested directly, independent of the Riverpod wiring.
  @visibleForTesting
  static ChecklistCompletionState aggregateCompletion(
    Iterable<ChecklistItem> items,
  ) {
    final activeItems = items
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

/// Provider for the checklist's completion *rate* (0.0–1.0). Family key is the
/// checklist's `(id, taskId)`.
final checklistCompletionRateControllerProvider = AsyncNotifierProvider
    .autoDispose
    .family<
      ChecklistCompletionRateController,
      double,
      ChecklistCompletionParams
    >(
      ChecklistCompletionRateController.new,
    );

/// Maps the counts from [ChecklistCompletionController] to a fraction in
/// `[0, 1]` (`completed / total`), used to drive the progress ring. An empty
/// checklist reports `0.0`.
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
