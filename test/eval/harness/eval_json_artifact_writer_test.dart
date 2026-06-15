import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'eval_json_artifact_writer.dart';

void main() {
  test('refuses existing files unless overwrite is enabled', () {
    final tempDir = Directory.systemTemp.createTempSync(
      'lotti-eval-json-writer-',
    );
    try {
      final output = File('${tempDir.path}/artifact.json')
        ..writeAsStringSync('{"old":true}\n');

      final overwriteMatcher = throwsA(
        isA<StateError>()
            .having(
              (error) => error.toString(),
              'message',
              contains('Refusing to overwrite existing test artifact'),
            )
            .having(
              (error) => error.toString(),
              'message',
              isNot(contains(output.path)),
            ),
      );

      expect(
        () => writeEvalJsonArtifact(
          const <String, dynamic>{'new': true},
          path: output.path,
          overwrite: false,
          description: 'test artifact',
        ),
        overwriteMatcher,
      );

      writeEvalJsonArtifact(
        const <String, dynamic>{'new': true},
        path: output.path,
        overwrite: true,
        description: 'test artifact',
      );

      expect(jsonDecode(output.readAsStringSync()), {'new': true});
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
    'refuses symlink outputs',
    () {
      final tempDir = Directory.systemTemp.createTempSync(
        'lotti-eval-json-writer-link-',
      );
      try {
        final target = File('${tempDir.path}/target.json')
          ..writeAsStringSync('{"old":true}\n');
        final link = Link('${tempDir.path}/artifact-link.json')
          ..createSync(target.path);

        expect(
          () => writeEvalJsonArtifact(
            const <String, dynamic>{'new': true},
            path: link.path,
            overwrite: true,
            description: 'test artifact',
          ),
          throwsA(
            isA<StateError>()
                .having(
                  (error) => error.toString(),
                  'message',
                  contains('Refusing to write test artifact to symlink'),
                )
                .having(
                  (error) => error.toString(),
                  'message',
                  isNot(contains(link.path)),
                ),
          ),
        );
        expect(jsonDecode(target.readAsStringSync()), {'old': true});
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    },
    skip: Platform.isWindows
        ? 'Symlink creation needs Windows privileges.'
        : false,
  );
}
