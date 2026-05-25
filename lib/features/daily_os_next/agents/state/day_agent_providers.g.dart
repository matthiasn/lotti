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

/// The Daily OS day-agent capture/reconcile service.

@ProviderFor(dayAgentCaptureService)
final dayAgentCaptureServiceProvider = DayAgentCaptureServiceProvider._();

/// The Daily OS day-agent capture/reconcile service.

final class DayAgentCaptureServiceProvider
    extends
        $FunctionalProvider<
          DayAgentCaptureService,
          DayAgentCaptureService,
          DayAgentCaptureService
        >
    with $Provider<DayAgentCaptureService> {
  /// The Daily OS day-agent capture/reconcile service.
  DayAgentCaptureServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dayAgentCaptureServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dayAgentCaptureServiceHash();

  @$internal
  @override
  $ProviderElement<DayAgentCaptureService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DayAgentCaptureService create(Ref ref) {
    return dayAgentCaptureService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DayAgentCaptureService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DayAgentCaptureService>(value),
    );
  }
}

String _$dayAgentCaptureServiceHash() =>
    r'f06f0abd8e56b3cc4d57f14b544b48a656ebc4e7';

/// The Daily OS day-agent drafting service.

@ProviderFor(dayAgentPlanService)
final dayAgentPlanServiceProvider = DayAgentPlanServiceProvider._();

/// The Daily OS day-agent drafting service.

final class DayAgentPlanServiceProvider
    extends
        $FunctionalProvider<
          DayAgentPlanService,
          DayAgentPlanService,
          DayAgentPlanService
        >
    with $Provider<DayAgentPlanService> {
  /// The Daily OS day-agent drafting service.
  DayAgentPlanServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dayAgentPlanServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dayAgentPlanServiceHash();

  @$internal
  @override
  $ProviderElement<DayAgentPlanService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DayAgentPlanService create(Ref ref) {
    return dayAgentPlanService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DayAgentPlanService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DayAgentPlanService>(value),
    );
  }
}

String _$dayAgentPlanServiceHash() =>
    r'174d6bded2a90ff5149f64fdd6c5a7af3e542cde';

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

/// Stream-refreshed parsed items for one capture.

@ProviderFor(parsedItemsForCapture)
final parsedItemsForCaptureProvider = ParsedItemsForCaptureFamily._();

/// Stream-refreshed parsed items for one capture.

final class ParsedItemsForCaptureProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AgentDomainEntity>>,
          List<AgentDomainEntity>,
          FutureOr<List<AgentDomainEntity>>
        >
    with
        $FutureModifier<List<AgentDomainEntity>>,
        $FutureProvider<List<AgentDomainEntity>> {
  /// Stream-refreshed parsed items for one capture.
  ParsedItemsForCaptureProvider._({
    required ParsedItemsForCaptureFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'parsedItemsForCaptureProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$parsedItemsForCaptureHash();

  @override
  String toString() {
    return r'parsedItemsForCaptureProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<AgentDomainEntity>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AgentDomainEntity>> create(Ref ref) {
    final argument = this.argument as String;
    return parsedItemsForCapture(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ParsedItemsForCaptureProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$parsedItemsForCaptureHash() =>
    r'53d4cb997743c687b265a666bcc8224d7351b872';

/// Stream-refreshed parsed items for one capture.

final class ParsedItemsForCaptureFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AgentDomainEntity>>, String> {
  ParsedItemsForCaptureFamily._()
    : super(
        retry: null,
        name: r'parsedItemsForCaptureProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Stream-refreshed parsed items for one capture.

  ParsedItemsForCaptureProvider call(String captureId) =>
      ParsedItemsForCaptureProvider._(argument: captureId, from: this);

  @override
  String toString() => r'parsedItemsForCaptureProvider';
}

/// Pending reconcile decisions for [date].

@ProviderFor(pendingDecisionsForDate)
final pendingDecisionsForDateProvider = PendingDecisionsForDateFamily._();

/// Pending reconcile decisions for [date].

final class PendingDecisionsForDateProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DayAgentPendingItem>>,
          List<DayAgentPendingItem>,
          FutureOr<List<DayAgentPendingItem>>
        >
    with
        $FutureModifier<List<DayAgentPendingItem>>,
        $FutureProvider<List<DayAgentPendingItem>> {
  /// Pending reconcile decisions for [date].
  PendingDecisionsForDateProvider._({
    required PendingDecisionsForDateFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'pendingDecisionsForDateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pendingDecisionsForDateHash();

  @override
  String toString() {
    return r'pendingDecisionsForDateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<DayAgentPendingItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<DayAgentPendingItem>> create(Ref ref) {
    final argument = this.argument as DateTime;
    return pendingDecisionsForDate(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PendingDecisionsForDateProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pendingDecisionsForDateHash() =>
    r'c6a78d2a4d386c6765f012ce0ed515e534fc88fb';

/// Pending reconcile decisions for [date].

final class PendingDecisionsForDateFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<DayAgentPendingItem>>,
          DateTime
        > {
  PendingDecisionsForDateFamily._()
    : super(
        retry: null,
        name: r'pendingDecisionsForDateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Pending reconcile decisions for [date].

  PendingDecisionsForDateProvider call(DateTime date) =>
      PendingDecisionsForDateProvider._(argument: date, from: this);

  @override
  String toString() => r'pendingDecisionsForDateProvider';
}
