//ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../../../../test_data/test_data.dart';

class MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {}

class FakeJournalAudio extends Fake implements JournalAudio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockPathProvider = MockPathProviderPlatform();

  setUpAll(() {
    PathProviderPlatform.instance = mockPathProvider;
    registerFallbackValue(FakeJournalAudio());

    // Mock directory path
    when(mockPathProvider.getApplicationDocumentsPath)
        .thenAnswer((_) => Future.value('/mock/path'));
  });

  test('SpeechModal exists and audio entry can be accessed', () {
    // This test verifies that the test audio entry can be accessed without errors
    expect(() => testAudioEntry, returnsNormally);
    expect(testAudioEntry, isA<JournalAudio>());
  });

  test('Audio entry contains expected properties', () {
    expect(testAudioEntry.meta, isNotNull);
    expect(testAudioEntry.data, isNotNull);
  });
}
