// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'correction_capture_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the correction capture service.

@ProviderFor(correctionCaptureService)
final correctionCaptureServiceProvider = CorrectionCaptureServiceProvider._();

/// Provider for the correction capture service.

final class CorrectionCaptureServiceProvider extends $FunctionalProvider<
    CorrectionCaptureService,
    CorrectionCaptureService,
    CorrectionCaptureService> with $Provider<CorrectionCaptureService> {
  /// Provider for the correction capture service.
  CorrectionCaptureServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'correctionCaptureServiceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$correctionCaptureServiceHash();

  @$internal
  @override
  $ProviderElement<CorrectionCaptureService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CorrectionCaptureService create(Ref ref) {
    return correctionCaptureService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CorrectionCaptureService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CorrectionCaptureService>(value),
    );
  }
}

String _$correctionCaptureServiceHash() =>
    r'191c9a63ec23ef60d5cad940d5440f5ca5a9160a';

/// Notifier for pending correction with countdown.
/// UI watches this to show the snackbar with undo functionality.

@ProviderFor(CorrectionCaptureNotifier)
final correctionCaptureProvider = CorrectionCaptureNotifierProvider._();

/// Notifier for pending correction with countdown.
/// UI watches this to show the snackbar with undo functionality.
final class CorrectionCaptureNotifierProvider
    extends $NotifierProvider<CorrectionCaptureNotifier, PendingCorrection?> {
  /// Notifier for pending correction with countdown.
  /// UI watches this to show the snackbar with undo functionality.
  CorrectionCaptureNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'correctionCaptureProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$correctionCaptureNotifierHash();

  @$internal
  @override
  CorrectionCaptureNotifier create() => CorrectionCaptureNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PendingCorrection? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PendingCorrection?>(value),
    );
  }
}

String _$correctionCaptureNotifierHash() =>
    r'ed14d115ddb7914c2e4594fffdeb3ba2277d54d7';

/// Notifier for pending correction with countdown.
/// UI watches this to show the snackbar with undo functionality.

abstract class _$CorrectionCaptureNotifier
    extends $Notifier<PendingCorrection?> {
  PendingCorrection? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<PendingCorrection?, PendingCorrection?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<PendingCorrection?, PendingCorrection?>,
        PendingCorrection?,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
