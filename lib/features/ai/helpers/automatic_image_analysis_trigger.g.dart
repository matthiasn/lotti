// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'automatic_image_analysis_trigger.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the automatic image analysis trigger helper.

@ProviderFor(automaticImageAnalysisTrigger)
final automaticImageAnalysisTriggerProvider =
    AutomaticImageAnalysisTriggerProvider._();

/// Provider for the automatic image analysis trigger helper.

final class AutomaticImageAnalysisTriggerProvider extends $FunctionalProvider<
        AutomaticImageAnalysisTrigger,
        AutomaticImageAnalysisTrigger,
        AutomaticImageAnalysisTrigger>
    with $Provider<AutomaticImageAnalysisTrigger> {
  /// Provider for the automatic image analysis trigger helper.
  AutomaticImageAnalysisTriggerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'automaticImageAnalysisTriggerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$automaticImageAnalysisTriggerHash();

  @$internal
  @override
  $ProviderElement<AutomaticImageAnalysisTrigger> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AutomaticImageAnalysisTrigger create(Ref ref) {
    return automaticImageAnalysisTrigger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AutomaticImageAnalysisTrigger value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<AutomaticImageAnalysisTrigger>(value),
    );
  }
}

String _$automaticImageAnalysisTriggerHash() =>
    r'37a87e5fe419127f846a61fbb5f42d5beff09b1c';
