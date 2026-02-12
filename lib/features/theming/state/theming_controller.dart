import 'dart:async';
import 'dart:io';

import 'package:easy_debounce/easy_debounce.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/settings/constants/theming_settings_keys.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/theming/model/theme_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/themes/gamey/gamey_theme_builder.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theming_controller.g.dart';

/// Get emoji font fallback list for the current platform.
/// Only Linux needs explicit emoji font configuration.
List<String>? _getEmojiFontFallback() {
  return !kIsWeb && Platform.isLinux ? const ['Noto Color Emoji'] : null;
}

/// Immutable state representing the current theming configuration.
@immutable
class ThemingState {
  const ThemingState({
    this.darkTheme,
    this.lightTheme,
    this.darkThemeName,
    this.lightThemeName,
    this.themeMode = ThemeMode.system,
  });

  final ThemeData? darkTheme;
  final ThemeData? lightTheme;
  final String? darkThemeName;
  final String? lightThemeName;
  final ThemeMode themeMode;

  /// Check if the currently active theme is using the gamey theme.
  /// This considers the current theme mode to determine which theme is active.
  bool get isUsingGameyTheme {
    switch (themeMode) {
      case ThemeMode.light:
        return isGameyTheme(lightThemeName);
      case ThemeMode.dark:
        return isGameyTheme(darkThemeName);
      case ThemeMode.system:
        // For system mode, check both since we don't know the system preference here.
        // Widgets should use isCurrentlyUsingGameyTheme with BuildContext instead.
        return isGameyTheme(lightThemeName) || isGameyTheme(darkThemeName);
    }
  }

  /// Check if the gamey theme is active for a specific brightness.
  bool isGameyThemeForBrightness(Brightness brightness) {
    return brightness == Brightness.dark
        ? isGameyTheme(darkThemeName)
        : isGameyTheme(lightThemeName);
  }

  ThemingState copyWith({
    ThemeData? darkTheme,
    ThemeData? lightTheme,
    String? darkThemeName,
    String? lightThemeName,
    ThemeMode? themeMode,
  }) {
    return ThemingState(
      darkTheme: darkTheme ?? this.darkTheme,
      lightTheme: lightTheme ?? this.lightTheme,
      darkThemeName: darkThemeName ?? this.darkThemeName,
      lightThemeName: lightThemeName ?? this.lightThemeName,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

/// Stream provider watching the tooltip enable flag from config.
@riverpod
Stream<bool> enableTooltips(Ref ref) {
  final db = getIt<JournalDb>();
  return db.watchConfigFlag(enableTooltipFlag);
}

/// Notifier managing the complete theming state.
/// Marked as keepAlive since theme state should persist for the entire app lifecycle.
@Riverpod(keepAlive: true)
class ThemingController extends _$ThemingController {
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
      darkTheme: _buildTheme(defaultThemeName, isDark: true),
      lightTheme: _buildTheme(defaultThemeName, isDark: false),
      darkThemeName: defaultThemeName,
      lightThemeName: defaultThemeName,
    );
  }

  Future<void> _init() async {
    try {
      await _loadSelectedSchemes();
    } catch (e, st) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'THEMING_CONTROLLER',
        subDomain: 'init',
        stackTrace: st,
      );
      // Fallback is already set in build(), so we can continue
    }

    _watchThemePrefsUpdates();
  }

  void _watchThemePrefsUpdates() {
    _settingsNotificationSub =
        getIt<UpdateNotifications>().updateStream.listen((ids) async {
      if (ids.contains(settingsNotification) && !_isApplyingSyncedChanges) {
        _isApplyingSyncedChanges = true;
        try {
          await _loadSelectedSchemes();
        } catch (e, st) {
          getIt<LoggingService>().captureException(
            e,
            domain: 'THEMING_CONTROLLER',
            subDomain: 'theme_prefs_reload',
            stackTrace: st,
          );
          // Keep current theme if reload fails
        }
        _isApplyingSyncedChanges = false;
      }
    });
  }

  Future<void> _loadSelectedSchemes() async {
    final settingsDb = getIt<SettingsDb>();

    final darkThemeName = await settingsDb.itemByKey(darkSchemeNameKey);
    final lightThemeName = await settingsDb.itemByKey(lightSchemeNameKey);
    final themeModeStr = await settingsDb.itemByKey(themeModeKey);

    final themeMode = themeModeStr != null
        ? EnumToString.fromString(ThemeMode.values, themeModeStr) ??
            ThemeMode.system
        : ThemeMode.system;

    final effectiveDarkThemeName = darkThemeName ?? defaultThemeName;
    final effectiveLightThemeName = lightThemeName ?? defaultThemeName;

    state = ThemingState(
      darkTheme: _buildTheme(effectiveDarkThemeName, isDark: true),
      lightTheme: _buildTheme(effectiveLightThemeName, isDark: false),
      darkThemeName: effectiveDarkThemeName,
      lightThemeName: effectiveLightThemeName,
      themeMode: themeMode,
    );
  }

  ThemeData _buildTheme(String? themeName, {required bool isDark}) {
    // Check if this is the gamey theme
    final isGamey = isGameyTheme(themeName);

    // For gamey theme, use the designated base scheme; otherwise use selected scheme
    final scheme =
        isGamey ? gameyBaseScheme : (themes[themeName] ?? FlexScheme.greyLaw);

    var themeData = isDark
        ? FlexThemeData.dark(
            scheme: scheme,
            fontFamily: GoogleFonts.inclusiveSans().fontFamily,
            fontFamilyFallback: _getEmojiFontFallback(),
          )
        : FlexThemeData.light(
            scheme: scheme,
            fontFamily: GoogleFonts.inclusiveSans().fontFamily,
            fontFamilyFallback: _getEmojiFontFallback(),
          );

    // Apply base overrides
    themeData = withOverrides(themeData);

    // Apply gamey theme enhancements if this is the gamey theme
    if (isGamey) {
      themeData = GameyThemeBuilder.build(themeData);
    }

    return themeData;
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
              lightThemeName: state.lightThemeName ?? defaultThemeName,
              darkThemeName: state.darkThemeName ?? defaultThemeName,
              themeMode: state.themeMode.name,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
              status: SyncEntryStatus.update,
            ),
          );
        } catch (e, st) {
          getIt<LoggingService>().captureException(
            e,
            domain: 'THEMING_SYNC',
            subDomain: 'enqueue',
            stackTrace: st,
          );
        }
      },
    );
  }

  /// Sets the light theme to the specified theme name.
  void setLightTheme(String themeName) {
    if (!isValidThemeName(themeName)) return;

    state = state.copyWith(
      lightTheme: _buildTheme(themeName, isDark: false),
      lightThemeName: themeName,
    );

    getIt<SettingsDb>().saveSettingsItem(lightSchemeNameKey, themeName);
    _enqueueSyncMessage();
  }

  /// Sets the dark theme to the specified theme name.
  void setDarkTheme(String themeName) {
    if (!isValidThemeName(themeName)) return;

    state = state.copyWith(
      darkTheme: _buildTheme(themeName, isDark: true),
      darkThemeName: themeName,
    );

    getIt<SettingsDb>().saveSettingsItem(darkSchemeNameKey, themeName);
    _enqueueSyncMessage();
  }

  /// Called when the theme mode selection changes.
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
