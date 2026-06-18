import 'package:flutter/foundation.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'celebration_preferences_controller.g.dart';

/// [SettingsDb] keys backing each celebratory-animation switch. Stored as the
/// strings `'true'` / `'false'`; an absent key means "never set" → on.
const _celebrateHabitsKey = 'CELEBRATE_HABITS';
const _celebrateChecklistItemsKey = 'CELEBRATE_CHECKLIST_ITEMS';
const _celebrateTasksKey = 'CELEBRATE_TASKS';

/// Whether the celebratory completion *animations* are enabled for each of the
/// three completion events. All on by default; the user turns any of them off
/// in Settings → Advanced → Animations.
///
/// Only the visual celebration is gated — the glow bloom, spark burst, checkbox
/// pop, and strike-through wipe. The brief haptic that accompanies a completion
/// is deliberately left intact (it is feedback, not an animation, and on habits
/// the same haptic also fires for the non-celebratory "missed" swipe).
@immutable
class CelebrationPreferences {
  const CelebrationPreferences({
    required this.habits,
    required this.checklistItems,
    required this.tasks,
  });

  /// The default before the user has chosen otherwise: every celebration on.
  const CelebrationPreferences.allEnabled()
    : habits = true,
      checklistItems = true,
      tasks = true;

  /// Celebrate completing a habit (and the all-habits-done summary bloom).
  final bool habits;

  /// Celebrate checking off a checklist item (and reaching 100% on a checklist).
  final bool checklistItems;

  /// Celebrate moving a task into Done.
  final bool tasks;

  CelebrationPreferences copyWith({
    bool? habits,
    bool? checklistItems,
    bool? tasks,
  }) => CelebrationPreferences(
    habits: habits ?? this.habits,
    checklistItems: checklistItems ?? this.checklistItems,
    tasks: tasks ?? this.tasks,
  );

  @override
  bool operator ==(Object other) =>
      other is CelebrationPreferences &&
      other.habits == habits &&
      other.checklistItems == checklistItems &&
      other.tasks == tasks;

  @override
  int get hashCode => Object.hash(habits, checklistItems, tasks);
}

/// Holds the three celebratory-animation switches, persisted across launches in
/// [SettingsDb].
///
/// [build] returns [CelebrationPreferences.allEnabled] synchronously and then
/// hydrates the persisted values, mirroring `ZoomController`. Returning a value
/// synchronously (rather than an `AsyncValue`) lets a celebration call site read
/// the flag on the very frame it would fire — no loading state to thread through
/// a `didUpdateWidget`. Reads from / writes to [SettingsDb] are skipped when it
/// is not registered (some widget tests), so the default simply stays on.
@Riverpod(keepAlive: true)
class CelebrationPreferencesController
    extends _$CelebrationPreferencesController {
  /// True once the user has toggled a switch, so a late-arriving hydration
  /// can't clobber a fresh interaction (same race guard as `ZoomController`).
  bool _userAdjusted = false;

  @override
  CelebrationPreferences build() {
    _hydrate();
    return const CelebrationPreferences.allEnabled();
  }

  Future<void> _hydrate() async {
    if (!getIt.isRegistered<SettingsDb>()) return;
    final db = getIt<SettingsDb>();
    final habits = await db.itemByKey(_celebrateHabitsKey);
    final checklistItems = await db.itemByKey(_celebrateChecklistItemsKey);
    final tasks = await db.itemByKey(_celebrateTasksKey);
    // Bail if the user already toggled (don't clobber a fresh choice) or the
    // provider was disposed while the reads were in flight.
    if (_userAdjusted || !ref.mounted) return;
    state = CelebrationPreferences(
      habits: habits != 'false',
      checklistItems: checklistItems != 'false',
      tasks: tasks != 'false',
    );
  }

  /// Enables or disables the habit-completion celebration.
  Future<void> setHabits({required bool enabled}) =>
      _update(state.copyWith(habits: enabled), _celebrateHabitsKey, enabled);

  /// Enables or disables the checklist-item / checklist-complete celebration.
  Future<void> setChecklistItems({required bool enabled}) => _update(
    state.copyWith(checklistItems: enabled),
    _celebrateChecklistItemsKey,
    enabled,
  );

  /// Enables or disables the task-done celebration.
  Future<void> setTasks({required bool enabled}) =>
      _update(state.copyWith(tasks: enabled), _celebrateTasksKey, enabled);

  Future<void> _update(
    CelebrationPreferences next,
    String key,
    bool value,
  ) async {
    _userAdjusted = true;
    state = next;
    if (getIt.isRegistered<SettingsDb>()) {
      await getIt<SettingsDb>().saveSettingsItem(key, value.toString());
    }
  }
}

/// Convenience read of the current [CelebrationPreferences]. Celebration call
/// sites watch this; tests override it with `overrideWithValue(...)` to assert
/// gating without touching persistence.
@riverpod
CelebrationPreferences celebrationPreferences(Ref ref) =>
    ref.watch(celebrationPreferencesControllerProvider);
