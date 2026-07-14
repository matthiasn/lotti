import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_keys.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';

export 'package:lotti/features/daily_os_next/state/daily_os_preferences_keys.dart';

/// User-scoped Daily OS settings, persisted in [SettingsDb]: the greeting
/// name, the set of category ids excluded from the day flow, and one-shot
/// coachmark flags. Immutable; mutated through [DailyOsPreferencesController].
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

/// Loads [DailyOsPreferences] from [SettingsDb] on build and writes each
/// mutation straight back. The `_userNameEdited`/`_categoriesEdited` guards
/// ensure an in-flight async load never clobbers a value the user has already
/// changed in this session; coachmark flags need no guard because they only
/// ever flip false→true.
///
/// The greeting name additionally syncs across a user's devices: [setUserName]
/// stamps a last-write timestamp and enqueues a debounced
/// `SyncMessage.dailyOsUserName`, and an inbound synced change (surfaced as a
/// `settingsNotification`) reloads the name here under last-write-wins. The
/// excluded-category set and coachmark flags remain device-local.
class DailyOsPreferencesController extends Notifier<DailyOsPreferences> {
  bool _userNameEdited = false;
  bool _categoriesEdited = false;

  /// True while applying a name arriving from another device, so the reload
  /// does not re-enqueue an outbound sync message (theme-style ping-pong).
  bool _isApplyingSyncedName = false;
  StreamSubscription<Set<String>>? _settingsNotificationSub;
  final _syncDebounceKey =
      'daily_os.userName.sync.${identityHashCode(Object())}';

  @override
  DailyOsPreferences build() {
    ref.onDispose(() {
      unawaited(_settingsNotificationSub?.cancel());
      EasyDebounce.cancel(_syncDebounceKey);
    });
    // Subscribe before the initial load so a synced name arriving during the
    // load window is not missed.
    _watchSyncedUserName();
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
    // Persist the name and a fresh last-write timestamp together so the
    // outbound sync message and the local settings row agree on the winner.
    final updatedAt = clock.now().millisecondsSinceEpoch;
    _save(dailyOsUserNameSettingsKey, trimmed);
    _save(dailyOsUserNameUpdatedAtSettingsKey, updatedAt.toString());
    _enqueueUserNameSync(trimmed, updatedAt);
  }

  /// Debounced outbound sync of the greeting name. Coalesces rapid keystrokes
  /// into one message, skips while applying a synced change, and is a no-op
  /// before sync is configured (`OutboxService` unregistered).
  void _enqueueUserNameSync(String userName, int updatedAt) {
    if (_isApplyingSyncedName) return;
    EasyDebounce.debounce(
      _syncDebounceKey,
      const Duration(milliseconds: 250),
      () async {
        if (!getIt.isRegistered<OutboxService>()) return;
        try {
          await getIt<OutboxService>().enqueueMessage(
            SyncMessage.dailyOsUserName(
              userName: userName,
              updatedAt: updatedAt,
              status: SyncEntryStatus.update,
            ),
          );
        } catch (e, st) {
          if (getIt.isRegistered<DomainLogger>()) {
            getIt<DomainLogger>().error(
              LogDomain.dailyOs,
              e,
              stackTrace: st,
              subDomain: 'enqueue',
            );
          }
        }
      },
    );
  }

  /// Reloads the greeting name when a synced settings change lands, so an
  /// already-open Daily OS surface reflects a name set on another device.
  void _watchSyncedUserName() {
    if (!getIt.isRegistered<UpdateNotifications>()) return;
    _settingsNotificationSub = getIt<UpdateNotifications>().updateStream.listen(
      (ids) async {
        if (!ids.contains(settingsNotification) || _isApplyingSyncedName) {
          return;
        }
        _isApplyingSyncedName = true;
        try {
          await _reloadUserNameFromSettings();
        } catch (e, st) {
          if (getIt.isRegistered<DomainLogger>()) {
            getIt<DomainLogger>().error(
              LogDomain.dailyOs,
              e,
              stackTrace: st,
              subDomain: 'reload',
            );
          }
        }
        _isApplyingSyncedName = false;
      },
    );
  }

  Future<void> _reloadUserNameFromSettings() async {
    if (!getIt.isRegistered<SettingsDb>()) return;
    // The apply phase already resolved last-write-wins before writing, so the
    // stored value is authoritative — override even a locally edited name.
    final stored = await getIt<SettingsDb>().itemByKey(
      dailyOsUserNameSettingsKey,
    );
    if (!ref.mounted) return;
    final synced = stored?.trim() ?? '';
    if (synced != state.userName) {
      state = state.copyWith(userName: synced);
    }
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
