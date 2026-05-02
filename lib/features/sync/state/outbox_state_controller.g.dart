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

final class OutboxConnectionStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<OutboxConnectionState>,
          OutboxConnectionState,
          Stream<OutboxConnectionState>
        >
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
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

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

/// Future provider for daily outbox volume over the last [kOutboxVolumeDays].
/// Maps [OutboxDailyVolume] entries to [Observation]s with KB values.

@ProviderFor(outboxDailyVolume)
final outboxDailyVolumeProvider = OutboxDailyVolumeProvider._();

/// Future provider for daily outbox volume over the last [kOutboxVolumeDays].
/// Maps [OutboxDailyVolume] entries to [Observation]s with KB values.

final class OutboxDailyVolumeProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Observation>>,
          List<Observation>,
          FutureOr<List<Observation>>
        >
    with
        $FutureModifier<List<Observation>>,
        $FutureProvider<List<Observation>> {
  /// Future provider for daily outbox volume over the last [kOutboxVolumeDays].
  /// Maps [OutboxDailyVolume] entries to [Observation]s with KB values.
  OutboxDailyVolumeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'outboxDailyVolumeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$outboxDailyVolumeHash();

  @$internal
  @override
  $FutureProviderElement<List<Observation>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Observation>> create(Ref ref) {
    return outboxDailyVolume(ref);
  }
}

String _$outboxDailyVolumeHash() => r'4b860d94f32e31ae0ac6377ddb62e63baf8a55bc';

/// Looks up the global [SyncActivitySignaler]. Resolved through `getIt`
/// so tests that swap in a custom signaler do not need a parallel
/// override in every consumer.

@ProviderFor(syncActivitySignaler)
final syncActivitySignalerProvider = SyncActivitySignalerProvider._();

/// Looks up the global [SyncActivitySignaler]. Resolved through `getIt`
/// so tests that swap in a custom signaler do not need a parallel
/// override in every consumer.

final class SyncActivitySignalerProvider
    extends
        $FunctionalProvider<
          SyncActivitySignaler,
          SyncActivitySignaler,
          SyncActivitySignaler
        >
    with $Provider<SyncActivitySignaler> {
  /// Looks up the global [SyncActivitySignaler]. Resolved through `getIt`
  /// so tests that swap in a custom signaler do not need a parallel
  /// override in every consumer.
  SyncActivitySignalerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncActivitySignalerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncActivitySignalerHash();

  @$internal
  @override
  $ProviderElement<SyncActivitySignaler> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncActivitySignaler create(Ref ref) {
    return syncActivitySignaler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncActivitySignaler value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncActivitySignaler>(value),
    );
  }
}

String _$syncActivitySignalerHash() =>
    r'fe8cc1cd49a6214320ad6ad4b946879cba7f7b42';

/// Per-packet TX pulses for the sidebar sync activity indicator. Emits
/// once per outbound event committed to the homeserver.

@ProviderFor(syncActivityTxPulses)
final syncActivityTxPulsesProvider = SyncActivityTxPulsesProvider._();

/// Per-packet TX pulses for the sidebar sync activity indicator. Emits
/// once per outbound event committed to the homeserver.

final class SyncActivityTxPulsesProvider
    extends
        $FunctionalProvider<AsyncValue<DateTime>, DateTime, Stream<DateTime>>
    with $FutureModifier<DateTime>, $StreamProvider<DateTime> {
  /// Per-packet TX pulses for the sidebar sync activity indicator. Emits
  /// once per outbound event committed to the homeserver.
  SyncActivityTxPulsesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncActivityTxPulsesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncActivityTxPulsesHash();

  @$internal
  @override
  $StreamProviderElement<DateTime> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<DateTime> create(Ref ref) {
    return syncActivityTxPulses(ref);
  }
}

String _$syncActivityTxPulsesHash() =>
    r'7692edbba85b9f0705b31c6d74dd809c48c94eb8';

/// Per-packet RX pulses for the sidebar sync activity indicator. Emits
/// once per inbound event applied locally.

@ProviderFor(syncActivityRxPulses)
final syncActivityRxPulsesProvider = SyncActivityRxPulsesProvider._();

/// Per-packet RX pulses for the sidebar sync activity indicator. Emits
/// once per inbound event applied locally.

final class SyncActivityRxPulsesProvider
    extends
        $FunctionalProvider<AsyncValue<DateTime>, DateTime, Stream<DateTime>>
    with $FutureModifier<DateTime>, $StreamProvider<DateTime> {
  /// Per-packet RX pulses for the sidebar sync activity indicator. Emits
  /// once per inbound event applied locally.
  SyncActivityRxPulsesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncActivityRxPulsesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncActivityRxPulsesHash();

  @$internal
  @override
  $StreamProviderElement<DateTime> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<DateTime> create(Ref ref) {
    return syncActivityRxPulses(ref);
  }
}

String _$syncActivityRxPulsesHash() =>
    r'd177376085ba2f61b55a117e7e0b24e14e140d92';

/// Live depth of the inbound queue (active rows the worker can still
/// drain). Used by the sidebar sync activity indicator. Resolves the
/// queue lazily via `MatrixService.queueCoordinator` because the
/// coordinator is created during app boot, not during provider
/// construction.

@ProviderFor(inboundQueueDepth)
final inboundQueueDepthProvider = InboundQueueDepthProvider._();

/// Live depth of the inbound queue (active rows the worker can still
/// drain). Used by the sidebar sync activity indicator. Resolves the
/// queue lazily via `MatrixService.queueCoordinator` because the
/// coordinator is created during app boot, not during provider
/// construction.

final class InboundQueueDepthProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// Live depth of the inbound queue (active rows the worker can still
  /// drain). Used by the sidebar sync activity indicator. Resolves the
  /// queue lazily via `MatrixService.queueCoordinator` because the
  /// coordinator is created during app boot, not during provider
  /// construction.
  InboundQueueDepthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inboundQueueDepthProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inboundQueueDepthHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return inboundQueueDepth(ref);
  }
}

String _$inboundQueueDepthHash() => r'6fba40d4284e5aabc28e5752f2bff2d5b3be3955';
