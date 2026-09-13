import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Lays the test view out at [size] in logical pixels, restoring the default
/// surface afterwards.
///
/// Shared app hosts read this viewport when no device fixture is supplied.
/// Their explicit `mediaQueryData` fixtures already configure both MediaQuery
/// and the render viewport; this helper also works with custom app hosts.
void setTestSurfaceSize(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}
