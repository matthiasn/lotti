// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outbox_state_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Stream provider watching the Matrix sync enable flag.
/// Replaces OutboxCubit's config flag watching.

@ProviderFor(outboxConnectionState)
final outboxConnectionStateProvider = OutboxConnectionStateProvider._();

/// Stream provider watching the Matrix sync enable flag.
/// Replaces OutboxCubit's config flag watching.

final class OutboxConnectionStateProvider extends $FunctionalProvider<
        AsyncValue<OutboxConnectionState>,
        OutboxConnectionState,
        Stream<OutboxConnectionState>>
    with
        $FutureModifier<OutboxConnectionState>,
        $StreamProvider<OutboxConnectionState> {
  /// Stream provider watching the Matrix sync enable flag.
  /// Replaces OutboxCubit's config flag watching.
  OutboxConnectionStateProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'outboxConnectionStateProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$outboxConnectionStateHash();

  @$internal
  @override
  $StreamProviderElement<OutboxConnectionState> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<OutboxConnectionState> create(Ref ref) {
    return outboxConnectionState(ref);
  }
}

String _$outboxConnectionStateHash() =>
    r'888d8440f2775583844ad409954e7cabf8a08e2f';

/// Stream provider for outbox pending count (for badge display).

@ProviderFor(outboxPendingCount)
final outboxPendingCountProvider = OutboxPendingCountProvider._();

/// Stream provider for outbox pending count (for badge display).

final class OutboxPendingCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// Stream provider for outbox pending count (for badge display).
  OutboxPendingCountProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'outboxPendingCountProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$outboxPendingCountHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return outboxPendingCount(ref);
  }
}

String _$outboxPendingCountHash() =>
    r'd1063a52cfb2ee4fc2c937a96f1d8f71ff2211cd';
