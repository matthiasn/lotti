// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist_completion_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ChecklistCompletionService)
final checklistCompletionServiceProvider =
    ChecklistCompletionServiceProvider._();

final class ChecklistCompletionServiceProvider
    extends
        $AsyncNotifierProvider<
          ChecklistCompletionService,
          List<ChecklistCompletionSuggestion>
        > {
  ChecklistCompletionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'checklistCompletionServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$checklistCompletionServiceHash();

  @$internal
  @override
  ChecklistCompletionService create() => ChecklistCompletionService();
}

String _$checklistCompletionServiceHash() =>
    r'6d27ba5cfbc1cb79bd6357fbe2207da3c67da1f5';

abstract class _$ChecklistCompletionService
    extends $AsyncNotifier<List<ChecklistCompletionSuggestion>> {
  FutureOr<List<ChecklistCompletionSuggestion>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<ChecklistCompletionSuggestion>>,
              List<ChecklistCompletionSuggestion>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<ChecklistCompletionSuggestion>>,
                List<ChecklistCompletionSuggestion>
              >,
              AsyncValue<List<ChecklistCompletionSuggestion>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
