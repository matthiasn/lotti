import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lotti/services/dev_logger.dart';

import 'flutter_test_config.dart';

void main() {
  test('resetSharedTestGlobals restores the shared test baseline', () {
    final allowFontDownloads = GoogleFonts.config.allowRuntimeFetching;

    DevLogger.log(name: 'SharedStateTest', message: 'captured');
    GoogleFonts.config.allowRuntimeFetching = !allowFontDownloads;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
    DevLogger.suppressOutput = false;
    GetIt.I.allowReassignment = true;

    resetSharedTestGlobals(allowFontDownloads: allowFontDownloads);

    expect(
      GoogleFonts.config.allowRuntimeFetching,
      allowFontDownloads,
    );
    expect(driftRuntimeOptions.dontWarnAboutMultipleDatabases, isTrue);
    expect(DevLogger.suppressOutput, isTrue);
    expect(DevLogger.capturedLogs, isEmpty);
    expect(GetIt.I.allowReassignment, isFalse);
  });
}
