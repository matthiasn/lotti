// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'synced_audio_inference_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Live, sorted list of known peer node profiles plus the local node's own
/// snapshot.
///
/// Emits the current directory immediately, then forwards every directory
/// change from `SyncNodeProfileRepository.watchKnownNodes()`. Consumers
/// (the pinning selector, the sync-node settings page) listen here to see
/// remote-published profiles arrive without manual refresh.

@ProviderFor(knownSyncNodes)
final knownSyncNodesProvider = KnownSyncNodesProvider._();

/// Live, sorted list of known peer node profiles plus the local node's own
/// snapshot.
///
/// Emits the current directory immediately, then forwards every directory
/// change from `SyncNodeProfileRepository.watchKnownNodes()`. Consumers
/// (the pinning selector, the sync-node settings page) listen here to see
/// remote-published profiles arrive without manual refresh.

final class KnownSyncNodesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SyncNodeProfile>>,
          List<SyncNodeProfile>,
          Stream<List<SyncNodeProfile>>
        >
    with
        $FutureModifier<List<SyncNodeProfile>>,
        $StreamProvider<List<SyncNodeProfile>> {
  /// Live, sorted list of known peer node profiles plus the local node's own
  /// snapshot.
  ///
  /// Emits the current directory immediately, then forwards every directory
  /// change from `SyncNodeProfileRepository.watchKnownNodes()`. Consumers
  /// (the pinning selector, the sync-node settings page) listen here to see
  /// remote-published profiles arrive without manual refresh.
  KnownSyncNodesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'knownSyncNodesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$knownSyncNodesHash();

  @$internal
  @override
  $StreamProviderElement<List<SyncNodeProfile>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SyncNodeProfile>> create(Ref ref) {
    return knownSyncNodes(ref);
  }
}

String _$knownSyncNodesHash() => r'de53481f24351d80f593f21a8937f32ae4b315b9';

/// The local node's currently-persisted self profile, refreshed on every
/// directory change (covers display-name edits + capability re-probes).

@ProviderFor(localSyncNodeSelf)
final localSyncNodeSelfProvider = LocalSyncNodeSelfProvider._();

/// The local node's currently-persisted self profile, refreshed on every
/// directory change (covers display-name edits + capability re-probes).

final class LocalSyncNodeSelfProvider
    extends
        $FunctionalProvider<
          AsyncValue<SyncNodeProfile?>,
          SyncNodeProfile?,
          Stream<SyncNodeProfile?>
        >
    with $FutureModifier<SyncNodeProfile?>, $StreamProvider<SyncNodeProfile?> {
  /// The local node's currently-persisted self profile, refreshed on every
  /// directory change (covers display-name edits + capability re-probes).
  LocalSyncNodeSelfProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localSyncNodeSelfProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localSyncNodeSelfHash();

  @$internal
  @override
  $StreamProviderElement<SyncNodeProfile?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<SyncNodeProfile?> create(Ref ref) {
    return localSyncNodeSelf(ref);
  }
}

String _$localSyncNodeSelfHash() => r'428b79f4766522564af79f52c85d6b8aa6558dff';

/// Provides the [SyncedAudioInferenceDispatcher] that decides whether this node
/// should run AI inference on audio that arrived via sync. `keepAlive` so it
/// shares the listener's lifetime; wires it to the journal DB, vector-clock
/// service, profile resolvers, and the inference/wake machinery.

@ProviderFor(syncedAudioInferenceDispatcher)
final syncedAudioInferenceDispatcherProvider =
    SyncedAudioInferenceDispatcherProvider._();

/// Provides the [SyncedAudioInferenceDispatcher] that decides whether this node
/// should run AI inference on audio that arrived via sync. `keepAlive` so it
/// shares the listener's lifetime; wires it to the journal DB, vector-clock
/// service, profile resolvers, and the inference/wake machinery.

final class SyncedAudioInferenceDispatcherProvider
    extends
        $FunctionalProvider<
          SyncedAudioInferenceDispatcher,
          SyncedAudioInferenceDispatcher,
          SyncedAudioInferenceDispatcher
        >
    with $Provider<SyncedAudioInferenceDispatcher> {
  /// Provides the [SyncedAudioInferenceDispatcher] that decides whether this node
  /// should run AI inference on audio that arrived via sync. `keepAlive` so it
  /// shares the listener's lifetime; wires it to the journal DB, vector-clock
  /// service, profile resolvers, and the inference/wake machinery.
  SyncedAudioInferenceDispatcherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncedAudioInferenceDispatcherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncedAudioInferenceDispatcherHash();

  @$internal
  @override
  $ProviderElement<SyncedAudioInferenceDispatcher> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncedAudioInferenceDispatcher create(Ref ref) {
    return syncedAudioInferenceDispatcher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncedAudioInferenceDispatcher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncedAudioInferenceDispatcher>(
        value,
      ),
    );
  }
}

String _$syncedAudioInferenceDispatcherHash() =>
    r'2da559f05ff1818a06292fc77bc58d3f9079deaa';

/// Eagerly-constructed sync-only listener.
///
/// Watching this provider from `MyBeamerApp` calls `start()` so the
/// dispatcher fires on every `fromSync: true` batch from
/// `UpdateNotifications.syncUpdateStream`. The provider is `keepAlive` —
/// the subscription must survive the entire app lifetime.

@ProviderFor(syncedAudioInferenceListener)
final syncedAudioInferenceListenerProvider =
    SyncedAudioInferenceListenerProvider._();

/// Eagerly-constructed sync-only listener.
///
/// Watching this provider from `MyBeamerApp` calls `start()` so the
/// dispatcher fires on every `fromSync: true` batch from
/// `UpdateNotifications.syncUpdateStream`. The provider is `keepAlive` —
/// the subscription must survive the entire app lifetime.

final class SyncedAudioInferenceListenerProvider
    extends
        $FunctionalProvider<
          SyncedAudioInferenceListener,
          SyncedAudioInferenceListener,
          SyncedAudioInferenceListener
        >
    with $Provider<SyncedAudioInferenceListener> {
  /// Eagerly-constructed sync-only listener.
  ///
  /// Watching this provider from `MyBeamerApp` calls `start()` so the
  /// dispatcher fires on every `fromSync: true` batch from
  /// `UpdateNotifications.syncUpdateStream`. The provider is `keepAlive` —
  /// the subscription must survive the entire app lifetime.
  SyncedAudioInferenceListenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncedAudioInferenceListenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncedAudioInferenceListenerHash();

  @$internal
  @override
  $ProviderElement<SyncedAudioInferenceListener> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncedAudioInferenceListener create(Ref ref) {
    return syncedAudioInferenceListener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncedAudioInferenceListener value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncedAudioInferenceListener>(value),
    );
  }
}

String _$syncedAudioInferenceListenerHash() =>
    r'6d8d6139877a54de22b34bba54cc8c6c7b11b0c7';
