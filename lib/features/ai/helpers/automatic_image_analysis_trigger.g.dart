// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'automatic_image_analysis_trigger.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the automatic image analysis trigger helper.
///
/// Uses keepAlive to prevent disposal during async operations.
/// The trigger stores a Ref and uses it in async operations, so it must
/// remain valid throughout the inference lifecycle.

@ProviderFor(automaticImageAnalysisTrigger)
final automaticImageAnalysisTriggerProvider =
    AutomaticImageAnalysisTriggerProvider._();

/// Provider for the automatic image analysis trigger helper.
///
/// Uses keepAlive to prevent disposal during async operations.
/// The trigger stores a Ref and uses it in async operations, so it must
/// remain valid throughout the inference lifecycle.

final class AutomaticImageAnalysisTriggerProvider
    extends
        $FunctionalProvider<
          AutomaticImageAnalysisTrigger,
          AutomaticImageAnalysisTrigger,
          AutomaticImageAnalysisTrigger
        >
    with $Provider<AutomaticImageAnalysisTrigger> {
  /// Provider for the automatic image analysis trigger helper.
  ///
  /// Uses keepAlive to prevent disposal during async operations.
  /// The trigger stores a Ref and uses it in async operations, so it must
  /// remain valid throughout the inference lifecycle.
  AutomaticImageAnalysisTriggerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'automaticImageAnalysisTriggerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$automaticImageAnalysisTriggerHash();

  @$internal
  @override
  $ProviderElement<AutomaticImageAnalysisTrigger> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AutomaticImageAnalysisTrigger create(Ref ref) {
    return automaticImageAnalysisTrigger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AutomaticImageAnalysisTrigger value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AutomaticImageAnalysisTrigger>(
        value,
      ),
    );
  }
}

String _$automaticImageAnalysisTriggerHash() =>
    r'af6116353e182281e2594a4b995e25712ce47da2';
