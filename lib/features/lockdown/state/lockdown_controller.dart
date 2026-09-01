import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/lockdown/domain/lockdown_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';

/// Source of truth for lockdown mode.
///
/// Kept alive for the whole session and deliberately **not persisted**: a
/// demo that ends with the app closed must never reopen still locked down,
/// and a lockdown that survived a crash would be indistinguishable from data
/// loss to the user. Restarting the app is therefore always a way out.
final lockdownControllerProvider =
    NotifierProvider<LockdownController, LockdownState>(
      LockdownController.new,
    );

class LockdownController extends Notifier<LockdownState> {
  @override
  LockdownState build() => LockdownState.inactive;

  /// Locks the app down to a single category. The picker only offers one at a
  /// time today; see [lockToCategories] for the set-shaped entry point.
  void lockToCategory(String categoryId) => lockToCategories({categoryId});

  /// Locks the app down to [categoryIds]. An empty set clears lockdown.
  void lockToCategories(Set<String> categoryIds) {
    _apply(LockdownState(categoryIds: Set.unmodifiable(categoryIds)));
  }

  /// Exits lockdown and restores the full app.
  void clear() => _apply(LockdownState.inactive);

  void _apply(LockdownState next) {
    if (next == state) return;
    state = next;
    // Mirror the scope into the synchronous cache so every picker and chip
    // that lists categories through it stays inside the locked set.
    getIt<EntitiesCacheService>().lockedCategoryIds = next.categoryIds;
  }
}
