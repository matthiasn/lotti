import 'dart:async';

import 'package:easy_debounce/easy_debounce.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/settings/constants/theming_settings_keys.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';

/// The scheme name this app reports in [SyncMessage.themingSelection].
///
/// The message's name fields are kept for wire compatibility with app versions
/// that still offered selectable FlexColorScheme themes. Those versions ignore
/// an unknown name (falling back to their default scheme) while still applying
/// the [ThemeMode] — which is the only theming preference that exists now.
const String kSyncedThemeName = 'Lotti';

/// Immutable snapshot of the current theming configuration.
///
/// Holds the pre-built design-system [ThemeData] pair handed to `MaterialApp`
/// plus the selected [ThemeMode]. There is exactly one theme — the design
/// system's — so the only user preference left is light/dark/system.
@immutable
class ThemingState {
  const ThemingState({
    this.darkTheme,
    this.lightTheme,
    this.themeMode = ThemeMode.system,
  });

  /// Built dark [ThemeData]; passed to `MaterialApp.darkTheme`.
  final ThemeData? darkTheme;

  /// Built light [ThemeData]; passed to `MaterialApp.theme`.
  final ThemeData? lightTheme;

  /// Whether to use the light, dark, or system-driven theme.
  final ThemeMode themeMode;

  ThemingState copyWith({
    ThemeData? darkTheme,
    ThemeData? lightTheme,
    ThemeMode? themeMode,
  }) {
    return ThemingState(
      darkTheme: darkTheme ?? this.darkTheme,
      lightTheme: lightTheme ?? this.lightTheme,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

/// Stream provider watching the tooltip enable flag from config.
final StreamProvider<bool> enableTooltipsProvider =
    StreamProvider.autoDispose<bool>(
      enableTooltips,
      name: 'enableTooltipsProvider',
    );
Stream<bool> enableTooltips(Ref ref) {
  final db = getIt<JournalDb>();
  return db.watchConfigFlag(enableTooltipFlag);
}

/// Notifier managing the complete theming state.
/// Marked as keepAlive since theme state should persist for the entire app lifecycle.
final themingControllerProvider =
    NotifierProvider<ThemingController, ThemingState>(
      ThemingController.new,
      name: 'themingControllerProvider',
    );

class ThemingController extends Notifier<ThemingState> {
  StreamSubscription<Set<String>>? _settingsNotificationSub;
  bool _isApplyingSyncedChanges = false;
  final _debounceKey = 'theming.sync.${identityHashCode(Object())}';

  @override
  ThemingState build() {
    ref.onDispose(() {
      _settingsNotificationSub?.cancel();
      EasyDebounce.cancel(_debounceKey);
    });

    // Initialize asynchronously
    _init();

    // Return default state - will be updated once preferences are loaded
    return ThemingState(
      darkTheme: _buildTheme(isDark: true),
      lightTheme: _buildTheme(isDark: false),
    );
  }

  Future<void> _init() async {
    // Subscribe to notifications before the initial load so that any sync
    // updates arriving during the await window are not lost.
    _watchThemePrefsUpdates();

    try {
      await _loadThemeMode();
    } catch (e, st) {
      getIt<DomainLogger>().error(
        LogDomain.theming,
        e,
        stackTrace: st,
        subDomain: 'init',
      );
      // Fallback is already set in build(), so we can continue
    }
  }

  void _watchThemePrefsUpdates() {
    _settingsNotificationSub = getIt<UpdateNotifications>().updateStream.listen(
      (ids) async {
        if (ids.contains(settingsNotification) && !_isApplyingSyncedChanges) {
          _isApplyingSyncedChanges = true;
          try {
            await _loadThemeMode();
          } catch (e, st) {
            getIt<DomainLogger>().error(
              LogDomain.theming,
              e,
              stackTrace: st,
              subDomain: 'theme_prefs_reload',
            );
            // Keep current theme if reload fails
          }
          _isApplyingSyncedChanges = false;
        }
      },
    );
  }

  Future<void> _loadThemeMode() async {
    final settingsDb = getIt<SettingsDb>();
    final themeModeStr = await settingsDb.itemByKey(themeModeKey);

    final themeMode = themeModeStr != null
        ? EnumToString.fromString(ThemeMode.values, themeModeStr) ??
              ThemeMode.system
        : ThemeMode.system;

    state = state.copyWith(themeMode: themeMode);
  }

  /// The one theme the app has: the design-system theme, composed with the
  /// Material-level overrides (wolt sheet motion, markdown theme, inputs…)
  /// that `MaterialApp` needs beyond the token-derived basics.
  ThemeData _buildTheme({required bool isDark}) {
    return withOverrides(
      isDark ? DesignSystemTheme.dark() : DesignSystemTheme.light(),
    );
  }

  void _enqueueSyncMessage() {
    // Skip enqueuing sync messages when applying synced changes
    if (_isApplyingSyncedChanges) {
      return;
    }

    EasyDebounce.debounce(
      _debounceKey,
      const Duration(milliseconds: 250),
      () async {
        if (!getIt.isRegistered<OutboxService>()) {
          return;
        }
        try {
          await getIt<OutboxService>().enqueueMessage(
            SyncMessage.themingSelection(
              lightThemeName: kSyncedThemeName,
              darkThemeName: kSyncedThemeName,
              themeMode: state.themeMode.name,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
              status: SyncEntryStatus.update,
            ),
          );
        } catch (e, st) {
          getIt<DomainLogger>().error(
            LogDomain.theming,
            e,
            stackTrace: st,
            subDomain: 'enqueue',
          );
        }
      },
    );
  }

  /// Updates [ThemingState.themeMode] from a segmented-button selection.
  ///
  /// Takes the first entry of `modes` (the picker is single-select), persists
  /// it to settings, and enqueues a debounced sync message. `modes` must be
  /// non-empty.
  void onThemeSelectionChanged(Set<ThemeMode> modes) {
    final themeMode = modes.first;

    state = state.copyWith(themeMode: themeMode);

    getIt<SettingsDb>().saveSettingsItem(
      themeModeKey,
      EnumToString.convertToString(themeMode),
    );
    _enqueueSyncMessage();
  }
}
