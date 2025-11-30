// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'correction_capture_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$correctionCaptureServiceHash() =>
    r'bdbad3406c2af6b074bf2fad856c44756d2bbc51';

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
    r'b8ad78534e145b5e96632ca46cbbae7ebfa9e870';

/// Notifier for correction capture events.
/// UI can watch this to show snackbar notifications.
///
/// Copied from [CorrectionCaptureNotifier].
@ProviderFor(CorrectionCaptureNotifier)
final correctionCaptureNotifierProvider = AutoDisposeNotifierProvider<
    CorrectionCaptureNotifier, CorrectionCaptureEvent?>.internal(
  CorrectionCaptureNotifier.new,
  name: r'correctionCaptureNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$correctionCaptureNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CorrectionCaptureNotifier
    = AutoDisposeNotifier<CorrectionCaptureEvent?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
