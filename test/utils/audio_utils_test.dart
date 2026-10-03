import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:path_provider/path_provider.dart';

import '../helpers/path_provider.dart';
import '../test_data/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioUtils Tests - ', () {
    late Directory mockDocDir;
    late JournalAudio testAudioJournal;

    setUpAll(() async {
      setFakeDocumentsPath();

      // Create a test JournalAudio with specific paths for testing
      testAudioJournal = JournalAudio(
        meta: testAudioEntry.meta,
        data: AudioData(
          dateFrom: testAudioEntry.data.dateFrom,
          dateTo: testAudioEntry.data.dateTo,
          duration: testAudioEntry.data.duration,
          audioFile: 'test-audio.aac',
          audioDirectory: '/audio/2023-01-01/',
        ),
      );
    });

    setUp(() async {
      // Reset GetIt before each test and register a fresh mockDocDir
      await getIt.reset();
      mockDocDir = await getApplicationDocumentsDirectory();
      getIt.registerSingleton<Directory>(mockDocDir);
    });

    tearDown(getIt.reset);

    test('getRelativeAudioPath returns correct path', () {
      final expectedPath =
          '${testAudioJournal.data.audioDirectory}${testAudioJournal.data.audioFile}';
      final result = AudioUtils.getRelativeAudioPath(testAudioJournal);

      expect(result, equals(expectedPath));
      expect(result, equals('/audio/2023-01-01/test-audio.aac'));
    });

    test('getAudioPath returns correct full path', () {
      final expectedPath =
          '${mockDocDir.path}${testAudioJournal.data.audioDirectory}${testAudioJournal.data.audioFile}';
      final result = AudioUtils.getAudioPath(testAudioJournal, mockDocDir);

      expect(result, equals(expectedPath));
    });

    glados.Glados(
      glados.any.generatedAudioPathScenario,
      glados.ExploreConfig(numRuns: 96),
    ).test(
      'getRelativeAudioPath concatenates generated directories and file names',
      (scenario) {
        expect(
          AudioUtils.getRelativeAudioPath(scenario.journalAudio),
          scenario.expectedRelativePath,
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.generatedAudioPathScenario,
      glados.ExploreConfig(numRuns: 96),
    ).test(
      'getAudioPath prefixes generated relative paths with documents directory',
      (scenario) {
        expect(
          AudioUtils.getAudioPath(
            scenario.journalAudio,
            Directory(scenario.documentsDirectory),
          ),
          scenario.expectedFullPath,
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );

    test('getFullAudioPath returns correct full path', () async {
      final expectedPath =
          '${mockDocDir.path}${testAudioJournal.data.audioDirectory}${testAudioJournal.data.audioFile}';
      final result = await AudioUtils.getFullAudioPath(testAudioJournal);

      expect(result, equals(expectedPath));
    });

    test(
      'getFullAudioPath degrades to the bare documents path when directory '
      'and file are empty',
      () async {
        // Empty strings are valid String values for these fields; the function
        // must concatenate them without inserting separators or throwing, so
        // the result is exactly the documents directory path.
        final emptyPathJournal = JournalAudio(
          meta: testAudioJournal.meta,
          data: AudioData(
            dateFrom: testAudioJournal.data.dateFrom,
            dateTo: testAudioJournal.data.dateTo,
            duration: testAudioJournal.data.duration,
            audioFile: '',
            audioDirectory: '',
          ),
        );

        expect(AudioUtils.getRelativeAudioPath(emptyPathJournal), isEmpty);
        expect(
          await AudioUtils.getFullAudioPath(emptyPathJournal),
          equals(mockDocDir.path),
        );
      },
    );
  });
}

enum _GeneratedAudioPathToken {
  alpha,
  numeric,
  spaced,
  dashed,
  underscored,
  percentEncoded,
}

class _GeneratedAudioPathScenario {
  const _GeneratedAudioPathScenario({
    required this.directoryParts,
    required this.fileStem,
    required this.extension,
    required this.documentsParts,
  });

  final List<_GeneratedAudioPathToken> directoryParts;
  final _GeneratedAudioPathToken fileStem;
  final _GeneratedAudioPathToken extension;
  final List<_GeneratedAudioPathToken> documentsParts;

  String get audioDirectory => '${_joinAudioPath(directoryParts)}/';

  String get audioFile => '${fileStem.text}.${extension.text}';

  String get documentsDirectory =>
      '/Users/test/Documents${_joinAudioPath(documentsParts)}';

  String get expectedRelativePath => '$audioDirectory$audioFile';

  String get expectedFullPath => '$documentsDirectory$expectedRelativePath';

  JournalAudio get journalAudio {
    final testDate = DateTime(2024, 3, 15, 10, 30);
    return JournalAudio(
      meta: Metadata(
        id: 'generated-audio',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      ),
      data: AudioData(
        dateFrom: testDate,
        dateTo: testDate,
        duration: Duration(seconds: directoryParts.length + 1),
        audioFile: audioFile,
        audioDirectory: audioDirectory,
      ),
    );
  }

  @override
  String toString() {
    return '_GeneratedAudioPathScenario('
        'audioDirectory: $audioDirectory, '
        'audioFile: $audioFile, '
        'documentsDirectory: $documentsDirectory)';
  }
}

String _joinAudioPath(List<_GeneratedAudioPathToken> parts) {
  if (parts.isEmpty) {
    return '';
  }
  return '/${parts.map((part) => part.text).join('/')}';
}

extension on _GeneratedAudioPathToken {
  String get text => switch (this) {
    _GeneratedAudioPathToken.alpha => 'alpha',
    _GeneratedAudioPathToken.numeric => '2024',
    _GeneratedAudioPathToken.spaced => 'file name',
    _GeneratedAudioPathToken.dashed => 'dash-name',
    _GeneratedAudioPathToken.underscored => 'under_score',
    _GeneratedAudioPathToken.percentEncoded => 'hello%20world',
  };
}

extension _AnyAudioUtils on glados.Any {
  glados.Generator<_GeneratedAudioPathToken> get _audioPathToken =>
      glados.AnyUtils(this).choose(_GeneratedAudioPathToken.values);

  glados.Generator<List<_GeneratedAudioPathToken>> get _audioPathParts =>
      glados.ListAnys(this).listWithLengthInRange(0, 4, _audioPathToken);

  glados.Generator<_GeneratedAudioPathScenario>
  get generatedAudioPathScenario => glados.CombinableAny(this).combine4(
    _audioPathParts,
    _audioPathToken,
    _audioPathToken,
    _audioPathParts,
    (
      List<_GeneratedAudioPathToken> directoryParts,
      _GeneratedAudioPathToken fileStem,
      _GeneratedAudioPathToken extension,
      List<_GeneratedAudioPathToken> documentsParts,
    ) => _GeneratedAudioPathScenario(
      directoryParts: directoryParts,
      fileStem: fileStem,
      extension: extension,
      documentsParts: documentsParts,
    ),
  );
}
