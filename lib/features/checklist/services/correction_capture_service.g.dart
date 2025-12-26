// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'correction_capture_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$correctionCaptureServiceHash() =>
    r'd71f1420b5b44651f64a81c3bde4a783701f4886';

/// Provider for the correction capture service.
///
/// Copied from [correctionCaptureService].
@ProviderFor(correctionCaptureService)
final correctionCaptureServiceProvider =
    AutoDisposeProvider<CorrectionCaptureService>.internal(
  correctionCaptureService,
  name: r'correctionCaptureServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$correctionCaptureServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CorrectionCaptureServiceRef
    = AutoDisposeProviderRef<CorrectionCaptureService>;
String _$correctionCaptureNotifierHash() =>
    r'ed14d115ddb7914c2e4594fffdeb3ba2277d54d7';

/// Notifier for pending correction with countdown.
/// UI watches this to show the snackbar with undo functionality.
///
/// Copied from [CorrectionCaptureNotifier].
@ProviderFor(CorrectionCaptureNotifier)
final correctionCaptureNotifierProvider = AutoDisposeNotifierProvider<
    CorrectionCaptureNotifier, PendingCorrection?>.internal(
  CorrectionCaptureNotifier.new,
  name: r'correctionCaptureNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$correctionCaptureNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CorrectionCaptureNotifier = AutoDisposeNotifier<PendingCorrection?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
