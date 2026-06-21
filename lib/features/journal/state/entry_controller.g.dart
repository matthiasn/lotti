// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entry_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The detail-side controller for a single journal entry, keyed by entry id.
///
/// Owns the entry's load/draft/save lifecycle (the two-state `EntryState`
/// machine), editor focus/toolbar state, and the entity mutations exposed to
/// the detail UI — status/priority, cover art, language, and text copy. Saves
/// follow the dual-write path (persist the entity, then propagate metadata such
/// as category to linked entries). See the feature README for the full
/// save/refresh flow.

@ProviderFor(EntryController)
final entryControllerProvider = EntryControllerFamily._();

/// The detail-side controller for a single journal entry, keyed by entry id.
///
/// Owns the entry's load/draft/save lifecycle (the two-state `EntryState`
/// machine), editor focus/toolbar state, and the entity mutations exposed to
/// the detail UI — status/priority, cover art, language, and text copy. Saves
/// follow the dual-write path (persist the entity, then propagate metadata such
/// as category to linked entries). See the feature README for the full
/// save/refresh flow.
final class EntryControllerProvider
    extends $AsyncNotifierProvider<EntryController, EntryState?> {
  /// The detail-side controller for a single journal entry, keyed by entry id.
  ///
  /// Owns the entry's load/draft/save lifecycle (the two-state `EntryState`
  /// machine), editor focus/toolbar state, and the entity mutations exposed to
  /// the detail UI — status/priority, cover art, language, and text copy. Saves
  /// follow the dual-write path (persist the entity, then propagate metadata such
  /// as category to linked entries). See the feature README for the full
  /// save/refresh flow.
  EntryControllerProvider._({
    required EntryControllerFamily super.from,
    required String super.argument,
  }) : super(
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

String _$entryControllerHash() => r'89ea8962ec514aab90887fef7ab990758dd4af76';

/// The detail-side controller for a single journal entry, keyed by entry id.
///
/// Owns the entry's load/draft/save lifecycle (the two-state `EntryState`
/// machine), editor focus/toolbar state, and the entity mutations exposed to
/// the detail UI — status/priority, cover art, language, and text copy. Saves
/// follow the dual-write path (persist the entity, then propagate metadata such
/// as category to linked entries). See the feature README for the full
/// save/refresh flow.

final class EntryControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          EntryController,
          AsyncValue<EntryState?>,
          EntryState?,
          FutureOr<EntryState?>,
          String
        > {
  EntryControllerFamily._()
    : super(
        retry: null,
        name: r'entryControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The detail-side controller for a single journal entry, keyed by entry id.
  ///
  /// Owns the entry's load/draft/save lifecycle (the two-state `EntryState`
  /// machine), editor focus/toolbar state, and the entity mutations exposed to
  /// the detail UI — status/priority, cover art, language, and text copy. Saves
  /// follow the dual-write path (persist the entity, then propagate metadata such
  /// as category to linked entries). See the feature README for the full
  /// save/refresh flow.

  EntryControllerProvider call({required String id}) =>
      EntryControllerProvider._(argument: id, from: this);

  @override
  String toString() => r'entryControllerProvider';
}

/// The detail-side controller for a single journal entry, keyed by entry id.
///
/// Owns the entry's load/draft/save lifecycle (the two-state `EntryState`
/// machine), editor focus/toolbar state, and the entity mutations exposed to
/// the detail UI — status/priority, cover art, language, and text copy. Saves
/// follow the dual-write path (persist the entity, then propagate metadata such
/// as category to linked entries). See the feature README for the full
/// save/refresh flow.

abstract class _$EntryController extends $AsyncNotifier<EntryState?> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  FutureOr<EntryState?> build({required String id});
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<EntryState?>, EntryState?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<EntryState?>, EntryState?>,
              AsyncValue<EntryState?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(id: _$args));
  }
}
