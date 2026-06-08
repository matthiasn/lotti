import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/ai/ui/settings/services/ai_setup_prompt_service.dart';
import 'package:lotti/features/settings/state/zoom_controller.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';

import '../widget_test_utils.dart';

/// Shared private-stub equivalents for the beamer widget tests.
///
/// These were previously redeclared identically in both
/// `beamer_app_test.dart` and `my_beamer_app_test.dart`. They live here so
/// the two test files share a single definition instead of drifting apart.
/// Scope: import only from tests under `test/beamer/`.

/// A wildcard [BeamLocation] that renders an empty page for any path. Used to
/// satisfy the nav-service delegates without pulling real pages into the tree.
class EmptyTestLocation extends BeamLocation<BeamState> {
  EmptyTestLocation(super.routeInformation);

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    return const [
      BeamPage(
        key: ValueKey('empty'),
        child: SizedBox.shrink(),
      ),
    ];
  }

  @override
  List<Pattern> get pathPatterns => ['*'];
}

/// A [ThemingController] whose `build` returns a fully resolved (non-null)
/// light/dark theme, so `MyBeamerApp` renders its real app shell instead of
/// the loading scaffold.
class ReadyThemingController extends ThemingController {
  @override
  ThemingState build() => ThemingState(
    darkTheme: resolveTestTheme(ThemeData.dark()),
    lightTheme: resolveTestTheme(ThemeData.light()),
  );
}

/// A [ZoomController] pinned to the default scale.
class TestZoomController extends ZoomController {
  @override
  double build() => defaultZoomScale;
}

/// An [AiSetupPromptService] that never wants to show the setup prompt.
class MockAiSetupPromptService extends AiSetupPromptService {
  @override
  Future<bool> build() async => false;
}
