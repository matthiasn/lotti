// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'linked_tasks_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for managing the LinkedTasks section UI state.

@ProviderFor(LinkedTasksController)
final linkedTasksControllerProvider = LinkedTasksControllerFamily._();

/// Controller for managing the LinkedTasks section UI state.
final class LinkedTasksControllerProvider
    extends $NotifierProvider<LinkedTasksController, LinkedTasksState> {
  /// Controller for managing the LinkedTasks section UI state.
  LinkedTasksControllerProvider._(
      {required LinkedTasksControllerFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'linkedTasksControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$linkedTasksControllerHash();

  @override
  String toString() {
    return r'linkedTasksControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LinkedTasksController create() => LinkedTasksController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LinkedTasksState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LinkedTasksState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LinkedTasksControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$linkedTasksControllerHash() =>
    r'e7206ded96d7a406b69ef535e4368d89c4b8fb69';

/// Controller for managing the LinkedTasks section UI state.

final class LinkedTasksControllerFamily extends $Family
    with
        $ClassFamilyOverride<LinkedTasksController, LinkedTasksState,
            LinkedTasksState, LinkedTasksState, String> {
  LinkedTasksControllerFamily._()
      : super(
          retry: null,
          name: r'linkedTasksControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Controller for managing the LinkedTasks section UI state.

  LinkedTasksControllerProvider call({
    required String taskId,
  }) =>
      LinkedTasksControllerProvider._(argument: taskId, from: this);

  @override
  String toString() => r'linkedTasksControllerProvider';
}

/// Controller for managing the LinkedTasks section UI state.

abstract class _$LinkedTasksController extends $Notifier<LinkedTasksState> {
  late final _$args = ref.$arg as String;
  String get taskId => _$args;

  LinkedTasksState build({
    required String taskId,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<LinkedTasksState, LinkedTasksState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<LinkedTasksState, LinkedTasksState>,
        LinkedTasksState,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              taskId: _$args,
            ));
  }
}

/// Provider that resolves outgoing entry links to Task entities.
///
/// This is used by LinkedToSection to get resolved Task objects
/// instead of EntryLinks, avoiding the need to watch individual
/// entryControllerProviders in the widget tree.
///
/// Returns `List<JournalEntity>` (all Tasks) - caller should cast with `whereType<Task>()`.

@ProviderFor(outgoingLinkedTasks)
final outgoingLinkedTasksProvider = OutgoingLinkedTasksFamily._();

/// Provider that resolves outgoing entry links to Task entities.
///
/// This is used by LinkedToSection to get resolved Task objects
/// instead of EntryLinks, avoiding the need to watch individual
/// entryControllerProviders in the widget tree.
///
/// Returns `List<JournalEntity>` (all Tasks) - caller should cast with `whereType<Task>()`.

final class OutgoingLinkedTasksProvider extends $FunctionalProvider<
    List<JournalEntity>,
    List<JournalEntity>,
    List<JournalEntity>> with $Provider<List<JournalEntity>> {
  /// Provider that resolves outgoing entry links to Task entities.
  ///
  /// This is used by LinkedToSection to get resolved Task objects
  /// instead of EntryLinks, avoiding the need to watch individual
  /// entryControllerProviders in the widget tree.
  ///
  /// Returns `List<JournalEntity>` (all Tasks) - caller should cast with `whereType<Task>()`.
  OutgoingLinkedTasksProvider._(
      {required OutgoingLinkedTasksFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'outgoingLinkedTasksProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$outgoingLinkedTasksHash();

  @override
  String toString() {
    return r'outgoingLinkedTasksProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<List<JournalEntity>> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<JournalEntity> create(Ref ref) {
    final argument = this.argument as String;
    return outgoingLinkedTasks(
      ref,
      argument,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<JournalEntity> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<JournalEntity>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is OutgoingLinkedTasksProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$outgoingLinkedTasksHash() =>
    r'22d1f2dc6c6aafda071a74faed9e5afda408d22f';

/// Provider that resolves outgoing entry links to Task entities.
///
/// This is used by LinkedToSection to get resolved Task objects
/// instead of EntryLinks, avoiding the need to watch individual
/// entryControllerProviders in the widget tree.
///
/// Returns `List<JournalEntity>` (all Tasks) - caller should cast with `whereType<Task>()`.

final class OutgoingLinkedTasksFamily extends $Family
    with $FunctionalFamilyOverride<List<JournalEntity>, String> {
  OutgoingLinkedTasksFamily._()
      : super(
          retry: null,
          name: r'outgoingLinkedTasksProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Provider that resolves outgoing entry links to Task entities.
  ///
  /// This is used by LinkedToSection to get resolved Task objects
  /// instead of EntryLinks, avoiding the need to watch individual
  /// entryControllerProviders in the widget tree.
  ///
  /// Returns `List<JournalEntity>` (all Tasks) - caller should cast with `whereType<Task>()`.

  OutgoingLinkedTasksProvider call(
    String taskId,
  ) =>
      OutgoingLinkedTasksProvider._(argument: taskId, from: this);

  @override
  String toString() => r'outgoingLinkedTasksProvider';
}
