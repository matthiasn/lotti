// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_plan_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the day plan for a specific date.
///
/// Automatically creates a draft plan if none exists.
/// Listens for updates and refreshes when the plan changes.

@ProviderFor(DayPlanController)
final dayPlanControllerProvider = DayPlanControllerFamily._();

/// Provides the day plan for a specific date.
///
/// Automatically creates a draft plan if none exists.
/// Listens for updates and refreshes when the plan changes.
final class DayPlanControllerProvider
    extends $AsyncNotifierProvider<DayPlanController, JournalEntity?> {
  /// Provides the day plan for a specific date.
  ///
  /// Automatically creates a draft plan if none exists.
  /// Listens for updates and refreshes when the plan changes.
  DayPlanControllerProvider._(
      {required DayPlanControllerFamily super.from,
      required DateTime super.argument})
      : super(
          retry: null,
          name: r'dayPlanControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dayPlanControllerHash();

  @override
  String toString() {
    return r'dayPlanControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  DayPlanController create() => DayPlanController();

  @override
  bool operator ==(Object other) {
    return other is DayPlanControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dayPlanControllerHash() => r'8f30dd30a0f2ae7ae7ce7bbb66c33624402ad160';

/// Provides the day plan for a specific date.
///
/// Automatically creates a draft plan if none exists.
/// Listens for updates and refreshes when the plan changes.

final class DayPlanControllerFamily extends $Family
    with
        $ClassFamilyOverride<DayPlanController, AsyncValue<JournalEntity?>,
            JournalEntity?, FutureOr<JournalEntity?>, DateTime> {
  DayPlanControllerFamily._()
      : super(
          retry: null,
          name: r'dayPlanControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Provides the day plan for a specific date.
  ///
  /// Automatically creates a draft plan if none exists.
  /// Listens for updates and refreshes when the plan changes.

  DayPlanControllerProvider call({
    required DateTime date,
  }) =>
      DayPlanControllerProvider._(argument: date, from: this);

  @override
  String toString() => r'dayPlanControllerProvider';
}

/// Provides the day plan for a specific date.
///
/// Automatically creates a draft plan if none exists.
/// Listens for updates and refreshes when the plan changes.

abstract class _$DayPlanController extends $AsyncNotifier<JournalEntity?> {
  late final _$args = ref.$arg as DateTime;
  DateTime get date => _$args;

  FutureOr<JournalEntity?> build({
    required DateTime date,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<JournalEntity?>, JournalEntity?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<JournalEntity?>, JournalEntity?>,
        AsyncValue<JournalEntity?>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              date: _$args,
            ));
  }
}
