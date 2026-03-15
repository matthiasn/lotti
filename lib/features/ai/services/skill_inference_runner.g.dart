// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skill_inference_runner.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(skillInferenceRunner)
final skillInferenceRunnerProvider = SkillInferenceRunnerProvider._();

final class SkillInferenceRunnerProvider
    extends
        $FunctionalProvider<
          SkillInferenceRunner,
          SkillInferenceRunner,
          SkillInferenceRunner
        >
    with $Provider<SkillInferenceRunner> {
  SkillInferenceRunnerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'skillInferenceRunnerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$skillInferenceRunnerHash();

  @$internal
  @override
  $ProviderElement<SkillInferenceRunner> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SkillInferenceRunner create(Ref ref) {
    return skillInferenceRunner(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SkillInferenceRunner value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SkillInferenceRunner>(value),
    );
  }
}

String _$skillInferenceRunnerHash() =>
    r'd14967a9acc5381272773281a17259b82a93d064';
