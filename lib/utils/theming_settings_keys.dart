// SettingsDb keys for persisted theming preferences. The wire values are
// frozen for backward compatibility — including the legacy typo in the
// dark-scheme key — so they must not be "corrected" without a migration.

/// Key for the selected light-mode color scheme name.
const lightSchemeNameKey = 'LIGHT_SCHEME';

/// Key for the selected dark-mode color scheme name. The persisted value is
/// the misspelled `DARK_SCHEMA`; kept verbatim so existing installs keep
/// reading their stored choice.
const darkSchemeNameKey = 'DARK_SCHEMA'; // Keep existing typo for compatibility

/// Key for the `ThemeMode` selection (light / dark / system).
const themeModeKey = 'THEME_MODE';

/// Key for the last-write timestamp of the theming prefs, used to resolve
/// which side wins when the preferences are synced across devices.
const themePrefsUpdatedAtKey = 'THEME_PREFS_UPDATED_AT';
