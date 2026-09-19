import 'package:integration_test/integration_test_driver.dart';

/// Driver for the tutorial-video harness (`integration_test/tutorial/`).
///
/// `flutter drive` (unlike `flutter test`) launches the REAL desktop app
/// window, which the tutorial workbench records from the Xvfb display —
/// see `tools/tutorial_videos/`. The App Preview walk
/// (`integration_test/store_preview_test.dart`) runs through it too: a
/// recorded walk hands the driver no screenshots.
Future<void> main() => integrationDriver();
