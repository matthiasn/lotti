---
name: app-screenshots
description: Capture in-app screenshots of a widget or flow at mobile + desktop sizes — offline, deterministic, real fonts and icons — using the reusable screenshot harness. Use when asked to "show me X in the app", "screenshot this screen", or to preview a UI change for review on phone vs desktop.
argument-hint: "<surface to capture, e.g. 'project create modal'>"
---

# In-App Screenshots

Produces PNGs of a widget or flow rendered inside the real app shell, at phone
and desktop viewports, with real fonts and icons. It runs through
`flutter test --update-goldens` — fully offline and deterministic — so it does
**not** require a display, the GUI app, or driving the device.

This is a visualization tool, **not** a golden test: there are no committed
reference images. You write a throwaway capture test, emit the PNGs, share
them, then delete the test. Nothing screenshot-related gets committed unless
the user explicitly asks to keep it.

## When to use

- "Show me the <screen/modal/dialog> in app context."
- "What does this change look like on mobile vs desktop?"
- Previewing a UI change for design review.

For "is this change actually wired up / does it behave correctly", prefer the
`verify` skill (runs the real app). This skill is about *appearance*.

## The harness

`test/test_utils/screenshot_harness.dart` provides:

- `loadAppFonts()` — loads every bundled font (app families + Material/Cupertino
  icon fonts + icon-font packages) from `FontManifest.json`. Call once in
  `setUpAll`. Without it, glyphs and icons render as boxes.
- `screenshotTheme({bool dark = true})` — the production `withOverrides` theme
  with `Inter` applied to the Material text themes (the bare test theme falls
  back to an unbundled font otherwise).
- `captureInApp(tester, {child, name, size, dark, devicePixelRatio, overrides, interaction, outputDir})`
  — sizes the view, pumps `child` in the app shell, runs `interaction` (open a
  modal, tap a FAB, focus a field…), then writes `<outputDir>/<name>.png`
  relative to the **calling test file's** directory.
- `ScreenshotViewport.phone` (390×844) and `ScreenshotViewport.desktop`
  (1280×800).

## Workflow

1. **Find the surface and how to reach the state.** Identify the entry widget
   (often a tab/page like `ProjectsTabPage`) and the tap/scroll needed to reach
   the state to capture (e.g. tapping the FAB to open a modal). Reuse existing
   widget tests for that surface to learn the required service registrations
   and provider overrides — copy their `setUp`.

2. **Write a throwaway capture test** at `test/_scratch_capture_test.dart`
   (the `_scratch_` prefix marks it disposable). Use `setUpTestGetIt` +
   `additionalSetup` for services the surface resolves through `getIt`, and
   pass provider overrides via `captureInApp(overrides: ...)`. Drive the state
   in `interaction`.

3. **Generate the PNGs:**
   ```sh
   fvm flutter test --update-goldens test/_scratch_capture_test.dart
   ```
   Images land in `test/screenshots/` (the `outputDir`, next to the test).

4. **View and share.** Read the PNGs to inspect them; send them to the user
   with `SendUserFile`.

5. **Clean up** — this is mandatory unless the user asks to keep anything:
   ```sh
   rm test/_scratch_capture_test.dart && rm -rf test/screenshots
   ```

## Example capture test

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'; // Override
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/pages/projects_tab_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import 'features/categories/test_utils.dart';
import 'features/projects/test_utils.dart';
import 'mocks/mocks.dart';
import 'test_utils/screenshot_harness.dart';
import 'widget_test_utils.dart';

void main() {
  setUpAll(loadAppFonts);

  final groups = [
    ProjectCategoryGroup(
      categoryId: 'lotti',
      category: CategoryTestUtils.createTestCategory(id: 'lotti', name: 'Lotti'),
      projects: [
        ProjectListItemData(
          project: makeTestProject(id: 'p1', title: 'Daily Operating System'),
          category: CategoryTestUtils.createTestCategory(id: 'lotti', name: 'Lotti'),
          taskRollup: const ProjectTaskRollupData(totalTaskCount: 25),
        ),
      ],
    ),
  ];

  List<Override> overrides() => [
    projectsOverviewProvider.overrideWith(
      (ref) => Stream.value(ProjectsOverviewSnapshot(groups: groups)),
    ),
    visibleProjectGroupsProvider.overrideWith((ref) => AsyncValue.data(groups)),
  ];

  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        final activity = MockUserActivityService();
        when(activity.updateActivity).thenReturn(null);
        getIt.registerSingleton<UserActivityService>(activity);

        final nav = MockNavService();
        when(() => nav.isDesktopMode).thenReturn(false);
        when(() => nav.desktopSelectedProjectId)
            .thenReturn(ValueNotifier<String?>(null));
        getIt.registerSingleton<NavService>(nav);

        final cache = MockEntitiesCacheService();
        when(() => cache.getCategoryById(any())).thenReturn(null);
        getIt.registerSingleton<EntitiesCacheService>(cache);
      },
    );
  });
  tearDown(tearDownTestGetIt);

  Future<void> openCreate(WidgetTester tester) =>
      tester.tap(find.bySemanticsLabel('New Project'));

  testWidgets('phone', (tester) async {
    await captureInApp(
      tester,
      child: const ProjectsTabPage(),
      name: 'create_mobile',
      overrides: overrides(),
      interaction: openCreate,
    );
  });

  testWidgets('desktop', (tester) async {
    await captureInApp(
      tester,
      child: const ProjectsTabPage(),
      name: 'create_desktop',
      size: ScreenshotViewport.desktop,
      overrides: overrides(),
      interaction: openCreate,
    );
  });
}
```

## Gotchas

- **`Override` lives in `package:flutter_riverpod/misc.dart`** in this Riverpod
  version — import it for the `List<Override>` type (separate from
  `flutter_riverpod.dart`, which has `AsyncValue`).
- **Register every service the surface touches** via `setUpTestGetIt`'s
  `additionalSetup`, or the widget throws on a missing `getIt` registration.
  Modals pull in their own deps (e.g. the create modal's `CategoryField` needs
  `EntitiesCacheService`).
- **Desktop layout is width-driven.** `captureInApp(size: ScreenshotViewport.desktop)`
  sets both the view physical size and `MediaQuery`, so width-gated split
  views (`isDesktopLayout`) and the dialog branch (modal page breakpoint)
  engage correctly.
- **Capture target is `find.byType(MaterialApp)`** so overlay content (modals,
  dialogs, toasts) is included, not just the page body.
- **Don't commit the scratch test or `test/screenshots/`.** Delete them when
  done. The harness itself is the only permanent artifact.
