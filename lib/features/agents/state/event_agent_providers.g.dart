// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_agent_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The event-agent-specific service.

@ProviderFor(eventAgentService)
final eventAgentServiceProvider = EventAgentServiceProvider._();

/// The event-agent-specific service.

final class EventAgentServiceProvider
    extends
        $FunctionalProvider<
          EventAgentService,
          EventAgentService,
          EventAgentService
        >
    with $Provider<EventAgentService> {
  /// The event-agent-specific service.
  EventAgentServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eventAgentServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eventAgentServiceHash();

  @$internal
  @override
  $ProviderElement<EventAgentService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EventAgentService create(Ref ref) {
    return eventAgentService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EventAgentService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EventAgentService>(value),
    );
  }
}

String _$eventAgentServiceHash() => r'ca5b37bd7700a7ce8e94daf5fdc4334d48324c13';

/// Fetch the Event Agent for a given journal-domain [eventId].
///
/// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.
/// Watches the update stream so the UI rebuilds when an agent-event link
/// arrives via sync.

@ProviderFor(eventAgent)
final eventAgentProvider = EventAgentFamily._();

/// Fetch the Event Agent for a given journal-domain [eventId].
///
/// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.
/// Watches the update stream so the UI rebuilds when an agent-event link
/// arrives via sync.

final class EventAgentProvider
    extends
        $FunctionalProvider<
          AsyncValue<AgentDomainEntity?>,
          AgentDomainEntity?,
          FutureOr<AgentDomainEntity?>
        >
    with
        $FutureModifier<AgentDomainEntity?>,
        $FutureProvider<AgentDomainEntity?> {
  /// Fetch the Event Agent for a given journal-domain [eventId].
  ///
  /// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.
  /// Watches the update stream so the UI rebuilds when an agent-event link
  /// arrives via sync.
  EventAgentProvider._({
    required EventAgentFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'eventAgentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$eventAgentHash();

  @override
  String toString() {
    return r'eventAgentProvider'
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
    final argument = this.argument as String;
    return eventAgent(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EventAgentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$eventAgentHash() => r'00c67b995daf39a6ce7f8c140737917b51bf33a4';

/// Fetch the Event Agent for a given journal-domain [eventId].
///
/// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.
/// Watches the update stream so the UI rebuilds when an agent-event link
/// arrives via sync.

final class EventAgentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AgentDomainEntity?>, String> {
  EventAgentFamily._()
    : super(
        retry: null,
        name: r'eventAgentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fetch the Event Agent for a given journal-domain [eventId].
  ///
  /// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.
  /// Watches the update stream so the UI rebuilds when an agent-event link
  /// arrives via sync.

  EventAgentProvider call(String eventId) =>
      EventAgentProvider._(argument: eventId, from: this);

  @override
  String toString() => r'eventAgentProvider';
}
