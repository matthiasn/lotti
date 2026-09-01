import 'package:flutter/foundation.dart';

/// Which categories the app is currently locked down to.
///
/// Lockdown restricts every category-scoped surface to the categories in
/// [categoryIds]; an empty set means no lockdown. The state is modeled as a
/// set from the start so that a later multi-category picker needs no data
/// model change — today's picker only ever produces a single-element set.
///
/// The `''` sentinel that filters use for "unassigned" is deliberately never
/// allowed through [restrict]: an entry without a category is not part of any
/// locked category and must not leak into a demo.
@immutable
class LockdownState {
  const LockdownState({this.categoryIds = const {}});

  /// The inactive state — nothing is locked down.
  static const LockdownState inactive = LockdownState();

  /// IDs of the categories whose content may be shown. Empty when inactive.
  final Set<String> categoryIds;

  /// Whether lockdown is currently restricting the app.
  bool get isActive => categoryIds.isNotEmpty;

  /// Whether content belonging to [categoryId] may be shown.
  ///
  /// Always true while inactive. A `null` or empty [categoryId] (an
  /// unassigned entry) is never allowed while active.
  bool allows(String? categoryId) {
    if (!isActive) return true;
    if (categoryId == null || categoryId.isEmpty) return false;
    return categoryIds.contains(categoryId);
  }

  /// Clamps a user-chosen category filter to the locked set.
  ///
  /// Returns [selected] untouched while inactive. While active the result is
  /// the part of [selected] that lies inside the locked set, falling back to
  /// the whole locked set when nothing overlaps — so an empty selection (which
  /// filters read as "all categories") and a selection made entirely of other
  /// categories both resolve to exactly the locked content, never to more.
  Set<String> restrict(Set<String> selected) {
    if (!isActive) return selected;
    final overlap = selected.intersection(categoryIds);
    return overlap.isEmpty ? categoryIds : overlap;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LockdownState && setEquals(other.categoryIds, categoryIds);

  @override
  int get hashCode => Object.hashAll(categoryIds.toList()..sort());

  @override
  String toString() => 'LockdownState(categoryIds: $categoryIds)';
}
