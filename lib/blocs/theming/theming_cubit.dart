import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lotti/blocs/theming/theming_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/settings/constants/theming_settings_keys.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';

/// Get emoji font fallback list for the current platform.
/// Only Linux needs explicit emoji font configuration.
List<String>? _getEmojiFontFallback() {
  return !kIsWeb && Platform.isLinux ? const ['Noto Color Emoji'] : null;
}

class ThemingCubit extends Cubit<ThemingState> {
  ThemingCubit() : super(ThemingState(enableTooltips: true)) {
    // Intentionally not awaited - initialization happens asynchronously
    // while cubit remains in valid state. Errors are caught and logged.
    unawaited(_init());
  }

  Future<void> _init() async {
    // Initialize with default themes as fallback
    _initLightTheme(_lightThemeName);
    _initDarkTheme(_darkThemeName);
    emitState();

    // Try to load user's theme preferences
    try {
      await _loadSelectedSchemes();
    } catch (e, st) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'THEMING_CUBIT',
        subDomain: 'init',
        stackTrace: st,
      );
      // Fallback is already set above, so we can continue
      getIt<LoggingService>().captureException(
        Exception('Using default theme (Grey Law) due to initialization error'),
        domain: 'THEMING_CUBIT',
        subDomain: 'fallback',
      );
    }

    // Set up tooltip subscription regardless of theme load success
    _tooltipSubscription =
        getIt<JournalDb>().watchConfigFlag(enableTooltipFlag).listen(
      (enableTooltips) {
        _enableTooltips = enableTooltips;
        emitState();
      },
      onError: (Object e, StackTrace st) {
        getIt<LoggingService>().captureException(
          e,
          domain: 'THEMING_CUBIT',
          subDomain: 'tooltip_stream',
          stackTrace: st,
        );
      },
    );

    _watchThemePrefsUpdates();
  }

  bool _enableTooltips = true;
  final _debounceKey = 'theming.sync.${identityHashCode(Object())}';
  bool _isApplyingSyncedChanges = false;
  bool _isClosing = false;
  StreamSubscription<bool>? _tooltipSubscription;
  StreamSubscription<List<SettingsItem>>? _themePrefsSubscription;

  void _watchThemePrefsUpdates() {
    _themePrefsSubscription = getIt<SettingsDb>()
        .watchSettingsItemByKey(themePrefsUpdatedAtKey)
        .listen(
      (items) async {
        if (_isClosing || isClosed) return;
        if (items.isNotEmpty && !_isApplyingSyncedChanges) {
          _isApplyingSyncedChanges = true;
          try {
            await _loadSelectedSchemes();
          } catch (e, st) {
            getIt<LoggingService>().captureException(
              e,
              domain: 'THEMING_CUBIT',
              subDomain: 'theme_prefs_reload',
              stackTrace: st,
            );
            // Keep current theme if reload fails
          }
          _isApplyingSyncedChanges = false;
        }
      },
      onError: (Object e, StackTrace st) {
        getIt<LoggingService>().captureException(
          e,
          domain: 'THEMING_CUBIT',
          subDomain: 'theme_prefs_stream',
          stackTrace: st,
        );
      },
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
              lightThemeName: _lightThemeName ?? 'Grey Law',
              darkThemeName: _darkThemeName ?? 'Grey Law',
              themeMode: _themeMode.name,
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

  Future<void> _loadSelectedSchemes() async {
    _darkThemeName = await getIt<SettingsDb>().itemByKey(darkSchemeNameKey);
    _lightThemeName = await getIt<SettingsDb>().itemByKey(lightSchemeNameKey);
    _initLightTheme(_lightThemeName);
    _initDarkTheme(_darkThemeName);

    final themeMode = await getIt<SettingsDb>().itemByKey(themeModeKey);

    if (themeMode != null) {
      _themeMode = EnumToString.fromString(ThemeMode.values, themeMode) ??
          ThemeMode.system;
    }

    emitState();
  }

  void _initLightTheme(String? themeName) {
    final scheme = themes[themeName] ?? FlexScheme.greyLaw;
    _lightTheme = withOverrides(
      FlexThemeData.light(
        scheme: scheme,
        fontFamily: GoogleFonts.inclusiveSans().fontFamily,
        fontFamilyFallback: _getEmojiFontFallback(),
      ),
    );
  }

  void _initDarkTheme(String? themeName) {
    final scheme = themes[themeName] ?? FlexScheme.greyLaw;
    _darkTheme = withOverrides(
      FlexThemeData.dark(
        scheme: scheme,
        fontFamily: GoogleFonts.inclusiveSans().fontFamily,
        fontFamilyFallback: _getEmojiFontFallback(),
      ),
    );
  }

  String? _darkThemeName = 'Grey Law';
  String? _lightThemeName = 'Grey Law';
  ThemeData? _darkTheme;
  ThemeData? _lightTheme;
  ThemeMode _themeMode = ThemeMode.system;

  void emitState() {
    emit(
      ThemingState(
        darkTheme: _darkTheme,
        darkThemeName: _darkThemeName,
        lightTheme: _lightTheme,
        lightThemeName: _lightThemeName,
        themeMode: _themeMode,
        enableTooltips: _enableTooltips,
      ),
    );
  }

  void setLightTheme(String themeName) {
    final theme = themes[themeName];
    if (theme != null) {
      _initLightTheme(themeName);
      _lightThemeName = themeName;

      getIt<SettingsDb>().saveSettingsItem(
        lightSchemeNameKey,
        themeName,
      );

      emitState();
      _enqueueSyncMessage();
    }
  }

  void onThemeSelectionChanged(Set<ThemeMode> modes) {
    _themeMode = modes.first;

    getIt<SettingsDb>().saveSettingsItem(
      themeModeKey,
      EnumToString.convertToString(_themeMode),
    );
    emitState();
    _enqueueSyncMessage();
  }

  void setDarkTheme(String themeName) {
    final theme = themes[themeName];
    if (theme != null) {
      _initDarkTheme(themeName);
      _darkThemeName = themeName;

      getIt<SettingsDb>().saveSettingsItem(
        darkSchemeNameKey,
        themeName,
      );

      emitState();
      _enqueueSyncMessage();
    }
  }

  @override
  Future<void> close() async {
    _isClosing = true;
    await _tooltipSubscription?.cancel();
    await _themePrefsSubscription?.cancel();
    await super.close();
  }
}
