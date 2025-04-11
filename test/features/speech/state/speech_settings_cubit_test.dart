import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/speech/state/asr_service.dart';
import 'package:lotti/features/speech/state/speech_settings_cubit.dart';
import 'package:lotti/features/speech/state/speech_settings_state.dart';
import 'package:lotti/get_it.dart';

// Create test implementations rather than mocks
class TestAsrService implements AsrService {
  String _model = '';

  @override
  String get model => _model;

  @override
  set model(String value) {
    _model = value;
  }

  @override
  final progressController =
      StreamController<(String, TranscriptionStatus)>.broadcast();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestSettingsDb implements SettingsDb {
  final Map<String, String> _items = {};

  @override
  Future<String?> itemByKey(String key) async {
    return _items[key];
  }

  @override
  Future<int> saveSettingsItem(String key, String value) async {
    _items[key] = value;
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestAsrService testAsrService;
  late TestSettingsDb testSettingsDb;

  setUp(() {
    testAsrService = TestAsrService();
    testSettingsDb = TestSettingsDb();

    // Register dependencies
    getIt
      ..registerSingleton<AsrService>(testAsrService)
      ..registerSingleton<SettingsDb>(testSettingsDb);
  });

  tearDown(() {
    // Clean up
    testAsrService.progressController.close();
    getIt.reset();
  });

  test('SpeechSettingsCubit initial state has correct available models', () {
    final cubit = SpeechSettingsCubit();
    expect(cubit.state.availableModels, equals(availableModels));
  });

  test('SpeechSettingsCubit.selectModel updates model in AsrService', () async {
    final cubit = SpeechSettingsCubit();
    await cubit.selectModel('tiny');
    expect(testAsrService.model, equals('tiny'));
  });

  test('SpeechSettingsCubit.selectModel updates state correctly', () async {
    final cubit = SpeechSettingsCubit();
    await cubit.selectModel('tiny');
    expect(cubit.state.selectedModel, equals('tiny'));
  });
}
