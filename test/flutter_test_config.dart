import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:google_fonts/google_fonts.dart';
import 'package:lotti/services/dev_logger.dart';

import 'test_utils/clipboard_test_context.dart';

/// Runs before every test file. Use this to set global test configuration
/// that keeps tests fast and deterministic across runners (flutter test,
/// very_good test, CI, etc.).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Allow opt-in font downloads locally via env var, default to hermetic.
  final allowFontDownloads =
      Platform.environment['ALLOW_FONT_DOWNLOADS']?.toLowerCase() == 'true';
  GoogleFonts.config.allowRuntimeFetching = allowFontDownloads;

  // Suppress drift multiple-database warnings when a single VM isolate
  // reuses executors across files (common with test optimizers).
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // Suppress DevLogger console output in tests by default.
  // Tests that need to verify logging can use DevLogger.capturedLogs.
  DevLogger.suppressOutput = true;

  // Bind super_clipboard's native write channels to a shared recording mock
  // context before any test runs, so the channel singletons can't bind a
  // handler-less context from whichever test happens to write first. See
  // installSharedClipboardTestContext for the full rationale.
  installSharedClipboardTestContext();

  await testMain();
}
