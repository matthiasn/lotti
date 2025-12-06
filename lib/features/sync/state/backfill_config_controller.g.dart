// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backfill_config_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$backfillConfigControllerHash() =>
    r'2ee1f1aa7736aa7d67f96120b59e188f951192a3';

/// Controller for backfill configuration settings.
/// Allows enabling/disabling automatic backfill sync (useful on metered/slow networks).
///
/// Copied from [BackfillConfigController].
@ProviderFor(BackfillConfigController)
final backfillConfigControllerProvider =
    AutoDisposeAsyncNotifierProvider<BackfillConfigController, bool>.internal(
  BackfillConfigController.new,
  name: r'backfillConfigControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$backfillConfigControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$BackfillConfigController = AutoDisposeAsyncNotifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
