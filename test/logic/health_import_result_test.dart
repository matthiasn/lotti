import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/logic/health_import_result.dart';

void main() {
  group('HealthImportResult constructors', () {
    test('imported carries its sample count and reads as success', () {
      const result = HealthImportResult.imported(42);

      expect(result.status, HealthImportStatus.imported);
      expect(result.sampleCount, 42);
      expect(result.error, isNull);
      expect(result.isSuccess, isTrue);
    });

    test('an import of zero samples is still a success, not a failure', () {
      // A range the health store simply has no data for must not read as
      // "something went wrong" — the page renders these differently.
      const result = HealthImportResult.imported(0);

      expect(result.isSuccess, isTrue);
      expect(result.sampleCount, 0);
    });

    test('unsupportedPlatform is not a success and counts nothing', () {
      const result = HealthImportResult.unsupportedPlatform();

      expect(result.status, HealthImportStatus.unsupportedPlatform);
      expect(result.isSuccess, isFalse);
      expect(result.sampleCount, 0);
      expect(result.error, isNull);
    });

    test('permissionDenied is not a success and counts nothing', () {
      const result = HealthImportResult.permissionDenied();

      expect(result.status, HealthImportStatus.permissionDenied);
      expect(result.isSuccess, isFalse);
      expect(result.sampleCount, 0);
    });

    test('noDataOrAccess is not a success and counts nothing', () {
      const result = HealthImportResult.noDataOrAccess();

      expect(result.status, HealthImportStatus.noDataOrAccess);
      expect(result.isSuccess, isFalse);
      expect(result.sampleCount, 0);
      expect(result.error, isNull);
    });

    test('noDataOrAccess is distinct from an empty success', () {
      // The whole reason it exists: iOS reports a switched-off data type as a
      // successful authorization followed by an empty read, which is
      // indistinguishable from an up-to-date import unless they are separate
      // outcomes.
      expect(
        const HealthImportResult.noDataOrAccess().status,
        isNot(const HealthImportResult.imported(0).status),
      );
    });

    test('noMatchingTypes is not a success and counts nothing', () {
      const result = HealthImportResult.noMatchingTypes();

      expect(result.status, HealthImportStatus.noMatchingTypes);
      expect(result.isSuccess, isFalse);
      expect(result.sampleCount, 0);
    });

    test('failed carries the thrown object and is not a success', () {
      final failure = Exception('health store exploded');
      final result = HealthImportResult.failed(failure);

      expect(result.status, HealthImportStatus.failed);
      expect(result.isSuccess, isFalse);
      expect(result.error, same(failure));
      expect(result.sampleCount, 0);
    });
  });

  group('HealthImportResult.combined', () {
    test('sums sample counts when every part succeeded', () {
      final combined = HealthImportResult.combined(const [
        HealthImportResult.imported(3),
        HealthImportResult.imported(0),
        HealthImportResult.imported(7),
      ]);

      expect(combined.isSuccess, isTrue);
      expect(combined.sampleCount, 10);
    });

    test('an empty batch is a success importing nothing', () {
      final combined = HealthImportResult.combined(const []);

      expect(combined.isSuccess, isTrue);
      expect(combined.sampleCount, 0);
    });

    test('reports the first non-success rather than a total', () {
      // The first failure is the one that explains the rest: a denied
      // authorization makes every later part fail identically, so surfacing a
      // later one would point the user at the wrong cause.
      const denied = HealthImportResult.permissionDenied();
      final combined = HealthImportResult.combined([
        const HealthImportResult.imported(5),
        denied,
        HealthImportResult.failed(Exception('later, unrelated')),
      ]);

      expect(combined, same(denied));
      expect(combined.sampleCount, 0);
    });

    test('a suspected access problem surfaces through a batch', () {
      // Import all must not bury the one category that needs attention under
      // five that worked — the page's access callout keys off this.
      const suspected = HealthImportResult.noDataOrAccess();
      final combined = HealthImportResult.combined(const [
        HealthImportResult.imported(5),
        suspected,
        HealthImportResult.imported(2),
      ]);

      expect(combined, same(suspected));
    });

    test('a single failure among successes suppresses the sum', () {
      final failure = Exception('nope');
      final combined = HealthImportResult.combined([
        HealthImportResult.failed(failure),
        const HealthImportResult.imported(9),
      ]);

      expect(combined.status, HealthImportStatus.failed);
      expect(combined.error, same(failure));
      expect(
        combined.sampleCount,
        0,
        reason: 'a partial count would overstate what was actually imported',
      );
    });
  });

  group('toString', () {
    test('names the status and the count', () {
      expect(
        const HealthImportResult.imported(3).toString(),
        'HealthImportResult(imported, samples: 3)',
      );
    });

    test('names the error type but never the error message', () {
      // The health store's exception strings can carry sample metadata; logs
      // and diagnostics take the type only.
      final result = HealthImportResult.failed(
        StateError('user-identifying detail'),
      );

      expect(result.toString(), contains('StateError'));
      expect(result.toString(), isNot(contains('user-identifying detail')));
    });
  });
}
