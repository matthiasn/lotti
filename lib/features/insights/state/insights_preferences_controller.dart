import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';

/// SettingsDb key for the focus-category selection (JSON string list).
const insightsFocusCategoryIdsSettingsKey = 'INSIGHTS_FOCUS_CATEGORY_IDS';

/// Per-device Insights preferences.
///
/// Stored in [SettingsDb], which is local-only (only explicitly-coded keys
/// sync) — matching the Daily OS excluded-categories precedent.
@immutable
class InsightsPreferences {
  InsightsPreferences({Set<String> focusCategoryIds = const <String>{}})
    : focusCategoryIds = Set<String>.unmodifiable(focusCategoryIds);

  /// Categories the user counts as "focus" work. Empty = unconfigured,
  /// in which case the KPI row shows only the total.
  final Set<String> focusCategoryIds;

  bool get isConfigured => focusCategoryIds.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is InsightsPreferences &&
      setEquals(other.focusCategoryIds, focusCategoryIds);

  @override
  int get hashCode => Object.hashAllUnordered(focusCategoryIds);
}

/// Single writer for [InsightsPreferences]: loads once from [SettingsDb],
/// holds state in memory, and persists on every change. SettingsDb writes
/// emit no `UpdateNotifications` token, so dependents must watch this
/// provider — never re-read the database.
class InsightsPreferencesController extends Notifier<InsightsPreferences> {
  bool _edited = false;

  @override
  InsightsPreferences build() {
    unawaited(_load());
    return InsightsPreferences();
  }

  Future<void> _load() async {
    if (!getIt.isRegistered<SettingsDb>()) return;
    final raw = await getIt<SettingsDb>().itemByKey(
      insightsFocusCategoryIdsSettingsKey,
    );
    if (!ref.mounted || _edited) return;
    state = InsightsPreferences(focusCategoryIds: _decode(raw));
  }

  /// Adds [categoryId] to the focus set if absent, removes it if present, then
  /// persists the new set. Sets the `_edited` flag so a still-in-flight initial
  /// [_load] never clobbers this user edit.
  void toggleFocusCategory(String categoryId) {
    _edited = true;
    final next = {...state.focusCategoryIds};
    if (!next.remove(categoryId)) {
      next.add(categoryId);
    }
    state = InsightsPreferences(focusCategoryIds: next);
    _save(next);
  }

  void _save(Set<String> ids) {
    if (!getIt.isRegistered<SettingsDb>()) return;
    unawaited(
      getIt<SettingsDb>().saveSettingsItem(
        insightsFocusCategoryIdsSettingsKey,
        jsonEncode(ids.toList()..sort()),
      ),
    );
  }

  Set<String> _decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>{};
      return decoded.whereType<String>().toSet();
    } catch (_) {
      return const <String>{};
    }
  }
}

final insightsPreferencesControllerProvider =
    NotifierProvider<InsightsPreferencesController, InsightsPreferences>(
      InsightsPreferencesController.new,
      name: 'insightsPreferencesControllerProvider',
    );
