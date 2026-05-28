import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/get_it.dart';

const dailyOsUserNameSettingsKey = 'DAILY_OS_USER_NAME';
const dailyOsExcludedCategoryIdsSettingsKey = 'DAILY_OS_EXCLUDED_CATEGORY_IDS';

@immutable
class DailyOsPreferences {
  DailyOsPreferences({
    this.userName = '',
    Set<String> excludedCategoryIds = const <String>{},
  }) : excludedCategoryIds = Set<String>.unmodifiable(excludedCategoryIds);

  final String userName;
  final Set<String> excludedCategoryIds;

  bool get hasUserName => userName.trim().isNotEmpty;

  bool allowsCategory(DayAgentCategory category) =>
      !excludedCategoryIds.contains(category.id);

  bool allowsCategoryId(String categoryId) =>
      !excludedCategoryIds.contains(categoryId);

  DailyOsPreferences copyWith({
    String? userName,
    Set<String>? excludedCategoryIds,
  }) {
    return DailyOsPreferences(
      userName: userName ?? this.userName,
      excludedCategoryIds: excludedCategoryIds ?? this.excludedCategoryIds,
    );
  }
}

class DailyOsPreferencesController extends Notifier<DailyOsPreferences> {
  bool _userNameEdited = false;
  bool _categoriesEdited = false;

  @override
  DailyOsPreferences build() {
    unawaited(_load());
    return DailyOsPreferences();
  }

  Future<void> _load() async {
    if (!getIt.isRegistered<SettingsDb>()) return;
    final values = await getIt<SettingsDb>().itemsByKeys(
      const [
        dailyOsUserNameSettingsKey,
        dailyOsExcludedCategoryIdsSettingsKey,
      ],
    );
    if (!ref.mounted) return;

    var next = state;
    if (!_userNameEdited) {
      next = next.copyWith(
        userName: values[dailyOsUserNameSettingsKey]?.trim() ?? '',
      );
    }
    if (!_categoriesEdited) {
      next = next.copyWith(
        excludedCategoryIds: _decodeCategoryIds(
          values[dailyOsExcludedCategoryIdsSettingsKey],
        ),
      );
    }
    state = next;
  }

  void setUserName(String value) {
    _userNameEdited = true;
    final trimmed = value.trim();
    state = state.copyWith(userName: trimmed);
    _save(dailyOsUserNameSettingsKey, trimmed);
  }

  void setCategoryEnabled(String categoryId, {required bool enabled}) {
    _categoriesEdited = true;
    final next = {...state.excludedCategoryIds};
    if (enabled) {
      next.remove(categoryId);
    } else {
      next.add(categoryId);
    }
    state = state.copyWith(excludedCategoryIds: next);
    _save(
      dailyOsExcludedCategoryIdsSettingsKey,
      jsonEncode(next.toList()..sort()),
    );
  }

  void setIncludedCategoryIds({
    required Set<String> includedCategoryIds,
    required Iterable<String> allCategoryIds,
  }) {
    _categoriesEdited = true;
    final allIds = allCategoryIds.toSet();
    final next = allIds.difference(includedCategoryIds.intersection(allIds));
    state = state.copyWith(excludedCategoryIds: next);
    _save(
      dailyOsExcludedCategoryIdsSettingsKey,
      jsonEncode(next.toList()..sort()),
    );
  }

  void includeAllCategories() {
    _categoriesEdited = true;
    state = state.copyWith(excludedCategoryIds: const <String>{});
    _save(dailyOsExcludedCategoryIdsSettingsKey, jsonEncode(const <String>[]));
  }

  void _save(String key, String value) {
    if (!getIt.isRegistered<SettingsDb>()) return;
    unawaited(getIt<SettingsDb>().saveSettingsItem(key, value));
  }

  Set<String> _decodeCategoryIds(String? raw) {
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

final dailyOsPreferencesControllerProvider =
    NotifierProvider<DailyOsPreferencesController, DailyOsPreferences>(
      DailyOsPreferencesController.new,
    );

final FutureProvider<List<DayAgentCategory>> dailyOsKnownCategoriesProvider =
    FutureProvider.autoDispose<List<DayAgentCategory>>((ref) async {
      final agent = ref.read(dayAgentProvider);
      final items = await agent.surfaceTaskCorpus();
      final categories = <String, DayAgentCategory>{};
      for (final item in items) {
        categories[item.category.id] = item.category;
      }
      final sorted = categories.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return sorted;
    });
