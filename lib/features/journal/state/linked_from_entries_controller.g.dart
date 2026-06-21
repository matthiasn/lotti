// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'linked_from_entries_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Loads and live-updates the entries that link *to* entry `id` (incoming
/// links, the "linked from" set), resolved to full [JournalEntity]s.
///
/// Mirrors `LinkedEntriesController` but for the reverse direction: subscribes
/// to [UpdateNotifications] and re-fetches when the source or any linking
/// entity changes, caching for `entryCacheDuration`.

@ProviderFor(LinkedFromEntriesController)
final linkedFromEntriesControllerProvider =
    LinkedFromEntriesControllerFamily._();

/// Loads and live-updates the entries that link *to* entry `id` (incoming
/// links, the "linked from" set), resolved to full [JournalEntity]s.
///
/// Mirrors `LinkedEntriesController` but for the reverse direction: subscribes
/// to [UpdateNotifications] and re-fetches when the source or any linking
/// entity changes, caching for `entryCacheDuration`.
final class LinkedFromEntriesControllerProvider
    extends
        $AsyncNotifierProvider<
          LinkedFromEntriesController,
          List<JournalEntity>
        > {
  /// Loads and live-updates the entries that link *to* entry `id` (incoming
  /// links, the "linked from" set), resolved to full [JournalEntity]s.
  ///
  /// Mirrors `LinkedEntriesController` but for the reverse direction: subscribes
  /// to [UpdateNotifications] and re-fetches when the source or any linking
  /// entity changes, caching for `entryCacheDuration`.
  LinkedFromEntriesControllerProvider._({
    required LinkedFromEntriesControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'linkedFromEntriesControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$linkedFromEntriesControllerHash();

  @override
  String toString() {
    return r'linkedFromEntriesControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LinkedFromEntriesController create() => LinkedFromEntriesController();

  @override
  bool operator ==(Object other) {
    return other is LinkedFromEntriesControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$linkedFromEntriesControllerHash() =>
    r'f0e539e16b539e4177fd402ed1150b391b3248f3';

/// Loads and live-updates the entries that link *to* entry `id` (incoming
/// links, the "linked from" set), resolved to full [JournalEntity]s.
///
/// Mirrors `LinkedEntriesController` but for the reverse direction: subscribes
/// to [UpdateNotifications] and re-fetches when the source or any linking
/// entity changes, caching for `entryCacheDuration`.

final class LinkedFromEntriesControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          LinkedFromEntriesController,
          AsyncValue<List<JournalEntity>>,
          List<JournalEntity>,
          FutureOr<List<JournalEntity>>,
          String
        > {
  LinkedFromEntriesControllerFamily._()
    : super(
        retry: null,
        name: r'linkedFromEntriesControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Loads and live-updates the entries that link *to* entry `id` (incoming
  /// links, the "linked from" set), resolved to full [JournalEntity]s.
  ///
  /// Mirrors `LinkedEntriesController` but for the reverse direction: subscribes
  /// to [UpdateNotifications] and re-fetches when the source or any linking
  /// entity changes, caching for `entryCacheDuration`.

  LinkedFromEntriesControllerProvider call({required String id}) =>
      LinkedFromEntriesControllerProvider._(argument: id, from: this);

  @override
  String toString() => r'linkedFromEntriesControllerProvider';
}

/// Loads and live-updates the entries that link *to* entry `id` (incoming
/// links, the "linked from" set), resolved to full [JournalEntity]s.
///
/// Mirrors `LinkedEntriesController` but for the reverse direction: subscribes
/// to [UpdateNotifications] and re-fetches when the source or any linking
/// entity changes, caching for `entryCacheDuration`.

abstract class _$LinkedFromEntriesController
    extends $AsyncNotifier<List<JournalEntity>> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  FutureOr<List<JournalEntity>> build({required String id});
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<JournalEntity>>, List<JournalEntity>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<JournalEntity>>, List<JournalEntity>>,
              AsyncValue<List<JournalEntity>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(id: _$args));
  }
}
