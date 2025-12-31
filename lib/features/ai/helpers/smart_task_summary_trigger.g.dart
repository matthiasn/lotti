// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'smart_task_summary_trigger.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the smart task summary trigger.

@ProviderFor(smartTaskSummaryTrigger)
final smartTaskSummaryTriggerProvider = SmartTaskSummaryTriggerProvider._();

/// Provider for the smart task summary trigger.

final class SmartTaskSummaryTriggerProvider extends $FunctionalProvider<
    SmartTaskSummaryTrigger,
    SmartTaskSummaryTrigger,
    SmartTaskSummaryTrigger> with $Provider<SmartTaskSummaryTrigger> {
  /// Provider for the smart task summary trigger.
  SmartTaskSummaryTriggerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'smartTaskSummaryTriggerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$smartTaskSummaryTriggerHash();

  @$internal
  @override
  $ProviderElement<SmartTaskSummaryTrigger> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SmartTaskSummaryTrigger create(Ref ref) {
    return smartTaskSummaryTrigger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SmartTaskSummaryTrigger value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SmartTaskSummaryTrigger>(value),
    );
  }
}

String _$smartTaskSummaryTriggerHash() =>
    r'49172b201584ca70f5f32c6770a6c2815baa416b';
