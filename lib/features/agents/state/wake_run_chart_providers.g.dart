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
