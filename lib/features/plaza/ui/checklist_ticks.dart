import 'package:flutter/foundation.dart';

/// Which open checklist items have been ticked on a wall or in the side
/// panel, per task, for this harness session.
///
/// Prototype-only state: the facade and the panel both read and write it
/// so they agree, but nothing is persisted (the real write path through the
/// checklist services is milestone M5).
class ChecklistTicks extends ChangeNotifier {
  final Map<String, Set<int>> _ticked = {};

  bool isTicked(String taskId, int index) =>
      _ticked[taskId]?.contains(index) ?? false;

  int tickedCount(String taskId) => _ticked[taskId]?.length ?? 0;

  void toggle(String taskId, int index) {
    final set = _ticked.putIfAbsent(taskId, () => {});
    if (!set.remove(index)) set.add(index);
    notifyListeners();
  }
}
