// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_completion_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HabitCompletionController)
final habitCompletionControllerProvider = HabitCompletionControllerFamily._();

final class HabitCompletionControllerProvider extends $AsyncNotifierProvider<
    HabitCompletionController, List<HabitResult>> {
  HabitCompletionControllerProvider._(
      {required HabitCompletionControllerFamily super.from,
      required ({
        String habitId,
        DateTime rangeStart,
        DateTime rangeEnd,
      })
          super.argument})
      : super(
          retry: null,
          name: r'habitCompletionControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$habitCompletionControllerHash();

  @override
  String toString() {
    return r'habitCompletionControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  HabitCompletionController create() => HabitCompletionController();

  @override
  bool operator ==(Object other) {
    return other is HabitCompletionControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$habitCompletionControllerHash() =>
    r'8d260b21ccd31e85888f0ca3d382bab05d3dad4d';

final class HabitCompletionControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            HabitCompletionController,
            AsyncValue<List<HabitResult>>,
            List<HabitResult>,
            FutureOr<List<HabitResult>>,
            ({
              String habitId,
              DateTime rangeStart,
              DateTime rangeEnd,
            })> {
  HabitCompletionControllerFamily._()
      : super(
          retry: null,
          name: r'habitCompletionControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  HabitCompletionControllerProvider call({
    required String habitId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) =>
      HabitCompletionControllerProvider._(argument: (
        habitId: habitId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ), from: this);

  @override
  String toString() => r'habitCompletionControllerProvider';
}

abstract class _$HabitCompletionController
    extends $AsyncNotifier<List<HabitResult>> {
  late final _$args = ref.$arg as ({
    String habitId,
    DateTime rangeStart,
    DateTime rangeEnd,
  });
  String get habitId => _$args.habitId;
  DateTime get rangeStart => _$args.rangeStart;
  DateTime get rangeEnd => _$args.rangeEnd;

  FutureOr<List<HabitResult>> build({
    required String habitId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<HabitResult>>, List<HabitResult>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<HabitResult>>, List<HabitResult>>,
        AsyncValue<List<HabitResult>>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              habitId: _$args.habitId,
              rangeStart: _$args.rangeStart,
              rangeEnd: _$args.rangeEnd,
            ));
  }
}
