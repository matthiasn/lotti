// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_config_by_type_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for getting a list of AiConfig items of a specific type
/// Used in settings list pages to display all configurations of a particular type

@ProviderFor(AiConfigByTypeController)
final aiConfigByTypeControllerProvider = AiConfigByTypeControllerFamily._();

/// Controller for getting a list of AiConfig items of a specific type
/// Used in settings list pages to display all configurations of a particular type
final class AiConfigByTypeControllerProvider
    extends $StreamNotifierProvider<AiConfigByTypeController, List<AiConfig>> {
  /// Controller for getting a list of AiConfig items of a specific type
  /// Used in settings list pages to display all configurations of a particular type
  AiConfigByTypeControllerProvider._(
      {required AiConfigByTypeControllerFamily super.from,
      required AiConfigType super.argument})
      : super(
          retry: null,
          name: r'aiConfigByTypeControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$aiConfigByTypeControllerHash();

  @override
  String toString() {
    return r'aiConfigByTypeControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AiConfigByTypeController create() => AiConfigByTypeController();

  @override
  bool operator ==(Object other) {
    return other is AiConfigByTypeControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$aiConfigByTypeControllerHash() =>
    r'a808c63b14000abab40ea37fa9fdbafdfb1b1254';

/// Controller for getting a list of AiConfig items of a specific type
/// Used in settings list pages to display all configurations of a particular type

final class AiConfigByTypeControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            AiConfigByTypeController,
            AsyncValue<List<AiConfig>>,
            List<AiConfig>,
            Stream<List<AiConfig>>,
            AiConfigType> {
  AiConfigByTypeControllerFamily._()
      : super(
          retry: null,
          name: r'aiConfigByTypeControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Controller for getting a list of AiConfig items of a specific type
  /// Used in settings list pages to display all configurations of a particular type

  AiConfigByTypeControllerProvider call({
    required AiConfigType configType,
  }) =>
      AiConfigByTypeControllerProvider._(argument: configType, from: this);

  @override
  String toString() => r'aiConfigByTypeControllerProvider';
}

/// Controller for getting a list of AiConfig items of a specific type
/// Used in settings list pages to display all configurations of a particular type

abstract class _$AiConfigByTypeController
    extends $StreamNotifier<List<AiConfig>> {
  late final _$args = ref.$arg as AiConfigType;
  AiConfigType get configType => _$args;

  Stream<List<AiConfig>> build({
    required AiConfigType configType,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<AiConfig>>, List<AiConfig>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<AiConfig>>, List<AiConfig>>,
        AsyncValue<List<AiConfig>>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              configType: _$args,
            ));
  }
}

/// Provider for getting a specific AiConfig by its ID

@ProviderFor(aiConfigById)
final aiConfigByIdProvider = AiConfigByIdFamily._();

/// Provider for getting a specific AiConfig by its ID

final class AiConfigByIdProvider extends $FunctionalProvider<
        AsyncValue<AiConfig?>, AiConfig?, FutureOr<AiConfig?>>
    with $FutureModifier<AiConfig?>, $FutureProvider<AiConfig?> {
  /// Provider for getting a specific AiConfig by its ID
  AiConfigByIdProvider._(
      {required AiConfigByIdFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'aiConfigByIdProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$aiConfigByIdHash();

  @override
  String toString() {
    return r'aiConfigByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<AiConfig?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AiConfig?> create(Ref ref) {
    final argument = this.argument as String;
    return aiConfigById(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AiConfigByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$aiConfigByIdHash() => r'4dce6fd111f80adaa5a13ea60f7cdfb8fe96ee5a';

/// Provider for getting a specific AiConfig by its ID

final class AiConfigByIdFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AiConfig?>, String> {
  AiConfigByIdFamily._()
      : super(
          retry: null,
          name: r'aiConfigByIdProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Provider for getting a specific AiConfig by its ID

  AiConfigByIdProvider call(
    String id,
  ) =>
      AiConfigByIdProvider._(argument: id, from: this);

  @override
  String toString() => r'aiConfigByIdProvider';
}
