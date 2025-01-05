// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'survey_chart_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$surveyChartDataControllerHash() =>
    r'6fab5e5f2377b3f54e40041937aa0bdaab4d1f2b';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$SurveyChartDataController
    extends BuildlessAutoDisposeAsyncNotifier<List<JournalEntity>> {
  late final String surveyType;
  late final DateTime rangeStart;
  late final DateTime rangeEnd;

  FutureOr<List<JournalEntity>> build({
    required String surveyType,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });
}

/// See also [SurveyChartDataController].
@ProviderFor(SurveyChartDataController)
const surveyChartDataControllerProvider = SurveyChartDataControllerFamily();

/// See also [SurveyChartDataController].
class SurveyChartDataControllerFamily
    extends Family<AsyncValue<List<JournalEntity>>> {
  /// See also [SurveyChartDataController].
  const SurveyChartDataControllerFamily();

  /// See also [SurveyChartDataController].
  SurveyChartDataControllerProvider call({
    required String surveyType,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return SurveyChartDataControllerProvider(
      surveyType: surveyType,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  SurveyChartDataControllerProvider getProviderOverride(
    covariant SurveyChartDataControllerProvider provider,
  ) {
    return call(
      surveyType: provider.surveyType,
      rangeStart: provider.rangeStart,
      rangeEnd: provider.rangeEnd,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'surveyChartDataControllerProvider';
}

/// See also [SurveyChartDataController].
class SurveyChartDataControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<SurveyChartDataController,
        List<JournalEntity>> {
  /// See also [SurveyChartDataController].
  SurveyChartDataControllerProvider({
    required String surveyType,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) : this._internal(
          () => SurveyChartDataController()
            ..surveyType = surveyType
            ..rangeStart = rangeStart
            ..rangeEnd = rangeEnd,
          from: surveyChartDataControllerProvider,
          name: r'surveyChartDataControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$surveyChartDataControllerHash,
          dependencies: SurveyChartDataControllerFamily._dependencies,
          allTransitiveDependencies:
              SurveyChartDataControllerFamily._allTransitiveDependencies,
          surveyType: surveyType,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

  SurveyChartDataControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.surveyType,
    required this.rangeStart,
    required this.rangeEnd,
  }) : super.internal();

  final String surveyType;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  FutureOr<List<JournalEntity>> runNotifierBuild(
    covariant SurveyChartDataController notifier,
  ) {
    return notifier.build(
      surveyType: surveyType,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  Override overrideWith(SurveyChartDataController Function() create) {
    return ProviderOverride(
      origin: this,
      override: SurveyChartDataControllerProvider._internal(
        () => create()
          ..surveyType = surveyType
          ..rangeStart = rangeStart
          ..rangeEnd = rangeEnd,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        surveyType: surveyType,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<SurveyChartDataController,
      List<JournalEntity>> createElement() {
    return _SurveyChartDataControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SurveyChartDataControllerProvider &&
        other.surveyType == surveyType &&
        other.rangeStart == rangeStart &&
        other.rangeEnd == rangeEnd;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, surveyType.hashCode);
    hash = _SystemHash.combine(hash, rangeStart.hashCode);
    hash = _SystemHash.combine(hash, rangeEnd.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SurveyChartDataControllerRef
    on AutoDisposeAsyncNotifierProviderRef<List<JournalEntity>> {
  /// The parameter `surveyType` of this provider.
  String get surveyType;

  /// The parameter `rangeStart` of this provider.
  DateTime get rangeStart;

  /// The parameter `rangeEnd` of this provider.
  DateTime get rangeEnd;
}

class _SurveyChartDataControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<SurveyChartDataController,
        List<JournalEntity>> with SurveyChartDataControllerRef {
  _SurveyChartDataControllerProviderElement(super.provider);

  @override
  String get surveyType =>
      (origin as SurveyChartDataControllerProvider).surveyType;
  @override
  DateTime get rangeStart =>
      (origin as SurveyChartDataControllerProvider).rangeStart;
  @override
  DateTime get rangeEnd =>
      (origin as SurveyChartDataControllerProvider).rangeEnd;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
