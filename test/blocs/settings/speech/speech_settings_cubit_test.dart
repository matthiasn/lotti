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

  group('SpeechSettingsCubit Tests - ', () {
    setUpAll(() async {
      setFakeDocumentsPath();
      final docDir = await getApplicationDocumentsDirectory();
      final settingsDb = SettingsDb(inMemoryDatabase: true);

      getIt
        ..registerSingleton<LoggingDb>(MockLoggingDb())
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<Directory>(docDir)
        ..registerSingleton<AsrService>(MockAsrService());

      final whisperDir = await Directory(p.join(docDir.path, 'whisper'))
          .create(recursive: true);

      final testModel = await File(p.join(whisperDir.path, 'ggml-small.bin'))
          .create(recursive: true);
      await testModel.writeAsString('foo');
    });

    /*
    blocTest<SpeechSettingsCubit, SpeechSettingsState>(
      'SpeechSettingsCubit test',
      build: () => SpeechSettingsCubit(
        downloadManager: mockDownloadManager,
      ),
      setUp: () {},
      act: (c) async {
        await c.downloadModel('small');
        await c.selectModel('small');
      },
      wait: defaultWait,
      expect: () => <SpeechSettingsState>[
        SpeechSettingsState(
          availableModels: availableModels,
          downloadProgress: <String, double>{
            'large-v3': 0.0,
            'large-v2_949MB': 0.0,
            'distil-large-v3_594MB': 0.0,
            'distil-large-v3_turbo_600MB': 0.0,
            'small': 1.0,
          },
          downloadedModelSizes: <String, double>{
            'small': 0.00000286102294921875,
          },
          selectedModel: '',
        ),
        SpeechSettingsState(
          availableModels: availableModels,
          downloadProgress: <String, double>{
            'large-v3': 0.0,
            'large-v2_949MB': 0.0,
            'distil-large-v3_594MB': 0.0,
            'distil-large-v3_turbo_600MB': 0.0,
            'small': 1.0,
          },
          downloadedModelSizes: <String, double>{
            'small': 0.00000286102294921875,
          },
          selectedModel: 'small',
        ),
      ],
      verify: (c) {
        verify(
          () => mockDownloadManager.addDownload(
            'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin',
            any(),
          ),
        ).called(1);
      },
    );
    */
  });
}
