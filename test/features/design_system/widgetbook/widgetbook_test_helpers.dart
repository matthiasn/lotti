import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:widgetbook/widgetbook.dart';

import '../../../widget_test_utils.dart';

/// Shared preamble for the thin single-use-case widgetbook tests.
///
/// Every component in the catalogue exposes exactly one `'Overview'` use case
/// whose builder is pumped under a scaffolded [DesignSystemTheme]. This helper
/// collapses the four boilerplate lines that otherwise repeat verbatim across
/// ~20 test files (build the component, grab the single use case, assert the
/// component/use-case names, pump it) into a single call while still asserting
/// the invariants those files used to check inline.
///
/// Pass [expectedName] to assert the registered catalogue name. The optional
/// [theme] defaults to [DesignSystemTheme.light]; pass
/// [DesignSystemTheme.dark] to exercise the dark-mode path.
Future<void> pumpWidgetbookOverview(
  WidgetTester tester,
  WidgetbookComponent component, {
  required String expectedName,
  ThemeData? theme,
}) async {
  final useCase = component.useCases.single;

  expect(component.name, expectedName);
  expect(useCase.name, 'Overview');

  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      Builder(builder: useCase.builder),
      theme: theme ?? DesignSystemTheme.light(),
    ),
  );
}
