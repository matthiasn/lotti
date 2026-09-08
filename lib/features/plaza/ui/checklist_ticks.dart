import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';

/// Persists a checklist edit by entity ID and reports whether it committed.
typedef PersistPlazaChecklist =
    Future<bool> Function(
      String taskId,
      String itemId, {
      required bool checked,
    });

/// Shared optimistic checklist state for facades and the side panel.
///
/// The standalone demo omits [persist]. App callers bind each new snapshot
/// with [bindTasks] and persist by item ID, so a refreshed/reordered preview
/// cannot redirect an in-flight edit. A failed write rolls back and reports it.
class ChecklistTicks extends ChangeNotifier {
  ChecklistTicks({this.persist, this.onFailure});

  final PersistPlazaChecklist? persist;
  final VoidCallback? onFailure;
  final Map<String, Set<String>> _ticked = {};
  final Map<String, List<String>> _itemIds = {};
  final Set<(String, String)> _pending = {};
  bool _disposed = false;

  /// Reconciles confirmed edits without notifying during a parent's build.
  void bindTasks(List<PlazaTask> tasks) {
    _itemIds.clear();
    for (final task in tasks) {
      _itemIds[task.id] = task.openChecklistItemIds;
      _ticked[task.id]?.removeWhere(
        (id) => !task.openChecklistItemIds.contains(id),
      );
    }
    _ticked.removeWhere((taskId, _) => !_itemIds.containsKey(taskId));
  }

  String? _itemId(String taskId, int index) {
    if (index < 0) return null;
    if (persist == null) return 'preview-$index';
    final ids = _itemIds[taskId];
    return ids != null && index < ids.length ? ids[index] : null;
  }

  bool isTicked(String taskId, int index) =>
      _ticked[taskId]?.contains(_itemId(taskId, index)) ?? false;

  int tickedCount(String taskId) => _ticked[taskId]?.length ?? 0;

  void toggle(String taskId, int index) {
    if (_disposed) return;
    final itemId = _itemId(taskId, index);
    if (itemId == null || _pending.contains((taskId, itemId))) return;
    final set = _ticked.putIfAbsent(taskId, () => {});
    final checked = !set.remove(itemId);
    if (checked) set.add(itemId);
    final write = persist;
    if (write != null) _pending.add((taskId, itemId));
    notifyListeners();
    if (write != null) {
      unawaited(_commit(write, taskId, itemId, checked));
    }
  }

  Future<void> _commit(
    PersistPlazaChecklist write,
    String taskId,
    String itemId,
    bool checked,
  ) async {
    var saved = false;
    try {
      saved = await write(taskId, itemId, checked: checked);
    } catch (_) {
      saved = false;
    }
    if (_disposed) return;
    _pending.remove((taskId, itemId));
    if (!saved) {
      final set = _ticked[taskId];
      if (checked) {
        set?.remove(itemId);
      } else if (_itemIds[taskId]?.contains(itemId) ?? false) {
        set?.add(itemId);
      }
      notifyListeners();
      onFailure?.call();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
