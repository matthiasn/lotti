// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backfill_config_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for backfill configuration settings.
/// Allows enabling/disabling automatic backfill sync (useful on metered/slow networks).

@ProviderFor(BackfillConfigController)
final backfillConfigControllerProvider = BackfillConfigControllerProvider._();

/// Controller for backfill configuration settings.
/// Allows enabling/disabling automatic backfill sync (useful on metered/slow networks).
final class BackfillConfigControllerProvider
    extends $AsyncNotifierProvider<BackfillConfigController, bool> {
  /// Controller for backfill configuration settings.
  /// Allows enabling/disabling automatic backfill sync (useful on metered/slow networks).
  BackfillConfigControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'backfillConfigControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$backfillConfigControllerHash();

  @$internal
  @override
  BackfillConfigController create() => BackfillConfigController();
}

String _$backfillConfigControllerHash() =>
    r'a0d946f891f3e4212a1cab2504180387431fa860';

/// Controller for backfill configuration settings.
/// Allows enabling/disabling automatic backfill sync (useful on metered/slow networks).

abstract class _$BackfillConfigController extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<bool>, bool>,
        AsyncValue<bool>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
