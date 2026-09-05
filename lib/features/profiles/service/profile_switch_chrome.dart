import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The chrome colour carried ACROSS a profile switch.
///
/// A switch discards the ProviderScope and resets getIt, so nothing that
/// knows the app's resolved theme survives it — yet frames still have to be
/// painted while it runs: the switch splash, and then the next generation's
/// loading frame while it re-resolves theming from the new world's
/// `SettingsDb`. Painted from Flutter's defaults those frames are WHITE,
/// which strobes between two themed frames — most visibly on leaving the
/// demo, where users hit it repeatedly.
///
/// So the running generation publishes its resolved background here
/// ([capture]), and the switch chrome reads it back ([background]) until the
/// next generation's own theme resolves. Deliberately a singleton OUTSIDE
/// getIt (reset by the switch) and OUTSIDE the tree (replaced by the switch)
/// — the same lifetime problem as `DemoCopyFailureNotices`, and the same
/// answer.
///
/// On a cold boot nothing has been published yet, so it falls back to the
/// design-system dark background — exactly what the loading frame already
/// hard-coded before this existed, so first launch is unchanged.
class ProfileSwitchChrome {
  ProfileSwitchChrome._();

  static final ProfileSwitchChrome instance = ProfileSwitchChrome._();

  Color? _background;
  Brightness? _brightness;

  /// Publishes the live generation's resolved chrome.
  ///
  /// Called from the app's themed branch during build. That is a deliberate
  /// side effect in `build`: it is a plain field write with no notification
  /// and no listeners in the current tree — the only readers are frames
  /// built AFTER that tree has been torn down — and the resolved
  /// (light-vs-dark) theme exists nowhere else.
  void capture(ThemeData theme) {
    _background = theme.scaffoldBackgroundColor;
    _brightness = theme.brightness;
  }

  /// Background to paint while no generation's theme is available.
  Color get background => _background ?? dsTokensDark.colors.background.level01;

  /// Brightness the switch chrome should assume.
  Brightness get brightness => _brightness ?? Brightness.dark;

  /// The token set matching [brightness], for the few chrome accents (the
  /// splash spinner) that still need a colour while no theme exists.
  DsTokens get tokens =>
      brightness == Brightness.dark ? dsTokensDark : dsTokensLight;

  /// Whether a generation has published its chrome in this process yet.
  bool get hasCapture => _background != null;

  @visibleForTesting
  void reset() {
    _background = null;
    _brightness = null;
  }
}
