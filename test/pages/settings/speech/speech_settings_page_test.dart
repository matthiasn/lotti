import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/speech/state/asr_service.dart';
import 'package:lotti/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../helpers/path_provider.dart';
import '../../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsPage Widget Tests - ', () {
    setUpAll(() async {
      setFakeDocumentsPath();
      final docDir = await getApplicationDocumentsDirectory();
      final settingsDb = SettingsDb(inMemoryDatabase: true);

      getIt
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<LoggingDb>(MockLoggingDb())
        ..registerSingleton<Directory>(docDir)
        ..registerSingleton<AsrService>(MockAsrService());

      final whisperDir = await Directory(p.join(docDir.path, 'whisper'))
          .create(recursive: true);

      final testModel = await File(p.join(whisperDir.path, 'ggml-tiny.bin'))
          .create(recursive: true);
      await testModel.writeAsString('foo');
    });

    tearDown(getIt.reset);

    // testWidgets('Available models are displayed', (tester) async {
    //   await tester.pumpWidget(
    //     makeTestableWidget(
    //       ConstrainedBox(
    //         constraints: const BoxConstraints(
    //           maxHeight: 1000,
    //           maxWidth: 1000,
    //         ),
    //         child: const SpeechSettingsPage(),
    //       ),
    //     ),
    //   );
    //
    //   await tester.pumpAndSettle();
    //
    //   expect(find.text('tiny'), findsOneWidget);
    //   expect(find.text('tiny.en'), findsOneWidget);
    //
    //   final tinyDownloadButton = find.bySemanticsLabel('download tiny');
    //   expect(tinyDownloadButton, findsOneWidget);
    //   await tester.tap(tinyDownloadButton);
    //   await tester.pumpAndSettle();
    //
    //   final tinyEnDownloadButton = find.bySemanticsLabel('download tiny.en');
    //   expect(tinyEnDownloadButton, findsOneWidget);
    //   await tester.tap(tinyEnDownloadButton);
    //   await tester.pumpAndSettle();
    //
    //   final baseDownloadButton = find.bySemanticsLabel('download base');
    //   expect(baseDownloadButton, findsOneWidget);
    //   await tester.tap(baseDownloadButton);
    //   await tester.pumpAndSettle();
    //
    //   final baseEnDownloadButton = find.bySemanticsLabel('download base.en');
    //   expect(baseEnDownloadButton, findsOneWidget);
    //   await tester.tap(baseEnDownloadButton);
    //   await tester.pumpAndSettle();
    //
    //   final smallDownloadButton = find.bySemanticsLabel('download small');
    //   expect(smallDownloadButton, findsOneWidget);
    //   await tester.tap(smallDownloadButton);
    //   await tester.pumpAndSettle();
    //
    //   final smallEnDownloadButton = find.bySemanticsLabel('download small.en');
    //   expect(smallEnDownloadButton, findsOneWidget);
    //   await tester.tap(smallEnDownloadButton);
    //   await tester.pumpAndSettle();
    //
    //   final mediumEnDownloadButton =
    //       find.bySemanticsLabel('download medium.en');
    //   expect(mediumEnDownloadButton, findsOneWidget);
    //   await tester.tap(mediumEnDownloadButton);
    //   await tester.pumpAndSettle();
    // });
  });
}
