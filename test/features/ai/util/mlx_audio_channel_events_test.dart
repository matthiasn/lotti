import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:lotti/utils/platform.dart' as platform;

import 'mlx_audio_channel_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // MlxAudioChannel short-circuits to "unsupported" on non-macOS hosts so the
  // native bridge is never invoked from iOS / Android / Linux / Windows
  // builds. The bulk of the suite exercises the macOS path; flip the flag for
  // those tests and restore it for each so the cross-platform CI runners
  // (Linux + Windows) keep exercising the real channel behaviour.
  late bool originalIsMacOS;

  setUp(() {
    originalIsMacOS = platform.isMacOS;
    platform.isMacOS = true;
  });

  tearDown(() {
    platform.isMacOS = originalIsMacOS;
  });

  group('MlxAudioRealtimeEvent', () {
    test('maps native event type strings and optional stats fields', () {
      final cases = <String?, MlxAudioRealtimeEventType>{
        'transcription.provisional': MlxAudioRealtimeEventType.provisional,
        'transcription.confirmed': MlxAudioRealtimeEventType.confirmed,
        'transcription.display': MlxAudioRealtimeEventType.display,
        'transcription.stats': MlxAudioRealtimeEventType.stats,
        'transcription.done': MlxAudioRealtimeEventType.done,
        'transcription.error': MlxAudioRealtimeEventType.error,
        'unexpected': MlxAudioRealtimeEventType.error,
        null: MlxAudioRealtimeEventType.error,
      };

      for (final entry in cases.entries) {
        final event = MlxAudioRealtimeEvent.fromMap({
          if (entry.key != null) 'type': entry.key,
          'text': 'text',
          'confirmedText': 'confirmed',
          'provisionalText': 'provisional',
          'message': 'message',
          'encodedWindowCount': 3,
          'totalAudioSeconds': 1.5,
          'tokensPerSecond': 2.5,
          'realTimeFactor': 0.75,
          'peakMemoryGB': 4.25,
        });

        expect(event.type, entry.value);
        expect(event.text, 'text');
        expect(event.confirmedText, 'confirmed');
        expect(event.provisionalText, 'provisional');
        expect(event.message, 'message');
        expect(event.encodedWindowCount, 3);
        expect(event.totalAudioSeconds, 1.5);
        expect(event.tokensPerSecond, 2.5);
        expect(event.realTimeFactor, 0.75);
        expect(event.peakMemoryGB, 4.25);
      }
    });

    // The _typeFromString switch has a `_` catch-all mapping every unrecognized
    // type string to .error. The canonical type strings all contain a dot
    // (e.g. 'transcription.provisional'), so letterOrDigits can never produce
    // one; the guard below keeps the property correct even if that ever changes.
    glados.Glados<String>(
      glados.any.letterOrDigits,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'maps any non-canonical type string to error',
      (value) {
        const canonical = {
          'transcription.provisional',
          'transcription.confirmed',
          'transcription.display',
          'transcription.stats',
          'transcription.done',
          'transcription.error',
        };
        if (canonical.contains(value)) return;

        final event = MlxAudioRealtimeEvent.fromMap({'type': value});
        expect(
          event.type,
          MlxAudioRealtimeEventType.error,
          reason: 'unrecognized type "$value" should fall through to error',
        );
      },
      tags: 'glados',
    );
  });

  group('MlxAudioModelDownloadProgress', () {
    test('marks only retryable terminal statuses as installable', () {
      expect(
        const MlxAudioModelDownloadProgress(
          modelId: 'model-a',
          status: MlxAudioModelStatus.notInstalled,
        ).canInstall,
        isTrue,
      );
      expect(
        const MlxAudioModelDownloadProgress(
          modelId: 'model-a',
          status: MlxAudioModelStatus.failed,
        ).canInstall,
        isTrue,
      );
      expect(
        const MlxAudioModelDownloadProgress(
          modelId: 'model-a',
          status: MlxAudioModelStatus.installed,
        ).canInstall,
        isFalse,
      );
      expect(
        const MlxAudioModelDownloadProgress(
          modelId: 'model-a',
          status: MlxAudioModelStatus.downloading,
        ).canInstall,
        isFalse,
      );
      expect(
        const MlxAudioModelDownloadProgress(
          modelId: 'model-a',
          status: MlxAudioModelStatus.unsupported,
        ).canInstall,
        isFalse,
      );
    });

    test('treats zero-byte downloading events as indeterminate', () {
      final progress = MlxAudioModelDownloadProgress.fromMap({
        'modelId': 'mlx-community/example',
        'status': 'downloading',
        'progress': 0,
        'completedUnitCount': 0,
        'totalUnitCount': 0,
      });

      expect(progress.normalizedProgress, isNull);
      expect(progress.percentComplete, isNull);
      expect(progress.hasMeasuredProgress, isFalse);
    });

    test('reports zero percent when total bytes are known', () {
      final progress = MlxAudioModelDownloadProgress.fromMap({
        'modelId': 'mlx-community/example',
        'status': 'downloading',
        'progress': 0,
        'completedUnitCount': 0,
        'totalUnitCount': 8 * 1024 * 1024 * 1024,
      });

      expect(progress.normalizedProgress, 0);
      expect(progress.percentComplete, 0);
      expect(progress.hasMeasuredProgress, isTrue);
    });

    test('falls back to byte counts when native fraction is stale', () {
      final progress = MlxAudioModelDownloadProgress.fromMap({
        'modelId': 'mlx-community/example',
        'status': 'downloading',
        'progress': 0,
        'completedUnitCount': 1300,
        'totalUnitCount': 8870,
      });

      expect(progress.normalizedProgress, closeTo(0.146, 0.001));
      expect(progress.percentComplete, 14);
      expect(progress.hasMeasuredProgress, isTrue);
    });

    test('reports tiny measured byte progress without hiding it', () {
      final progress = MlxAudioModelDownloadProgress.fromMap({
        'modelId': 'mlx-community/example',
        'status': 'downloading',
        'progress': 0.004,
        'completedUnitCount': 4,
        'totalUnitCount': 1000,
      });

      expect(progress.normalizedProgress, 0.004);
      expect(progress.percentComplete, 0);
      expect(progress.hasMeasuredProgress, isTrue);
    });

    test('reports measured progress above one percent', () {
      final progress = MlxAudioModelDownloadProgress.fromMap({
        'modelId': 'mlx-community/example',
        'status': 'downloading',
        'progress': 0.024,
        'completedUnitCount': 24,
        'totalUnitCount': 1000,
      });

      expect(progress.normalizedProgress, 0.024);
      expect(progress.percentComplete, 2);
      expect(progress.hasMeasuredProgress, isTrue);
    });

    test('uses native fraction when available', () {
      final progress = MlxAudioModelDownloadProgress.fromMap({
        'modelId': 'mlx-community/example',
        'status': 'downloading',
        'progress': 0.424,
        'completedUnitCount': 424,
        'totalUnitCount': 1000,
      });

      expect(progress.normalizedProgress, 0.424);
      expect(progress.percentComplete, 42);
      expect(progress.hasMeasuredProgress, isTrue);
    });

    test('derives progress from byte counts when fraction is missing', () {
      final progress = MlxAudioModelDownloadProgress.fromMap({
        'modelId': 'mlx-community/example',
        'status': 'downloading',
        'completedUnitCount': 25,
        'totalUnitCount': 100,
      });

      expect(progress.normalizedProgress, 0.25);
      expect(progress.percentComplete, 25);
      expect(progress.hasMeasuredProgress, isTrue);
    });

    test('reports installed models as complete', () {
      final progress = MlxAudioModelDownloadProgress.fromMap({
        'modelId': 'mlx-community/example',
        'status': 'installed',
      });

      expect(progress.normalizedProgress, 1);
      expect(progress.percentComplete, 100);
      expect(progress.hasMeasuredProgress, isTrue);
    });

    test('ignores non-finite native progress fractions', () {
      for (final progressValue in [double.nan, double.infinity]) {
        final progress = MlxAudioModelDownloadProgress.fromMap({
          'modelId': 'mlx-community/example',
          'status': 'downloading',
          'progress': progressValue,
        });

        expect(progress.normalizedProgress, isNull);
        expect(progress.percentComplete, isNull);
        expect(progress.hasMeasuredProgress, isFalse);
      }
    });

    glados.Glados(
      glados.any.downloadProgressScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'normalizes generated byte and fraction progress consistently',
      (
        scenario,
      ) {
        final progress = MlxAudioModelDownloadProgress.fromMap(scenario.map);

        final expectedNormalized = scenario.expectedNormalizedProgress;
        if (expectedNormalized == null) {
          expect(progress.normalizedProgress, isNull, reason: '$scenario');
        } else {
          expect(
            progress.normalizedProgress,
            closeTo(expectedNormalized, 0.0000001),
            reason: '$scenario',
          );
        }
        expect(
          progress.percentComplete,
          scenario.expectedPercentComplete,
          reason: '$scenario',
        );
        expect(
          progress.hasMeasuredProgress,
          scenario.expectedHasMeasuredProgress,
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );
  });
}
