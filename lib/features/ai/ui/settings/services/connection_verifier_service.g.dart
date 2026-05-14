// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_verifier_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Probe-per-provider lookup table. Override in tests to substitute
/// fake probes (returns canned states) without monkeypatching network
/// IO. Production callers leave this alone.

@ProviderFor(connectionProbeRegistry)
final connectionProbeRegistryProvider = ConnectionProbeRegistryProvider._();

/// Probe-per-provider lookup table. Override in tests to substitute
/// fake probes (returns canned states) without monkeypatching network
/// IO. Production callers leave this alone.

final class ConnectionProbeRegistryProvider
    extends
        $FunctionalProvider<
          Map<InferenceProviderType, ConnectionProbe>,
          Map<InferenceProviderType, ConnectionProbe>,
          Map<InferenceProviderType, ConnectionProbe>
        >
    with $Provider<Map<InferenceProviderType, ConnectionProbe>> {
  /// Probe-per-provider lookup table. Override in tests to substitute
  /// fake probes (returns canned states) without monkeypatching network
  /// IO. Production callers leave this alone.
  ConnectionProbeRegistryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectionProbeRegistryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectionProbeRegistryHash();

  @$internal
  @override
  $ProviderElement<Map<InferenceProviderType, ConnectionProbe>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<InferenceProviderType, ConnectionProbe> create(Ref ref) {
    return connectionProbeRegistry(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    Map<InferenceProviderType, ConnectionProbe> value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<Map<InferenceProviderType, ConnectionProbe>>(
            value,
          ),
    );
  }
}

String _$connectionProbeRegistryHash() =>
    r'309743132f30a96956dfecd8086cd6780f6d9159';

/// HTTP client factory used by the verifier. A factory (not a single
/// shared client) so each probe gets its own short-lived client that
/// can be `.close()`d in a `finally` without leaking connections to
/// concurrent probes. Tests override this with a `MockClient`-backed
/// factory to assert calls without touching the network.

@ProviderFor(connectionVerifierClient)
final connectionVerifierClientProvider = ConnectionVerifierClientProvider._();

/// HTTP client factory used by the verifier. A factory (not a single
/// shared client) so each probe gets its own short-lived client that
/// can be `.close()`d in a `finally` without leaking connections to
/// concurrent probes. Tests override this with a `MockClient`-backed
/// factory to assert calls without touching the network.

final class ConnectionVerifierClientProvider
    extends
        $FunctionalProvider<
          http.Client Function(),
          http.Client Function(),
          http.Client Function()
        >
    with $Provider<http.Client Function()> {
  /// HTTP client factory used by the verifier. A factory (not a single
  /// shared client) so each probe gets its own short-lived client that
  /// can be `.close()`d in a `finally` without leaking connections to
  /// concurrent probes. Tests override this with a `MockClient`-backed
  /// factory to assert calls without touching the network.
  ConnectionVerifierClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectionVerifierClientProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectionVerifierClientHash();

  @$internal
  @override
  $ProviderElement<http.Client Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  http.Client Function() create(Ref ref) {
    return connectionVerifierClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(http.Client Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<http.Client Function()>(value),
    );
  }
}

String _$connectionVerifierClientHash() =>
    r'39178bb96e14f1a2d849a22ab6b0989469f8d540';

/// Per-probe timeout. Surfaced as a separate provider so retry-style
/// tests can shorten it without instantiating the controller directly.

@ProviderFor(connectionVerifierTimeout)
final connectionVerifierTimeoutProvider = ConnectionVerifierTimeoutProvider._();

/// Per-probe timeout. Surfaced as a separate provider so retry-style
/// tests can shorten it without instantiating the controller directly.

final class ConnectionVerifierTimeoutProvider
    extends $FunctionalProvider<Duration, Duration, Duration>
    with $Provider<Duration> {
  /// Per-probe timeout. Surfaced as a separate provider so retry-style
  /// tests can shorten it without instantiating the controller directly.
  ConnectionVerifierTimeoutProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectionVerifierTimeoutProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectionVerifierTimeoutHash();

  @$internal
  @override
  $ProviderElement<Duration> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Duration create(Ref ref) {
    return connectionVerifierTimeout(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Duration value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Duration>(value),
    );
  }
}

String _$connectionVerifierTimeoutHash() =>
    r'fdcf8d541e45fd634dd4aee42778df66b56d41d8';

/// Family-keyed Riverpod notifier driving the connection-check strip.
/// One controller instance per `InferenceProviderType` so tab swaps
/// don't carry stale verification state between provider types.

@ProviderFor(ConnectionVerifierController)
final connectionVerifierControllerProvider =
    ConnectionVerifierControllerFamily._();

/// Family-keyed Riverpod notifier driving the connection-check strip.
/// One controller instance per `InferenceProviderType` so tab swaps
/// don't carry stale verification state between provider types.
final class ConnectionVerifierControllerProvider
    extends
        $NotifierProvider<ConnectionVerifierController, ConnectionCheckState> {
  /// Family-keyed Riverpod notifier driving the connection-check strip.
  /// One controller instance per `InferenceProviderType` so tab swaps
  /// don't carry stale verification state between provider types.
  ConnectionVerifierControllerProvider._({
    required ConnectionVerifierControllerFamily super.from,
    required InferenceProviderType super.argument,
  }) : super(
         retry: null,
         name: r'connectionVerifierControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$connectionVerifierControllerHash();

  @override
  String toString() {
    return r'connectionVerifierControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ConnectionVerifierController create() => ConnectionVerifierController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConnectionCheckState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConnectionCheckState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionVerifierControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$connectionVerifierControllerHash() =>
    r'590d50a848c139ba8d6f72e8c066cedde2013200';

/// Family-keyed Riverpod notifier driving the connection-check strip.
/// One controller instance per `InferenceProviderType` so tab swaps
/// don't carry stale verification state between provider types.

final class ConnectionVerifierControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ConnectionVerifierController,
          ConnectionCheckState,
          ConnectionCheckState,
          ConnectionCheckState,
          InferenceProviderType
        > {
  ConnectionVerifierControllerFamily._()
    : super(
        retry: null,
        name: r'connectionVerifierControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Family-keyed Riverpod notifier driving the connection-check strip.
  /// One controller instance per `InferenceProviderType` so tab swaps
  /// don't carry stale verification state between provider types.

  ConnectionVerifierControllerProvider call(
    InferenceProviderType providerType,
  ) => ConnectionVerifierControllerProvider._(
    argument: providerType,
    from: this,
  );

  @override
  String toString() => r'connectionVerifierControllerProvider';
}

/// Family-keyed Riverpod notifier driving the connection-check strip.
/// One controller instance per `InferenceProviderType` so tab swaps
/// don't carry stale verification state between provider types.

abstract class _$ConnectionVerifierController
    extends $Notifier<ConnectionCheckState> {
  late final _$args = ref.$arg as InferenceProviderType;
  InferenceProviderType get providerType => _$args;

  ConnectionCheckState build(InferenceProviderType providerType);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ConnectionCheckState, ConnectionCheckState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ConnectionCheckState, ConnectionCheckState>,
              ConnectionCheckState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
