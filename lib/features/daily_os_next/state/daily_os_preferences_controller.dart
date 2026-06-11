import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/get_it.dart';

const dailyOsUserNameSettingsKey = 'DAILY_OS_USER_NAME';
const dailyOsExcludedCategoryIdsSettingsKey = 'DAILY_OS_EXCLUDED_CATEGORY_IDS';
const dailyOsTimelineGesturesLearnedSettingsKey =
    'DAILY_OS_TIMELINE_GESTURES_LEARNED';
const dailyOsDayFooterHintRetiredSettingsKey =
    'DAILY_OS_DAY_FOOTER_HINT_RETIRED';

@immutable
class DailyOsPreferences {
  DailyOsPreferences({
    this.userName = '',
    Set<String> excludedCategoryIds = const <String>{},
    this.timelineGesturesLearned = false,
    this.dayFooterHintRetired = false,
  }) : excludedCategoryIds = Set<String>.unmodifiable(excludedCategoryIds);

  final String userName;
  final Set<String> excludedCategoryIds;

  /// One-shot coachmark: true once the user has paged the timeline lanes,
  /// pinch-zoomed, or toggled the lane mode — the "Swipe for actual ·
  /// pinch to zoom" hint retires permanently after the first use.
  final bool timelineGesturesLearned;

  /// One-shot coachmark: true once the user has locked in a day — the
  /// footer's "Talk to reshape the plan…" explainer retires after the
  /// promise has been experienced once.
  final bool dayFooterHintRetired;

  bool get hasUserName => userName.trim().isNotEmpty;

  bool allowsCategory(DayAgentCategory category) =>
      !excludedCategoryIds.contains(category.id);

  bool allowsCategoryId(String categoryId) =>
      !excludedCategoryIds.contains(categoryId);

  DailyOsPreferences copyWith({
    String? userName,
    Set<String>? excludedCategoryIds,
    bool? timelineGesturesLearned,
    bool? dayFooterHintRetired,
  }) {
    return DailyOsPreferences(
      userName: userName ?? this.userName,
      excludedCategoryIds: excludedCategoryIds ?? this.excludedCategoryIds,
      timelineGesturesLearned:
          timelineGesturesLearned ?? this.timelineGesturesLearned,
      dayFooterHintRetired: dayFooterHintRetired ?? this.dayFooterHintRetired,
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
        dailyOsTimelineGesturesLearnedSettingsKey,
        dailyOsDayFooterHintRetiredSettingsKey,
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
    // The coachmark flags only ever go from false to true, so a stored
    // true always wins — no edited-guard needed.
    next = next.copyWith(
      timelineGesturesLearned:
          next.timelineGesturesLearned ||
          values[dailyOsTimelineGesturesLearnedSettingsKey] == 'true',
      dayFooterHintRetired:
          next.dayFooterHintRetired ||
          values[dailyOsDayFooterHintRetiredSettingsKey] == 'true',
    );
    state = next;
  }

  /// Permanently retires the timeline's gesture hint — called the first
  /// time the user pages the lanes, pinch-zooms, or toggles the lane mode.
  void markTimelineGesturesLearned() {
    if (state.timelineGesturesLearned) return;
    state = state.copyWith(timelineGesturesLearned: true);
    _save(dailyOsTimelineGesturesLearnedSettingsKey, 'true');
  }

  /// Permanently retires the day footer's coaching line — called on the
  /// first successful lock-in.
  void markDayFooterHintRetired() {
    if (state.dayFooterHintRetired) return;
    state = state.copyWith(dayFooterHintRetired: true);
    _save(dailyOsDayFooterHintRetiredSettingsKey, 'true');
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
