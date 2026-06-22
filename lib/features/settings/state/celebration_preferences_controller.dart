import 'package:flutter/foundation.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'celebration_preferences_controller.g.dart';

/// [SettingsDb] keys backing each celebratory-animation switch. The bool keys
/// store the strings `'true'` / `'false'`; an absent key means "never set" → on.
const _celebrateEnabledKey = 'CELEBRATE_ENABLED';
const _celebrateHapticsKey = 'CELEBRATE_HAPTICS';
const _celebrateHabitsKey = 'CELEBRATE_HABITS';
const _celebrateChecklistItemsKey = 'CELEBRATE_CHECKLIST_ITEMS';
const _celebrateTasksKey = 'CELEBRATE_TASKS';

/// Per-content-type [CelebrationVariant] keys; each stores the variant's `name`.
/// An absent / unrecognised value falls back to the legacy [_celebrateVariantKey]
/// (so a user who picked one global style before this split keeps it), then to
/// that event's product default.
const _celebrateTasksVariantKey = 'CELEBRATE_VARIANT_TASKS';
const _celebrateHabitsVariantKey = 'CELEBRATE_VARIANT_HABITS';
const _celebrateChecklistItemsVariantKey = 'CELEBRATE_VARIANT_CHECKLIST_ITEMS';

/// Legacy single-variant key from before the style became per-content-type. Read
/// only as a migration fallback for the per-event keys above; never written.
const _celebrateVariantKey = 'CELEBRATE_VARIANT';

/// User preferences for the celebratory completion experience.
///
/// Two independent axes gate what plays:
///
/// * The **visual** celebration (glow bloom, spark/particle burst, checkbox pop,
///   anchor pop) is gated by the master [enabled] switch *and* the matching
///   per-event switch ([habits] / [checklistItems] / [tasks]). Read the
///   combined result via [animateHabits] / [animateChecklistItems] /
///   [animateTasks] at call sites — never the raw per-event field, which the
///   Settings UI still shows on its own so a user can pre-set categories while
///   the whole thing is off.
/// * The completion **haptic** is gated solely by [haptics], independent of the
///   visuals: a user can keep the tactile confirmation with the flash off, or
///   the flash with the buzz off. (On habits the same low-level haptic also
///   fires for the non-celebratory "missed" swipe; that path is unaffected —
///   only the *completion* haptic honours this switch.)
///
/// [tasksVariant] / [habitsVariant] / [checklistItemsVariant] each select which
/// particle language that content type's burst speaks — so a user can throw
/// confetti for habits, bubbles for checklists, and sparks for tasks. A variant
/// has no effect while the matching visual is gated off.
///
/// Everything defaults on, with each content type's product default variant
/// ([defaultTasksVariant] / [defaultHabitsVariant] /
/// [defaultChecklistItemsVariant]), so a fresh install celebrates out of the box
/// and an upgrade preserves a previously chosen global style via the migration in
/// [CelebrationPreferencesController].
@immutable
class CelebrationPreferences {
  const CelebrationPreferences({
    required this.enabled,
    required this.haptics,
    required this.habits,
    required this.checklistItems,
    required this.tasks,
    required this.tasksVariant,
    required this.habitsVariant,
    required this.checklistItemsVariant,
  });

  /// The default before the user has chosen otherwise: every celebration on,
  /// haptics on, each content type's product-default variant.
  const CelebrationPreferences.allEnabled()
    : enabled = true,
      haptics = true,
      habits = true,
      checklistItems = true,
      tasks = true,
      tasksVariant = defaultTasksVariant,
      habitsVariant = defaultHabitsVariant,
      checklistItemsVariant = defaultChecklistItemsVariant;

  /// Product-default variant per content type, applied on a fresh install with no
  /// stored choice (and no legacy global value to migrate from). Distinct per
  /// type so the celebrations feel deliberately different out of the box:
  /// restrained [CelebrationVariant.sparks] for closing a task, playful
  /// [CelebrationVariant.confetti] for a habit, and airy
  /// [CelebrationVariant.bubbles] for ticking off a checklist item.
  static const CelebrationVariant defaultTasksVariant =
      CelebrationVariant.sparks;
  static const CelebrationVariant defaultHabitsVariant =
      CelebrationVariant.confetti;
  static const CelebrationVariant defaultChecklistItemsVariant =
      CelebrationVariant.bubbles;

  /// Master switch for every *visual* celebration. When off, no glow/burst/pop
  /// plays anywhere regardless of the per-event switches; haptics are unaffected.
  final bool enabled;

  /// Whether the brief completion haptic fires. Independent of [enabled].
  final bool haptics;

  /// Celebrate completing a habit (and the all-habits-done summary bloom).
  final bool habits;

  /// Celebrate checking off a checklist item (and reaching 100% on a checklist).
  final bool checklistItems;

  /// Celebrate moving a task into Done.
  final bool tasks;

  /// Which particle language the task-done burst speaks.
  final CelebrationVariant tasksVariant;

  /// Which particle language the habit-completion burst speaks.
  final CelebrationVariant habitsVariant;

  /// Which particle language the checklist-item burst speaks (also the
  /// whole-checklist 100% bloom, though that is glow-only).
  final CelebrationVariant checklistItemsVariant;

  /// Whether the habit-completion visual should play: master on *and* habits on.
  bool get animateHabits => enabled && habits;

  /// Whether the checklist visual should play: master on *and* checklist on.
  bool get animateChecklistItems => enabled && checklistItems;

  /// Whether the task-done visual should play: master on *and* tasks on.
  bool get animateTasks => enabled && tasks;

  CelebrationPreferences copyWith({
    bool? enabled,
    bool? haptics,
    bool? habits,
    bool? checklistItems,
    bool? tasks,
    CelebrationVariant? tasksVariant,
    CelebrationVariant? habitsVariant,
    CelebrationVariant? checklistItemsVariant,
  }) => CelebrationPreferences(
    enabled: enabled ?? this.enabled,
    haptics: haptics ?? this.haptics,
    habits: habits ?? this.habits,
    checklistItems: checklistItems ?? this.checklistItems,
    tasks: tasks ?? this.tasks,
    tasksVariant: tasksVariant ?? this.tasksVariant,
    habitsVariant: habitsVariant ?? this.habitsVariant,
    checklistItemsVariant: checklistItemsVariant ?? this.checklistItemsVariant,
  );

  @override
  bool operator ==(Object other) =>
      other is CelebrationPreferences &&
      other.enabled == enabled &&
      other.haptics == haptics &&
      other.habits == habits &&
      other.checklistItems == checklistItems &&
      other.tasks == tasks &&
      other.tasksVariant == tasksVariant &&
      other.habitsVariant == habitsVariant &&
      other.checklistItemsVariant == checklistItemsVariant;

  @override
  int get hashCode => Object.hash(
    enabled,
    haptics,
    habits,
    checklistItems,
    tasks,
    tasksVariant,
    habitsVariant,
    checklistItemsVariant,
  );
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
  /// Keys the user has toggled this session. A late-arriving hydration skips
  /// only these fields, so toggling one switch before hydration completes
  /// doesn't clobber that choice — *and* doesn't block the other (untouched)
  /// switches from loading their persisted values.
  final _adjusted = <String>{};

  @override
  CelebrationPreferences build() {
    _hydrate();
    return const CelebrationPreferences.allEnabled();
  }

  Future<void> _hydrate() async {
    if (!getIt.isRegistered<SettingsDb>()) return;
    try {
      final db = getIt<SettingsDb>();
      final enabled = await db.itemByKey(_celebrateEnabledKey);
      final haptics = await db.itemByKey(_celebrateHapticsKey);
      final habits = await db.itemByKey(_celebrateHabitsKey);
      final checklistItems = await db.itemByKey(_celebrateChecklistItemsKey);
      final tasks = await db.itemByKey(_celebrateTasksKey);
      final tasksVariant = await db.itemByKey(_celebrateTasksVariantKey);
      final habitsVariant = await db.itemByKey(_celebrateHabitsVariantKey);
      final checklistItemsVariant = await db.itemByKey(
        _celebrateChecklistItemsVariantKey,
      );
      // The pre-split single key — used only to migrate a previously chosen
      // global style onto whichever per-event keys were never written.
      final legacyVariant = await db.itemByKey(_celebrateVariantKey);
      // The provider may have been disposed while the reads were in flight.
      if (!ref.mounted) return;
      // `copyWith(field: null)` keeps the current value, so a field the user
      // already toggled this session is left as-is while the rest hydrate.
      state = state.copyWith(
        enabled: _adjusted.contains(_celebrateEnabledKey)
            ? null
            : enabled != 'false',
        haptics: _adjusted.contains(_celebrateHapticsKey)
            ? null
            : haptics != 'false',
        habits: _adjusted.contains(_celebrateHabitsKey)
            ? null
            : habits != 'false',
        checklistItems: _adjusted.contains(_celebrateChecklistItemsKey)
            ? null
            : checklistItems != 'false',
        tasks: _adjusted.contains(_celebrateTasksKey) ? null : tasks != 'false',
        tasksVariant: _adjusted.contains(_celebrateTasksVariantKey)
            ? null
            : _resolveVariant(
                tasksVariant,
                legacyVariant,
                CelebrationPreferences.defaultTasksVariant,
              ),
        habitsVariant: _adjusted.contains(_celebrateHabitsVariantKey)
            ? null
            : _resolveVariant(
                habitsVariant,
                legacyVariant,
                CelebrationPreferences.defaultHabitsVariant,
              ),
        checklistItemsVariant:
            _adjusted.contains(_celebrateChecklistItemsVariantKey)
            ? null
            : _resolveVariant(
                checklistItemsVariant,
                legacyVariant,
                CelebrationPreferences.defaultChecklistItemsVariant,
              ),
      );
    } catch (_) {
      // A failed read leaves the all-enabled default (set in build) in place.
    }
  }

  /// Enables or disables *all* visual celebrations (the master switch). The
  /// per-event switches and haptics keep their own state underneath.
  Future<void> setEnabled({required bool enabled}) => _updateBool(
    state.copyWith(enabled: enabled),
    _celebrateEnabledKey,
    enabled,
  );

  /// Enables or disables the completion haptic, independent of the visuals.
  Future<void> setHaptics({required bool enabled}) => _updateBool(
    state.copyWith(haptics: enabled),
    _celebrateHapticsKey,
    enabled,
  );

  /// Enables or disables the habit-completion celebration.
  Future<void> setHabits({required bool enabled}) => _updateBool(
    state.copyWith(habits: enabled),
    _celebrateHabitsKey,
    enabled,
  );

  /// Enables or disables the checklist-item / checklist-complete celebration.
  Future<void> setChecklistItems({required bool enabled}) => _updateBool(
    state.copyWith(checklistItems: enabled),
    _celebrateChecklistItemsKey,
    enabled,
  );

  /// Enables or disables the task-done celebration.
  Future<void> setTasks({required bool enabled}) =>
      _updateBool(state.copyWith(tasks: enabled), _celebrateTasksKey, enabled);

  /// Selects the [CelebrationVariant] used by the task-done burst.
  Future<void> setTasksVariant(CelebrationVariant variant) async {
    _adjusted.add(_celebrateTasksVariantKey);
    state = state.copyWith(tasksVariant: variant);
    await _persist(_celebrateTasksVariantKey, variant.name);
  }

  /// Selects the [CelebrationVariant] used by the habit-completion burst.
  Future<void> setHabitsVariant(CelebrationVariant variant) async {
    _adjusted.add(_celebrateHabitsVariantKey);
    state = state.copyWith(habitsVariant: variant);
    await _persist(_celebrateHabitsVariantKey, variant.name);
  }

  /// Selects the [CelebrationVariant] used by the checklist-item burst.
  Future<void> setChecklistItemsVariant(CelebrationVariant variant) async {
    _adjusted.add(_celebrateChecklistItemsVariantKey);
    state = state.copyWith(checklistItemsVariant: variant);
    await _persist(_celebrateChecklistItemsVariantKey, variant.name);
  }

  Future<void> _updateBool(
    CelebrationPreferences next,
    String key,
    bool value,
  ) async {
    _adjusted.add(key);
    state = next;
    await _persist(key, value.toString());
  }

  Future<void> _persist(String key, String value) async {
    if (!getIt.isRegistered<SettingsDb>()) return;
    try {
      await getIt<SettingsDb>().saveSettingsItem(key, value);
    } catch (_) {
      // The in-memory state still reflects the change; persistence will be
      // retried on the next change. Swallow so a DB hiccup can't crash a tap.
    }
  }
}

/// Resolves a per-content-type variant from storage, oldest-wins-last:
/// the event's own [stored] value if present, else the [legacy] global value
/// (one-time migration from before the style became per-content-type), else the
/// product [fallback]. [CelebrationVariant.tryFromStorage] returns `null` for an
/// absent / unrecognised string so each tier can fall through cleanly.
CelebrationVariant _resolveVariant(
  String? stored,
  String? legacy,
  CelebrationVariant fallback,
) =>
    CelebrationVariant.tryFromStorage(stored) ??
    CelebrationVariant.tryFromStorage(legacy) ??
    fallback;

/// Convenience read of the current [CelebrationPreferences]. Celebration call
/// sites watch this; tests override it with `overrideWithValue(...)` to assert
/// gating without touching persistence.
@riverpod
CelebrationPreferences celebrationPreferences(Ref ref) =>
    ref.watch(celebrationPreferencesControllerProvider);
