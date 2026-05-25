// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_agent_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Daily OS day-agent service.

@ProviderFor(dayAgentService)
final dayAgentServiceProvider = DayAgentServiceProvider._();

/// The Daily OS day-agent service.

final class DayAgentServiceProvider
    extends
        $FunctionalProvider<DayAgentService, DayAgentService, DayAgentService>
    with $Provider<DayAgentService> {
  /// The Daily OS day-agent service.
  DayAgentServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dayAgentServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dayAgentServiceHash();

  @$internal
  @override
  $ProviderElement<DayAgentService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DayAgentService create(Ref ref) {
    return dayAgentService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DayAgentService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DayAgentService>(value),
    );
  }
}

String _$dayAgentServiceHash() => r'9c8771c7ab2d0dcb8a6ac1819a2cec8f0f66ad8c';

/// Fetch the active Daily OS day agent for [date], if one exists.

@ProviderFor(dayAgent)
final dayAgentProvider = DayAgentFamily._();

/// Fetch the active Daily OS day agent for [date], if one exists.

final class DayAgentProvider
    extends
        $FunctionalProvider<
          AsyncValue<AgentDomainEntity?>,
          AgentDomainEntity?,
          FutureOr<AgentDomainEntity?>
        >
    with
        $FutureModifier<AgentDomainEntity?>,
        $FutureProvider<AgentDomainEntity?> {
  /// Fetch the active Daily OS day agent for [date], if one exists.
  DayAgentProvider._({
    required DayAgentFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'dayAgentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dayAgentHash();

  @override
  String toString() {
    return r'dayAgentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<AgentDomainEntity?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AgentDomainEntity?> create(Ref ref) {
    final argument = this.argument as DateTime;
    return dayAgent(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DayAgentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dayAgentHash() => r'85322080372a7646bae0ff21c8a3857beb882796';

/// Fetch the active Daily OS day agent for [date], if one exists.

final class DayAgentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AgentDomainEntity?>, DateTime> {
  DayAgentFamily._()
    : super(
        retry: null,
        name: r'dayAgentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fetch the active Daily OS day agent for [date], if one exists.

  DayAgentProvider call(DateTime date) =>
      DayAgentProvider._(argument: date, from: this);

  @override
  String toString() => r'dayAgentProvider';
}
