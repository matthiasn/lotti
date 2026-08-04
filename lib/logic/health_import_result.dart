import 'package:collection/collection.dart';

/// Why a health import request ended the way it did.
///
/// Every outcome other than [imported] means nothing was written, and each one
/// needs a different response from the caller: retrying is pointless on
/// [unsupportedPlatform], the user must act on [permissionDenied], and
/// [noMatchingTypes] is a configuration defect rather than anything the user
/// can fix.
enum HealthImportStatus {
  /// The request completed. `sampleCount` may still be zero when the source
  /// simply holds no samples in the requested range — a successful import of
  /// nothing, not a failure.
  imported,

  /// The platform has no health store to read (desktop). Callers should
  /// present this as "unavailable here", never as an error.
  unsupportedPlatform,

  /// Apple Health / Health Connect refused read access for the requested
  /// types. Only the user can change this, in system settings.
  permissionDenied,

  /// None of the requested storage-type strings resolved to a health data type
  /// the plugin knows. Reaching this means a dashboard is configured for a type
  /// that no longer exists in the plugin's enum, so it is logged as a defect.
  noMatchingTypes,

  /// The health store threw. `error` carries what it threw.
  failed,
}

/// Outcome of one health import request.
///
/// The import methods on `HealthImport` return this instead of throwing, so a
/// single failing data type cannot abort a batch and the settings UI has
/// something concrete to render per category — a count, a permission prompt, or
/// an error — rather than the fire-and-forget silence it used to get.
class HealthImportResult {
  const HealthImportResult._(this.status, {this.sampleCount = 0, this.error});

  /// [sampleCount] samples were read and persisted.
  const HealthImportResult.imported(int sampleCount)
    : this._(HealthImportStatus.imported, sampleCount: sampleCount);

  /// There is no health store on this platform.
  const HealthImportResult.unsupportedPlatform()
    : this._(HealthImportStatus.unsupportedPlatform);

  /// Read access was refused.
  const HealthImportResult.permissionDenied()
    : this._(HealthImportStatus.permissionDenied);

  /// No requested type resolved to a known health data type.
  const HealthImportResult.noMatchingTypes()
    : this._(HealthImportStatus.noMatchingTypes);

  /// The health store threw [error].
  const HealthImportResult.failed(Object error)
    : this._(HealthImportStatus.failed, error: error);

  /// Sums a batch of per-category results into one.
  ///
  /// Used where one user action fans out over several requests (the settings
  /// page can run every category at once): the batch succeeds only if every
  /// part did, and otherwise reports the *first* non-success — which is the one
  /// that explains the rest, since a denied authorization or an unsupported
  /// platform makes every later part fail the same way.
  factory HealthImportResult.combined(Iterable<HealthImportResult> results) {
    final failure = results.firstWhereOrNull((result) => !result.isSuccess);
    if (failure != null) {
      return failure;
    }
    return HealthImportResult.imported(
      results.fold<int>(0, (sum, result) => sum + result.sampleCount),
    );
  }

  final HealthImportStatus status;

  /// Number of samples read from the health store and persisted. Always `0`
  /// unless [status] is [HealthImportStatus.imported].
  final int sampleCount;

  /// What the health store threw. Non-null only for
  /// [HealthImportStatus.failed].
  final Object? error;

  /// Whether the request reached the health store and completed without error.
  /// True even when [sampleCount] is zero.
  bool get isSuccess => status == HealthImportStatus.imported;

  @override
  String toString() =>
      'HealthImportResult(${status.name}, samples: $sampleCount'
      '${error == null ? '' : ', error: ${error.runtimeType}'})';
}
