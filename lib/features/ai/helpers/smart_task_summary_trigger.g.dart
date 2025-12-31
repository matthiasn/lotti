// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'smart_task_summary_trigger.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the smart task summary trigger.
///
/// Uses keepAlive to prevent disposal during async operations.
/// The trigger stores a Ref and uses it in async operations, so it must
/// remain valid throughout the inference lifecycle.

@ProviderFor(smartTaskSummaryTrigger)
final smartTaskSummaryTriggerProvider = SmartTaskSummaryTriggerProvider._();

/// Provider for the smart task summary trigger.
///
/// Uses keepAlive to prevent disposal during async operations.
/// The trigger stores a Ref and uses it in async operations, so it must
/// remain valid throughout the inference lifecycle.

final class SmartTaskSummaryTriggerProvider extends $FunctionalProvider<
    SmartTaskSummaryTrigger,
    SmartTaskSummaryTrigger,
    SmartTaskSummaryTrigger> with $Provider<SmartTaskSummaryTrigger> {
  /// Provider for the smart task summary trigger.
  ///
  /// Uses keepAlive to prevent disposal during async operations.
  /// The trigger stores a Ref and uses it in async operations, so it must
  /// remain valid throughout the inference lifecycle.
  SmartTaskSummaryTriggerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'smartTaskSummaryTriggerProvider',
          isAutoDispose: false,
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
    r'614d7cb6a692b179339247dc8f501df362a236d1';
