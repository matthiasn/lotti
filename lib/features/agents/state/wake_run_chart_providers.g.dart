// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wake_run_chart_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Computes time-series chart data for a template's wake runs.
///
/// Fetches raw [WakeRunLogData] via the [AgentRepository] and transforms
/// them into daily and per-version buckets suitable for mini chart rendering.

@ProviderFor(templateWakeRunTimeSeries)
final templateWakeRunTimeSeriesProvider = TemplateWakeRunTimeSeriesFamily._();

/// Computes time-series chart data for a template's wake runs.
///
/// Fetches raw [WakeRunLogData] via the [AgentRepository] and transforms
/// them into daily and per-version buckets suitable for mini chart rendering.

final class TemplateWakeRunTimeSeriesProvider extends $FunctionalProvider<
        AsyncValue<WakeRunTimeSeries>,
        WakeRunTimeSeries,
        FutureOr<WakeRunTimeSeries>>
    with
        $FutureModifier<WakeRunTimeSeries>,
        $FutureProvider<WakeRunTimeSeries> {
  /// Computes time-series chart data for a template's wake runs.
  ///
  /// Fetches raw [WakeRunLogData] via the [AgentRepository] and transforms
  /// them into daily and per-version buckets suitable for mini chart rendering.
  TemplateWakeRunTimeSeriesProvider._(
      {required TemplateWakeRunTimeSeriesFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'templateWakeRunTimeSeriesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$templateWakeRunTimeSeriesHash();

  @override
  String toString() {
    return r'templateWakeRunTimeSeriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<WakeRunTimeSeries> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<WakeRunTimeSeries> create(Ref ref) {
    final argument = this.argument as String;
    return templateWakeRunTimeSeries(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TemplateWakeRunTimeSeriesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$templateWakeRunTimeSeriesHash() =>
    r'8ced658529ced5229d6411d6b44de5b7399a984a';

/// Computes time-series chart data for a template's wake runs.
///
/// Fetches raw [WakeRunLogData] via the [AgentRepository] and transforms
/// them into daily and per-version buckets suitable for mini chart rendering.

final class TemplateWakeRunTimeSeriesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<WakeRunTimeSeries>, String> {
  TemplateWakeRunTimeSeriesFamily._()
      : super(
          retry: null,
          name: r'templateWakeRunTimeSeriesProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Computes time-series chart data for a template's wake runs.
  ///
  /// Fetches raw [WakeRunLogData] via the [AgentRepository] and transforms
  /// them into daily and per-version buckets suitable for mini chart rendering.

  TemplateWakeRunTimeSeriesProvider call(
    String templateId,
  ) =>
      TemplateWakeRunTimeSeriesProvider._(argument: templateId, from: this);

  @override
  String toString() => r'templateWakeRunTimeSeriesProvider';
}

/// Computes task resolution time-series (true MTTR) for a template.
///
/// Bridges the agent database and journal database:
/// 1. Fetches all agents assigned to the template.
/// 2. For each agent, fetches `agent_task` links to find linked tasks.
/// 3. For each linked task, looks up the [JournalEntity] in the journal DB.
/// 4. Extracts the first DONE/REJECTED status from the task's status history.
/// 5. Computes MTTR as `status.createdAt - agent.createdAt`.

@ProviderFor(templateTaskResolutionTimeSeries)
final templateTaskResolutionTimeSeriesProvider =
    TemplateTaskResolutionTimeSeriesFamily._();

/// Computes task resolution time-series (true MTTR) for a template.
///
/// Bridges the agent database and journal database:
/// 1. Fetches all agents assigned to the template.
/// 2. For each agent, fetches `agent_task` links to find linked tasks.
/// 3. For each linked task, looks up the [JournalEntity] in the journal DB.
/// 4. Extracts the first DONE/REJECTED status from the task's status history.
/// 5. Computes MTTR as `status.createdAt - agent.createdAt`.

final class TemplateTaskResolutionTimeSeriesProvider
    extends $FunctionalProvider<AsyncValue<TaskResolutionTimeSeries>,
        TaskResolutionTimeSeries, FutureOr<TaskResolutionTimeSeries>>
    with
        $FutureModifier<TaskResolutionTimeSeries>,
        $FutureProvider<TaskResolutionTimeSeries> {
  /// Computes task resolution time-series (true MTTR) for a template.
  ///
  /// Bridges the agent database and journal database:
  /// 1. Fetches all agents assigned to the template.
  /// 2. For each agent, fetches `agent_task` links to find linked tasks.
  /// 3. For each linked task, looks up the [JournalEntity] in the journal DB.
  /// 4. Extracts the first DONE/REJECTED status from the task's status history.
  /// 5. Computes MTTR as `status.createdAt - agent.createdAt`.
  TemplateTaskResolutionTimeSeriesProvider._(
      {required TemplateTaskResolutionTimeSeriesFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'templateTaskResolutionTimeSeriesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$templateTaskResolutionTimeSeriesHash();

  @override
  String toString() {
    return r'templateTaskResolutionTimeSeriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TaskResolutionTimeSeries> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<TaskResolutionTimeSeries> create(Ref ref) {
    final argument = this.argument as String;
    return templateTaskResolutionTimeSeries(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TemplateTaskResolutionTimeSeriesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$templateTaskResolutionTimeSeriesHash() =>
    r'4827a29dfefe7df07308fe36a1b7011b7b9d62da';

/// Computes task resolution time-series (true MTTR) for a template.
///
/// Bridges the agent database and journal database:
/// 1. Fetches all agents assigned to the template.
/// 2. For each agent, fetches `agent_task` links to find linked tasks.
/// 3. For each linked task, looks up the [JournalEntity] in the journal DB.
/// 4. Extracts the first DONE/REJECTED status from the task's status history.
/// 5. Computes MTTR as `status.createdAt - agent.createdAt`.

final class TemplateTaskResolutionTimeSeriesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TaskResolutionTimeSeries>, String> {
  TemplateTaskResolutionTimeSeriesFamily._()
      : super(
          retry: null,
          name: r'templateTaskResolutionTimeSeriesProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Computes task resolution time-series (true MTTR) for a template.
  ///
  /// Bridges the agent database and journal database:
  /// 1. Fetches all agents assigned to the template.
  /// 2. For each agent, fetches `agent_task` links to find linked tasks.
  /// 3. For each linked task, looks up the [JournalEntity] in the journal DB.
  /// 4. Extracts the first DONE/REJECTED status from the task's status history.
  /// 5. Computes MTTR as `status.createdAt - agent.createdAt`.

  TemplateTaskResolutionTimeSeriesProvider call(
    String templateId,
  ) =>
      TemplateTaskResolutionTimeSeriesProvider._(
          argument: templateId, from: this);

  @override
  String toString() => r'templateTaskResolutionTimeSeriesProvider';
}
