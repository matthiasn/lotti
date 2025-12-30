// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outbox_state_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$outboxConnectionStateHash() =>
    r'888d8440f2775583844ad409954e7cabf8a08e2f';

/// Stream provider watching the Matrix sync enable flag.
/// Replaces OutboxCubit's config flag watching.
///
/// Copied from [outboxConnectionState].
@ProviderFor(outboxConnectionState)
final outboxConnectionStateProvider =
    AutoDisposeStreamProvider<OutboxConnectionState>.internal(
  outboxConnectionState,
  name: r'outboxConnectionStateProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$outboxConnectionStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OutboxConnectionStateRef
    = AutoDisposeStreamProviderRef<OutboxConnectionState>;
String _$outboxPendingCountHash() =>
    r'd1063a52cfb2ee4fc2c937a96f1d8f71ff2211cd';

/// Stream provider for outbox pending count (for badge display).
///
/// Copied from [outboxPendingCount].
@ProviderFor(outboxPendingCount)
final outboxPendingCountProvider = AutoDisposeStreamProvider<int>.internal(
  outboxPendingCount,
  name: r'outboxPendingCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$outboxPendingCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OutboxPendingCountRef = AutoDisposeStreamProviderRef<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
