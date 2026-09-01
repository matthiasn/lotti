import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';

/// The painted surface of the [SettingsPageHeader] on screen — the outermost
/// [DecoratedBox] the sliver wraps around its content — as the decoration it
/// currently carries.
///
/// The header's own tests and the pages that host it both read this back:
/// the surface colour is the one theme-dependent value the header paints
/// itself, so it is where a stale theme shows first. Only this helper knows
/// that the surface is a `DecoratedBox`; if the header's structure changes,
/// this is the one place to follow it.
BoxDecoration settingsHeaderSurface(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(SettingsPageHeader),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return box.decoration as BoxDecoration;
}
