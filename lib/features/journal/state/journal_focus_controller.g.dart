// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_focus_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(JournalFocusController)
final journalFocusControllerProvider = JournalFocusControllerFamily._();

final class JournalFocusControllerProvider
    extends $NotifierProvider<JournalFocusController, JournalFocusIntent?> {
  JournalFocusControllerProvider._(
      {required JournalFocusControllerFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'journalFocusControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$journalFocusControllerHash();

  @override
  String toString() {
    return r'journalFocusControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  JournalFocusController create() => JournalFocusController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JournalFocusIntent? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JournalFocusIntent?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is JournalFocusControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$journalFocusControllerHash() =>
    r'229387822c8a304890ec00a6ea68319248a5594d';

final class JournalFocusControllerFamily extends $Family
    with
        $ClassFamilyOverride<JournalFocusController, JournalFocusIntent?,
            JournalFocusIntent?, JournalFocusIntent?, String> {
  JournalFocusControllerFamily._()
      : super(
          retry: null,
          name: r'journalFocusControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  JournalFocusControllerProvider call({
    required String id,
  }) =>
      JournalFocusControllerProvider._(argument: id, from: this);

  @override
  String toString() => r'journalFocusControllerProvider';
}

abstract class _$JournalFocusController extends $Notifier<JournalFocusIntent?> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  JournalFocusIntent? build({
    required String id,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<JournalFocusIntent?, JournalFocusIntent?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<JournalFocusIntent?, JournalFocusIntent?>,
        JournalFocusIntent?,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              id: _$args,
            ));
  }
}
