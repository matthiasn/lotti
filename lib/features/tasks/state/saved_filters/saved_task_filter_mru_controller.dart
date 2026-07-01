import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Per-device "most recently used" order for saved task filters on mobile.
///
/// Desktop keeps an explicit, drag-reorderable order; the mobile rail instead
/// surfaces the filters the user touched most recently as width-permitting
/// quick-jump pills. The order is intentionally **in-memory and per-device**
/// (the locked rule is "the list is dynamic per device") — it resets on a cold
/// start and is never persisted or synced, so it stays a lightweight glance
/// affordance rather than a second source of truth for the saved-filter list.
///
/// State is the list of saved-filter ids in MRU order (most recent first). Ids
/// that have never been activated simply don't appear; the rail falls back to
/// the controller's stored order for those.
class SavedTaskFilterMruController extends Notifier<List<String>> {
  @override
  List<String> build() => const <String>[];

  /// Promotes [id] to the front of the MRU order. A no-op-shaped call (the id
  /// is already at the front) still rebuilds with an equal list, which Riverpod
  /// collapses, so callers can touch unconditionally on every activation.
  void touch(String id) {
    state = <String>[
      id,
      for (final existing in state)
        if (existing != id) existing,
    ];
  }
}

/// Provider exposing the in-memory MRU order for saved task filters.
final savedTaskFilterMruProvider =
    NotifierProvider<SavedTaskFilterMruController, List<String>>(
      SavedTaskFilterMruController.new,
      name: 'savedTaskFilterMruProvider',
    );
