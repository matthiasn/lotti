// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ftue_trigger_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Service that determines whether FTUE setup should be triggered for a provider.
///
/// This service encapsulates the logic for deciding when to show the FTUE setup
/// dialog, making it independently testable from the UI layer.

@ProviderFor(FtueTriggerService)
final ftueTriggerServiceProvider = FtueTriggerServiceProvider._();

/// Service that determines whether FTUE setup should be triggered for a provider.
///
/// This service encapsulates the logic for deciding when to show the FTUE setup
/// dialog, making it independently testable from the UI layer.
final class FtueTriggerServiceProvider
    extends $AsyncNotifierProvider<FtueTriggerService, void> {
  /// Service that determines whether FTUE setup should be triggered for a provider.
  ///
  /// This service encapsulates the logic for deciding when to show the FTUE setup
  /// dialog, making it independently testable from the UI layer.
  FtueTriggerServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'ftueTriggerServiceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$ftueTriggerServiceHash();

  @$internal
  @override
  FtueTriggerService create() => FtueTriggerService();
}

String _$ftueTriggerServiceHash() =>
    r'ccb79efa62e3cea61c38841755f1a282db0003cf';

/// Service that determines whether FTUE setup should be triggered for a provider.
///
/// This service encapsulates the logic for deciding when to show the FTUE setup
/// dialog, making it independently testable from the UI layer.

abstract class _$FtueTriggerService extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<void>, void>,
        AsyncValue<void>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
