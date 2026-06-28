import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_params.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_selection.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/get_it.dart';

/// [SettingsDb] keys backing each celebratory-animation switch. The bool keys
/// store the strings `'true'` / `'false'`; an absent key means "never set" → on.
const _celebrateEnabledKey = 'CELEBRATE_ENABLED';
const _celebrateHapticsKey = 'CELEBRATE_HAPTICS';
const _celebrateHabitsKey = 'CELEBRATE_HABITS';
const _celebrateChecklistItemsKey = 'CELEBRATE_CHECKLIST_ITEMS';
const _celebrateTasksKey = 'CELEBRATE_TASKS';

/// Per-content-type [CelebrationSelection] keys; each stores the selection
/// [CelebrationSelection.token] (a variant `name`, or the random / combine
/// sentinel). An absent / unrecognised value falls back to the legacy
/// [_celebrateVariantKey] (so a user who picked one global style before this
/// split keeps it), then to that event's product default.
const _celebrateTasksVariantKey = 'CELEBRATE_VARIANT_TASKS';
const _celebrateHabitsVariantKey = 'CELEBRATE_VARIANT_HABITS';
const _celebrateChecklistItemsVariantKey = 'CELEBRATE_VARIANT_CHECKLIST_ITEMS';

/// Legacy single-variant key from before the style became per-content-type. Read
/// only as a migration fallback for the per-event keys above; never written.
const _celebrateVariantKey = 'CELEBRATE_VARIANT';

/// The [SettingsDb] key holding the tuned [CelebrationParams] JSON for one
/// variant. Absent means "untouched" → the variant's defaults.
String _celebrateParamsKey(CelebrationVariant variant) =>
    'CELEBRATE_PARAMS_${variant.name}';

/// User preferences for the celebratory completion experience.
///
/// Two independent axes gate what plays:
///
/// * The **visual** celebration (glow bloom, spark/particle burst, checkbox pop,
///   anchor pop) is gated by the master [enabled] switch *and* the matching
///   per-event switch ([habits] / [checklistItems] / [tasks]). Read the
///   combined result via [animateHabits] / [animateChecklistItems] /
///   [animateTasks] at call sites.
/// * The completion **haptic** is gated solely by [haptics], independent of the
///   visuals.
///
/// [tasksSelection] / [habitsSelection] / [checklistItemsSelection] each choose
/// what that content type celebrates with — a fixed variant, a random one, or a
/// combined pair (see [CelebrationSelection]). [variantParams] holds the user's
/// tuned look per variant (globally, reused wherever that variant plays); read
/// the effective params via [paramsFor], which falls back to the untouched
/// defaults for any variant the user hasn't customized.
@immutable
class CelebrationPreferences {
  const CelebrationPreferences({
    required this.enabled,
    required this.haptics,
    required this.habits,
    required this.checklistItems,
    required this.tasks,
    required this.tasksSelection,
    required this.habitsSelection,
    required this.checklistItemsSelection,
    required this.variantParams,
  });

  /// The default before the user has chosen otherwise: every celebration on,
  /// haptics on, each content type's product-default variant, untouched params.
  const CelebrationPreferences.allEnabled()
    : enabled = true,
      haptics = true,
      habits = true,
      checklistItems = true,
      tasks = true,
      tasksSelection = const FixedSelection(defaultTasksVariant),
      habitsSelection = const FixedSelection(defaultHabitsVariant),
      checklistItemsSelection = const FixedSelection(
        defaultChecklistItemsVariant,
      ),
      variantParams = const {};

  /// Product-default variant per content type, applied on a fresh install with no
  /// stored choice (and no legacy global value to migrate from). Distinct per
  /// type so the celebrations feel deliberately different out of the box.
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

  /// What the task-done burst celebrates with.
  final CelebrationSelection tasksSelection;

  /// What the habit-completion burst celebrates with.
  final CelebrationSelection habitsSelection;

  /// What the checklist-item burst celebrates with (also the whole-checklist
  /// 100% bloom, though that is glow-only).
  final CelebrationSelection checklistItemsSelection;

  /// The user's tuned parameters per variant. Holds only the variants the user
  /// has customized; everything else uses [CelebrationParams.defaultsFor] via
  /// [paramsFor].
  final Map<CelebrationVariant, CelebrationParams> variantParams;

  /// The effective tunable look for [variant] — the user's tuned params if any,
  /// otherwise the untouched defaults.
  CelebrationParams paramsFor(CelebrationVariant variant) =>
      variantParams[variant] ?? CelebrationParams.defaultsFor(variant);

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
    CelebrationSelection? tasksSelection,
    CelebrationSelection? habitsSelection,
    CelebrationSelection? checklistItemsSelection,
    Map<CelebrationVariant, CelebrationParams>? variantParams,
  }) => CelebrationPreferences(
    enabled: enabled ?? this.enabled,
    haptics: haptics ?? this.haptics,
    habits: habits ?? this.habits,
    checklistItems: checklistItems ?? this.checklistItems,
    tasks: tasks ?? this.tasks,
    tasksSelection: tasksSelection ?? this.tasksSelection,
    habitsSelection: habitsSelection ?? this.habitsSelection,
    checklistItemsSelection:
        checklistItemsSelection ?? this.checklistItemsSelection,
    variantParams: variantParams ?? this.variantParams,
  );

  @override
  bool operator ==(Object other) =>
      other is CelebrationPreferences &&
      other.enabled == enabled &&
      other.haptics == haptics &&
      other.habits == habits &&
      other.checklistItems == checklistItems &&
      other.tasks == tasks &&
      other.tasksSelection == tasksSelection &&
      other.habitsSelection == habitsSelection &&
      other.checklistItemsSelection == checklistItemsSelection &&
      mapEquals(other.variantParams, variantParams);

  @override
  int get hashCode => Object.hash(
    enabled,
    haptics,
    habits,
    checklistItems,
    tasks,
    tasksSelection,
    habitsSelection,
    checklistItemsSelection,
    Object.hashAllUnordered(
      variantParams.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

/// Holds the celebratory-animation preferences, persisted across launches in
/// [SettingsDb].
///
/// build returns [CelebrationPreferences.allEnabled] synchronously and then
/// hydrates the persisted values, mirroring `ZoomController`. Returning a value
/// synchronously (rather than an `AsyncValue`) lets a celebration call site read
/// the flag on the very frame it would fire — no loading state to thread through
/// a `didUpdateWidget`. Reads from / writes to [SettingsDb] are skipped when it
/// is not registered (some widget tests), so the default simply stays on.
final celebrationPreferencesControllerProvider =
    NotifierProvider<CelebrationPreferencesController, CelebrationPreferences>(
      CelebrationPreferencesController.new,
      name: 'celebrationPreferencesControllerProvider',
    );

class CelebrationPreferencesController
    extends Notifier<CelebrationPreferences> {
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
      final tasksSelection = await db.itemByKey(_celebrateTasksVariantKey);
      final habitsSelection = await db.itemByKey(_celebrateHabitsVariantKey);
      final checklistItemsSelection = await db.itemByKey(
        _celebrateChecklistItemsVariantKey,
      );
      // The pre-split single key — used only to migrate a previously chosen
      // global style onto whichever per-event keys were never written.
      final legacyVariant = await db.itemByKey(_celebrateVariantKey);

      // Per-variant tuned params. Build the full map honouring any variant the
      // user already tuned this session (its key in [_adjusted]).
      final params = <CelebrationVariant, CelebrationParams>{};
      for (final variant in CelebrationVariant.values) {
        final key = _celebrateParamsKey(variant);
        if (_adjusted.contains(key)) {
          final current = state.variantParams[variant];
          if (current != null) params[variant] = current;
          continue;
        }
        final decoded = CelebrationParams.tryDecode(await db.itemByKey(key));
        // Guard against a blob whose payload variant disagrees with its storage
        // key (a hand-edited / corrupt row): storing it would render this
        // variant with another variant's knob set, so drop the mismatch.
        if (decoded != null && decoded.variant == variant) {
          params[variant] = decoded;
        }
      }

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
        tasksSelection: _adjusted.contains(_celebrateTasksVariantKey)
            ? null
            : _resolveSelection(
                tasksSelection,
                legacyVariant,
                CelebrationPreferences.defaultTasksVariant,
              ),
        habitsSelection: _adjusted.contains(_celebrateHabitsVariantKey)
            ? null
            : _resolveSelection(
                habitsSelection,
                legacyVariant,
                CelebrationPreferences.defaultHabitsVariant,
              ),
        checklistItemsSelection:
            _adjusted.contains(_celebrateChecklistItemsVariantKey)
            ? null
            : _resolveSelection(
                checklistItemsSelection,
                legacyVariant,
                CelebrationPreferences.defaultChecklistItemsVariant,
              ),
        variantParams: params,
      );
    } catch (_) {
      // A failed read leaves the all-enabled default (set in build) in place.
    }
  }

  /// Enables or disables *all* visual celebrations (the master switch).
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

  /// Sets what the task-done burst celebrates with.
  Future<void> setTasksSelection(CelebrationSelection selection) async {
    _adjusted.add(_celebrateTasksVariantKey);
    state = state.copyWith(tasksSelection: selection);
    await _persist(_celebrateTasksVariantKey, selection.token);
  }

  /// Sets what the habit-completion burst celebrates with.
  Future<void> setHabitsSelection(CelebrationSelection selection) async {
    _adjusted.add(_celebrateHabitsVariantKey);
    state = state.copyWith(habitsSelection: selection);
    await _persist(_celebrateHabitsVariantKey, selection.token);
  }

  /// Sets what the checklist-item burst celebrates with.
  Future<void> setChecklistItemsSelection(
    CelebrationSelection selection,
  ) async {
    _adjusted.add(_celebrateChecklistItemsVariantKey);
    state = state.copyWith(checklistItemsSelection: selection);
    await _persist(_celebrateChecklistItemsVariantKey, selection.token);
  }

  /// Stores the user's tuned [params] for `params.variant`, applied globally
  /// wherever that variant plays. Params equal to the variant's defaults are
  /// *cleared* rather than stored (empty value → "untouched" on next hydrate),
  /// so `variantParams` only ever holds genuinely customized variants and a
  /// reset never freezes today's defaults against future default changes.
  Future<void> setVariantParams(CelebrationParams params) async {
    final key = _celebrateParamsKey(params.variant);
    _adjusted.add(key);
    final nextParams = {...state.variantParams};
    if (params.isCustomized) {
      nextParams[params.variant] = params;
    } else {
      nextParams.remove(params.variant);
    }
    state = state.copyWith(variantParams: nextParams);
    await _persist(key, params.isCustomized ? params.encode() : '');
  }

  /// Restores [variant] to its untouched defaults (clears any stored override).
  Future<void> resetVariantParams(CelebrationVariant variant) =>
      setVariantParams(CelebrationParams.defaultsFor(variant));

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

/// Resolves a per-content-type selection from storage, oldest-wins-last: the
/// event's own [stored] token if present, else the [legacy] global variant name
/// (one-time migration from before surprise modes / per-content-type styles),
/// else a [FixedSelection] of the product [fallback]. [CelebrationSelection.fromToken]
/// returns `null` for an absent / unrecognised value so each tier falls through.
CelebrationSelection _resolveSelection(
  String? stored,
  String? legacy,
  CelebrationVariant fallback,
) =>
    CelebrationSelection.fromToken(stored) ??
    CelebrationSelection.fromToken(legacy) ??
    FixedSelection(fallback);

/// Convenience read of the current [CelebrationPreferences]. Celebration call
/// sites watch this; tests override it with `overrideWithValue(...)` to assert
/// gating without touching persistence.
final Provider<CelebrationPreferences> celebrationPreferencesProvider =
    Provider.autoDispose<CelebrationPreferences>(
      celebrationPreferences,
      name: 'celebrationPreferencesProvider',
    );
CelebrationPreferences celebrationPreferences(Ref ref) =>
    ref.watch(celebrationPreferencesControllerProvider);
