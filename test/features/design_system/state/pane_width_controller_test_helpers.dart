import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

/// Glados generators for the pane-width property tests.
///
/// The numeric range is deliberately wider than the production clamp window
/// (`[min, max]`) so generated values land below the minimum, inside the
/// window, and above the maximum, exercising both clamp branches of
/// `_parseWidth`.
extension AnyPaneWidth on glados.Any {
  /// Doubles spanning well below `minSidebarWidth` to well above
  /// `maxSidebarWidth`.
  glados.Generator<double> get sidebarWidthValue =>
      glados.DoubleAnys(this).doubleInRange(0, 1000);

  /// Doubles spanning well below `minListPaneWidth` to well above
  /// `maxListPaneWidth`.
  glados.Generator<double> get listPaneWidthValue =>
      glados.DoubleAnys(this).doubleInRange(0, 2000);
}

/// Creates a fresh [ProviderContainer] with [SettingsDb.itemsByKeys] stubbed
/// to return the given values for the pane width keys.
Future<ProviderContainer> hCreateContainerWithPersistedWidths({
  String? sidebarWidth,
  String? listPaneWidth,
  String? sidebarCollapsed,
}) async {
  await tearDownTestGetIt();
  final mocks = await setUpTestGetIt();
  when(
    () => mocks.settingsDb.itemsByKeys(any()),
  ).thenAnswer(
    (_) async => <String, String?>{
      sidebarWidthKey: sidebarWidth,
      listPaneWidthKey: listPaneWidth,
      sidebarCollapsedKey: sidebarCollapsed,
    },
  );
  return ProviderContainer();
}

/// Triggers provider read and drains pending microtasks so the async
/// `_loadPersistedWidths` (which calls the mocked `itemsByKeys`) completes
/// deterministically.
///
/// As of this writing `_loadPersistedWidths` contains a single `await` (the
/// `settingsDb.itemsByKeys` call), so one microtask hop would suffice. The
/// 16-iteration loop is deliberate headroom: it is resilient to future async
/// hops being added inside `_loadPersistedWidths` — a single `Future.value()`
/// would only cover today's one `await` and would silently return the
/// pre-hydration default if another were added. If `_loadPersistedWidths`
/// ever gains so many awaits that 16 hops no longer drain it, increase this
/// count.
Future<PaneWidths> hAwaitHydration(ProviderContainer container) async {
  container.read(paneWidthControllerProvider);
  for (var i = 0; i < 16; i++) {
    await Future<void>.value();
  }
  return container.read(paneWidthControllerProvider);
}

/// Re-stubs the already-registered [SettingsDb] mock with the given persisted
/// strings and hydrates a fresh controller, returning the resulting state.
///
/// Unlike [hCreateContainerWithPersistedWidths] this does not reset GetIt; it
/// only re-stubs the existing mock so it stays cheap when invoked hundreds of
/// times from a Glados property loop. The caller owns the container's lifetime
/// and must dispose it.
Future<PaneWidths> hHydrateWith({
  String? sidebarWidth,
  String? listPaneWidth,
  String? sidebarCollapsed,
}) async {
  when(
    () => getIt<SettingsDb>().itemsByKeys(any()),
  ).thenAnswer(
    (_) async => <String, String?>{
      sidebarWidthKey: sidebarWidth,
      listPaneWidthKey: listPaneWidth,
      sidebarCollapsedKey: sidebarCollapsed,
    },
  );
  final container = ProviderContainer();
  try {
    return await hAwaitHydration(container);
  } finally {
    container.dispose();
  }
}
