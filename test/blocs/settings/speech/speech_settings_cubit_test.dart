import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/settings/speech/speech_settings_cubit.dart';
import 'package:lotti/blocs/settings/speech/speech_settings_state.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/asr_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../helpers/path_provider.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/sync_config_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final mockDownloadManager = MockDownloadManager();

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

      final testModel = await File(p.join(whisperDir.path, 'ggml-tiny.bin'))
          .create(recursive: true);
      await testModel.writeAsString('foo');

      when(() => mockDownloadManager.addDownload(any(), any()))
          .thenAnswer((invocation) async {
        return null;
      });
    });

    blocTest<SpeechSettingsCubit, SpeechSettingsState>(
      'SpeechSettingsCubit test',
      build: () => SpeechSettingsCubit(
        downloadManager: mockDownloadManager,
      ),
      setUp: () {},
      act: (c) async {
        await c.downloadModel('tiny.en');
        await c.selectModel('tiny.en');
      },
      wait: defaultWait,
      expect: () => <SpeechSettingsState>[
        SpeechSettingsState(
          availableModels: availableModels,
          downloadProgress: <String, double>{
            'tiny.en': 0.0,
            'tiny': 1.0,
            'base.en': 0.0,
            'base': 0.0,
            'small.en': 0.0,
            'small': 0.0,
            'medium.en': 0.0,
            'medium': 0.0,
          },
          selectedModel: '',
        ),
        SpeechSettingsState(
          availableModels: availableModels,
          downloadProgress: <String, double>{
            'tiny.en': 0.0,
            'tiny': 1.0,
            'base.en': 0.0,
            'base': 0.0,
            'small.en': 0.0,
            'small': 0.0,
            'medium.en': 0.0,
            'medium': 0.0,
          },
          selectedModel: 'tiny.en',
        ),
      ],
      verify: (c) {
        verify(
          () => mockDownloadManager.addDownload(
            'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin',
            any(),
          ),
        ).called(1);
      },
    );
  });
}
