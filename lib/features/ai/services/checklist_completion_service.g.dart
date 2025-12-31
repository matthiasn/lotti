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

final class ChecklistCompletionServiceProvider extends $AsyncNotifierProvider<
    ChecklistCompletionService, List<ChecklistCompletionSuggestion>> {
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
    r'325f3b15abd863d11de14f0d5386023a9ee14ef9';

abstract class _$ChecklistCompletionService
    extends $AsyncNotifier<List<ChecklistCompletionSuggestion>> {
  FutureOr<List<ChecklistCompletionSuggestion>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<
        AsyncValue<List<ChecklistCompletionSuggestion>>,
        List<ChecklistCompletionSuggestion>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<ChecklistCompletionSuggestion>>,
            List<ChecklistCompletionSuggestion>>,
        AsyncValue<List<ChecklistCompletionSuggestion>>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
