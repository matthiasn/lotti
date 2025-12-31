// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'survey_chart_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SurveyChartDataController)
final surveyChartDataControllerProvider = SurveyChartDataControllerFamily._();

final class SurveyChartDataControllerProvider extends $AsyncNotifierProvider<
    SurveyChartDataController, List<JournalEntity>> {
  SurveyChartDataControllerProvider._(
      {required SurveyChartDataControllerFamily super.from,
      required ({
        String surveyType,
        DateTime rangeStart,
        DateTime rangeEnd,
      })
          super.argument})
      : super(
          retry: null,
          name: r'surveyChartDataControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$surveyChartDataControllerHash();

  @override
  String toString() {
    return r'surveyChartDataControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  SurveyChartDataController create() => SurveyChartDataController();

  @override
  bool operator ==(Object other) {
    return other is SurveyChartDataControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$surveyChartDataControllerHash() =>
    r'6fab5e5f2377b3f54e40041937aa0bdaab4d1f2b';

final class SurveyChartDataControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            SurveyChartDataController,
            AsyncValue<List<JournalEntity>>,
            List<JournalEntity>,
            FutureOr<List<JournalEntity>>,
            ({
              String surveyType,
              DateTime rangeStart,
              DateTime rangeEnd,
            })> {
  SurveyChartDataControllerFamily._()
      : super(
          retry: null,
          name: r'surveyChartDataControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  SurveyChartDataControllerProvider call({
    required String surveyType,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) =>
      SurveyChartDataControllerProvider._(argument: (
        surveyType: surveyType,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ), from: this);

  @override
  String toString() => r'surveyChartDataControllerProvider';
}

abstract class _$SurveyChartDataController
    extends $AsyncNotifier<List<JournalEntity>> {
  late final _$args = ref.$arg as ({
    String surveyType,
    DateTime rangeStart,
    DateTime rangeEnd,
  });
  String get surveyType => _$args.surveyType;
  DateTime get rangeStart => _$args.rangeStart;
  DateTime get rangeEnd => _$args.rangeEnd;

  FutureOr<List<JournalEntity>> build({
    required String surveyType,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<JournalEntity>>, List<JournalEntity>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<JournalEntity>>, List<JournalEntity>>,
        AsyncValue<List<JournalEntity>>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              surveyType: _$args.surveyType,
              rangeStart: _$args.rangeStart,
              rangeEnd: _$args.rangeEnd,
            ));
  }
}
