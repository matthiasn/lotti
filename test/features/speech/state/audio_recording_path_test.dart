import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/speech/state/audio_recording_path.dart';

void main() {
  group('AudioRecordingPath.forTimestamp', () {
    test('builds the per-day directory and timestamped stem', () {
      final path = AudioRecordingPath.forTimestamp(
        DateTime(2026, 2, 17, 9, 31, 4, 700),
      );

      expect(path.relativeDirectory, '/audio/2026-02-17/');
      expect(path.fileNameStem, '2026-02-17_09-31-04-700');
    });

    test('m4aFileName appends the .m4a extension to the stem', () {
      final path = AudioRecordingPath.forTimestamp(
        DateTime(2024, 12, 1, 0, 0, 5, 30),
      );

      expect(path.m4aFileName, '${path.fileNameStem}.m4a');
      expect(path.m4aFileName, endsWith('.m4a'));
    });

    test('outputPathIn joins the stem onto an absolute directory', () {
      final path = AudioRecordingPath.forTimestamp(
        DateTime(2025, 6, 13, 14, 5, 6, 9),
      );

      expect(
        path.outputPathIn('/docs/audio/2025-06-13/'),
        '/docs/audio/2025-06-13/2025-06-13_14-05-06-009',
      );
    });

    test('zero-pads single-digit calendar and clock fields', () {
      final path = AudioRecordingPath.forTimestamp(
        DateTime(2026, 1, 2, 3, 4, 5),
      );

      expect(path.relativeDirectory, '/audio/2026-01-02/');
      expect(path.fileNameStem, startsWith('2026-01-02_03-04-05'));
    });

    glados.Glados<DateTime>(
      glados.any.dateTime,
    ).test(
      'directory always nests under the /audio/ prefix and the day stem',
      (
        created,
      ) {
        final path = AudioRecordingPath.forTimestamp(created);
        final reason = 'created=$created';

        expect(
          path.relativeDirectory,
          startsWith(audioDirectoryPrefix),
          reason: reason,
        );
        expect(path.relativeDirectory, endsWith('/'), reason: reason);
        // The day component of the directory is the date prefix of the stem.
        expect(
          path.fileNameStem,
          startsWith(
            path.relativeDirectory
                .substring(audioDirectoryPrefix.length)
                .replaceAll('/', ''),
          ),
          reason: reason,
        );
        // The output path is the directory followed by the stem.
        expect(
          path.outputPathIn(path.relativeDirectory),
          '${path.relativeDirectory}${path.fileNameStem}',
          reason: reason,
        );
      },
      tags: 'glados',
    );
  });
}
