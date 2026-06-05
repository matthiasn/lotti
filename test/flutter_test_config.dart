import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:mocktail/mocktail.dart';

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

  // Mocktail keeps argument matchers (`any`, `captureAny`) in PROCESS-GLOBAL
  // state between `when`/`verify` registration and the mock invocation that
  // consumes them. A matcher that is registered but never consumed (e.g. a
  // `when` whose inner call throws before reaching `noSuchMethod`) silently
  // poisons the next mock interaction — anywhere in the isolate. Under plain
  // `flutter test` each file gets a fresh isolate, so the damage is
  // contained; under very_good's test optimizer (one isolate for the whole
  // suite/shard) it can corrupt an unrelated test in a different file, with
  // the victim depending on the platform-specific bundle order. Resetting
  // between tests confines any such leak to the test that caused it.
  // Registered fallback values survive the reset by design, and per-mock
  // stubs live on the mock instances, so setUpAll-created stubs keep
  // working.
  tearDown(resetMocktailState);

  await testMain();
}
