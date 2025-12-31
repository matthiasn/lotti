// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entry_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EntryController)
final entryControllerProvider = EntryControllerFamily._();

final class EntryControllerProvider
    extends $AsyncNotifierProvider<EntryController, EntryState?> {
  EntryControllerProvider._(
      {required EntryControllerFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'entryControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$entryControllerHash();

  @override
  String toString() {
    return r'entryControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  EntryController create() => EntryController();

  @override
  bool operator ==(Object other) {
    return other is EntryControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$entryControllerHash() => r'2e41635c80d4a72437d360bb07ba815faf9dfde3';

final class EntryControllerFamily extends $Family
    with
        $ClassFamilyOverride<EntryController, AsyncValue<EntryState?>,
            EntryState?, FutureOr<EntryState?>, String> {
  EntryControllerFamily._()
      : super(
          retry: null,
          name: r'entryControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  EntryControllerProvider call({
    required String id,
  }) =>
      EntryControllerProvider._(argument: id, from: this);

  @override
  String toString() => r'entryControllerProvider';
}

abstract class _$EntryController extends $AsyncNotifier<EntryState?> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  FutureOr<EntryState?> build({
    required String id,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<EntryState?>, EntryState?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<EntryState?>, EntryState?>,
        AsyncValue<EntryState?>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              id: _$args,
            ));
  }
}
