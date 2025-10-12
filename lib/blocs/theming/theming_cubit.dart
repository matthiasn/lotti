import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lotti/blocs/theming/theming_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';

const lightSchemeNameKey = 'LIGHT_SCHEME';
const darkSchemeNameKey = 'DARK_SCHEMA';
const themeModeKey = 'THEME_MODE';

/// Get emoji font fallback list for the current platform.
/// Only Linux needs explicit emoji font configuration.
List<String>? _getEmojiFontFallback() {
  return !kIsWeb && Platform.isLinux ? const ['Noto Color Emoji'] : null;
}

class ThemingCubit extends Cubit<ThemingState> {
  ThemingCubit() : super(ThemingState(enableTooltips: true)) {
    _loadSelectedSchemes();
    getIt<JournalDb>()
        .watchConfigFlag(enableTooltipFlag)
        .forEach((enableTooltips) {
      _enableTooltips = enableTooltips;
      emitState();
    });
  }

  bool _enableTooltips = false;

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
    }
  }

  void onThemeSelectionChanged(Set<ThemeMode> modes) {
    _themeMode = modes.first;

    getIt<SettingsDb>().saveSettingsItem(
      themeModeKey,
      EnumToString.convertToString(_themeMode),
    );
    emitState();
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
    }
  }

  @override
  Future<void> close() async {
    await super.close();
  }
}
