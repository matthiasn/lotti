import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/settings/constants/theming_settings_keys.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theming_controller.g.dart';

/// Stream provider watching the tooltip enable flag from config.
@riverpod
Stream<bool> enableTooltips(Ref ref) {
  return getIt<JournalDb>().watchConfigFlag(enableTooltipFlag);
}

/// App-wide light theme: design-system tokens ([DesignSystemTheme.light])
/// with [withAppWidgetOverrides] layered on top. Singleton, built once
/// at first access.
final ThemeData lottiLightTheme = withAppWidgetOverrides(
  DesignSystemTheme.light(),
);

/// App-wide dark theme: design-system tokens ([DesignSystemTheme.dark])
/// with [withAppWidgetOverrides] layered on top. Singleton, built once
/// at first access.
final ThemeData lottiDarkTheme = withAppWidgetOverrides(
  DesignSystemTheme.dark(),
);

/// Parses a stored [ThemeMode] name, falling back to [ThemeMode.system].
ThemeMode _themeModeFromStored(String? stored) {
  if (stored == null) return ThemeMode.system;
  return ThemeMode.values.firstWhere(
    (mode) => mode.name == stored,
    orElse: () => ThemeMode.system,
  );
}

/// Immutable state representing the current theming configuration.
///
/// The app exposes three theme modes only — Light, Dark, and System (auto).
/// Light/dark `ThemeData` are built once from the design system tokens, so
/// the state only varies by the selected mode.
@immutable
class ThemingState {
  const ThemingState({
    required this.lightTheme,
    required this.darkTheme,
    this.themeMode = ThemeMode.system,
  });

  final ThemeData lightTheme;
  final ThemeData darkTheme;
  final ThemeMode themeMode;

  ThemingState copyWith({ThemeMode? themeMode}) {
    return ThemingState(
      lightTheme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

/// Notifier managing the current [ThemeMode] selection.
/// Marked as keepAlive since theme state should persist for the entire
/// app lifecycle.
@Riverpod(keepAlive: true)
class ThemingController extends _$ThemingController {
  @override
  ThemingState build() {
    unawaited(_loadThemeMode());
    return ThemingState(
      lightTheme: lottiLightTheme,
      darkTheme: lottiDarkTheme,
    );
  }

  Future<void> _loadThemeMode() async {
    try {
      final stored = await getIt<SettingsDb>().itemByKey(themeModeKey);
      state = state.copyWith(themeMode: _themeModeFromStored(stored));
    } catch (e, st) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'THEMING_CONTROLLER',
        subDomain: 'loadThemeMode',
        stackTrace: st,
      );
    }
  }

  /// Persists the new theme mode. Theme selection is a per-device
  /// preference and is not synced across devices.
  void onThemeSelectionChanged(Set<ThemeMode> modes) {
    if (modes.isEmpty) return;
    final themeMode = modes.first;
    state = state.copyWith(themeMode: themeMode);
    unawaited(_persistThemeMode(themeMode));
  }

  Future<void> _persistThemeMode(ThemeMode themeMode) async {
    try {
      await getIt<SettingsDb>().saveSettingsItem(
        themeModeKey,
        themeMode.name,
      );
    } catch (e, st) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'THEMING_CONTROLLER',
        subDomain: 'saveThemeMode',
        stackTrace: st,
      );
    }
  }
}
