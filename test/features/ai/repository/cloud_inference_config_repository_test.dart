import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/cloud_inference_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_config_repository.dart';
import 'package:path/path.dart';

void main() {
  late Directory tempDir;
  late File configFile;
  late CloudInferenceConfigRepository repository;

  setUp(() async {
    // Create a temporary directory
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    tempDir = Directory('/tmp/cloud_inference_test_$timestamp');
    await tempDir.create(recursive: true);

    // Create the config file
    configFile = File(join(tempDir.path, 'cloud_inference_config.json'));

    // Initialize the repository with the temp directory
    repository = CloudInferenceConfigRepository(tempDir);
  });

  tearDown(() async {
    // Clean up the temporary directory
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('getConfig returns properly parsed CloudInferenceConfig', () async {
    // Prepare test data
    final testConfig = {
      'baseUrl': 'https://test-api.example.com',
      'apiKey': 'test-api-key-123',
      'geminiApiKey': 'test-gemini-key-456',
    };

    // Write test config to file
    await configFile.writeAsString(jsonEncode(testConfig));

    // Call the method under test
    final result = await repository.getConfig();

    // Verify results
    expect(result, isA<CloudInferenceConfig>());
    expect(result.baseUrl, testConfig['baseUrl']);
    expect(result.apiKey, testConfig['apiKey']);
    expect(result.geminiApiKey, testConfig['geminiApiKey']);
  });

  test('throws when config file is missing', () async {
    // Delete the config file to simulate missing file
    if (configFile.existsSync()) {
      configFile.deleteSync();
    }

    // Expect an exception when trying to read the missing file
    expect(
      () => repository.getConfig(),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('throws when config file contains invalid JSON', () async {
    // Write invalid JSON to the config file
    await configFile.writeAsString('{ invalid json }');

    // Expect a FormatException when parsing invalid JSON
    expect(
      () => repository.getConfig(),
      throwsA(isA<FormatException>()),
    );
  });
}
