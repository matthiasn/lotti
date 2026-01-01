// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_page_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for managing journal/tasks page state.
///
/// Uses a family provider pattern with showTasks as the family key.
/// keepAlive: true to preserve state when switching tabs.

@ProviderFor(JournalPageController)
final journalPageControllerProvider = JournalPageControllerFamily._();

/// Controller for managing journal/tasks page state.
///
/// Uses a family provider pattern with showTasks as the family key.
/// keepAlive: true to preserve state when switching tabs.
final class JournalPageControllerProvider
    extends $NotifierProvider<JournalPageController, JournalPageState> {
  /// Controller for managing journal/tasks page state.
  ///
  /// Uses a family provider pattern with showTasks as the family key.
  /// keepAlive: true to preserve state when switching tabs.
  JournalPageControllerProvider._(
      {required JournalPageControllerFamily super.from,
      required bool super.argument})
      : super(
          retry: null,
          name: r'journalPageControllerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$journalPageControllerHash();

  @override
  String toString() {
    return r'journalPageControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  JournalPageController create() => JournalPageController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JournalPageState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JournalPageState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is JournalPageControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$journalPageControllerHash() =>
    r'b4177fb43c71e8aa87bae0ffe07ef7c387739358';

/// Controller for managing journal/tasks page state.
///
/// Uses a family provider pattern with showTasks as the family key.
/// keepAlive: true to preserve state when switching tabs.

final class JournalPageControllerFamily extends $Family
    with
        $ClassFamilyOverride<JournalPageController, JournalPageState,
            JournalPageState, JournalPageState, bool> {
  JournalPageControllerFamily._()
      : super(
          retry: null,
          name: r'journalPageControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: false,
        );

  /// Controller for managing journal/tasks page state.
  ///
  /// Uses a family provider pattern with showTasks as the family key.
  /// keepAlive: true to preserve state when switching tabs.

  JournalPageControllerProvider call(
    bool showTasks,
  ) =>
      JournalPageControllerProvider._(argument: showTasks, from: this);

  @override
  String toString() => r'journalPageControllerProvider';
}

/// Controller for managing journal/tasks page state.
///
/// Uses a family provider pattern with showTasks as the family key.
/// keepAlive: true to preserve state when switching tabs.

abstract class _$JournalPageController extends $Notifier<JournalPageState> {
  late final _$args = ref.$arg as bool;
  bool get showTasks => _$args;

  JournalPageState build(
    bool showTasks,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<JournalPageState, JournalPageState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<JournalPageState, JournalPageState>,
        JournalPageState,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              _$args,
            ));
  }
}
