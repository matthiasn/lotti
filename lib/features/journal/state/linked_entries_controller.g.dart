// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'linked_entries_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LinkedEntriesController)
final linkedEntriesControllerProvider = LinkedEntriesControllerFamily._();

final class LinkedEntriesControllerProvider
    extends $AsyncNotifierProvider<LinkedEntriesController, List<EntryLink>> {
  LinkedEntriesControllerProvider._(
      {required LinkedEntriesControllerFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'linkedEntriesControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$linkedEntriesControllerHash();

  @override
  String toString() {
    return r'linkedEntriesControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LinkedEntriesController create() => LinkedEntriesController();

  @override
  bool operator ==(Object other) {
    return other is LinkedEntriesControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$linkedEntriesControllerHash() =>
    r'233ba30fd610e9366af282fd28573fb8df7eb040';

final class LinkedEntriesControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            LinkedEntriesController,
            AsyncValue<List<EntryLink>>,
            List<EntryLink>,
            FutureOr<List<EntryLink>>,
            String> {
  LinkedEntriesControllerFamily._()
      : super(
          retry: null,
          name: r'linkedEntriesControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  LinkedEntriesControllerProvider call({
    required String id,
  }) =>
      LinkedEntriesControllerProvider._(argument: id, from: this);

  @override
  String toString() => r'linkedEntriesControllerProvider';
}

abstract class _$LinkedEntriesController
    extends $AsyncNotifier<List<EntryLink>> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  FutureOr<List<EntryLink>> build({
    required String id,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<EntryLink>>, List<EntryLink>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<EntryLink>>, List<EntryLink>>,
        AsyncValue<List<EntryLink>>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              id: _$args,
            ));
  }
}

@ProviderFor(IncludeHiddenController)
final includeHiddenControllerProvider = IncludeHiddenControllerFamily._();

final class IncludeHiddenControllerProvider
    extends $NotifierProvider<IncludeHiddenController, bool> {
  IncludeHiddenControllerProvider._(
      {required IncludeHiddenControllerFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'includeHiddenControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$includeHiddenControllerHash();

  @override
  String toString() {
    return r'includeHiddenControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  IncludeHiddenController create() => IncludeHiddenController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IncludeHiddenControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$includeHiddenControllerHash() =>
    r'224d7a7bbee3c403c65bb85517e10fb1eeac3148';

final class IncludeHiddenControllerFamily extends $Family
    with
        $ClassFamilyOverride<IncludeHiddenController, bool, bool, bool,
            String> {
  IncludeHiddenControllerFamily._()
      : super(
          retry: null,
          name: r'includeHiddenControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  IncludeHiddenControllerProvider call({
    required String id,
  }) =>
      IncludeHiddenControllerProvider._(argument: id, from: this);

  @override
  String toString() => r'includeHiddenControllerProvider';
}

abstract class _$IncludeHiddenController extends $Notifier<bool> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  bool build({
    required String id,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<bool, bool>, bool, Object?, Object?>;
    element.handleCreate(
        ref,
        () => build(
              id: _$args,
            ));
  }
}

@ProviderFor(IncludeAiEntriesController)
final includeAiEntriesControllerProvider = IncludeAiEntriesControllerFamily._();

final class IncludeAiEntriesControllerProvider
    extends $NotifierProvider<IncludeAiEntriesController, bool> {
  IncludeAiEntriesControllerProvider._(
      {required IncludeAiEntriesControllerFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'includeAiEntriesControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$includeAiEntriesControllerHash();

  @override
  String toString() {
    return r'includeAiEntriesControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  IncludeAiEntriesController create() => IncludeAiEntriesController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IncludeAiEntriesControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$includeAiEntriesControllerHash() =>
    r'8db4e5da7dbd6f9ba3da50fc5227a5e0e507708a';

final class IncludeAiEntriesControllerFamily extends $Family
    with
        $ClassFamilyOverride<IncludeAiEntriesController, bool, bool, bool,
            String> {
  IncludeAiEntriesControllerFamily._()
      : super(
          retry: null,
          name: r'includeAiEntriesControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  IncludeAiEntriesControllerProvider call({
    required String id,
  }) =>
      IncludeAiEntriesControllerProvider._(argument: id, from: this);

  @override
  String toString() => r'includeAiEntriesControllerProvider';
}

abstract class _$IncludeAiEntriesController extends $Notifier<bool> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  bool build({
    required String id,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<bool, bool>, bool, Object?, Object?>;
    element.handleCreate(
        ref,
        () => build(
              id: _$args,
            ));
  }
}

@ProviderFor(NewestLinkedIdController)
final newestLinkedIdControllerProvider = NewestLinkedIdControllerFamily._();

final class NewestLinkedIdControllerProvider
    extends $AsyncNotifierProvider<NewestLinkedIdController, String?> {
  NewestLinkedIdControllerProvider._(
      {required NewestLinkedIdControllerFamily super.from,
      required String? super.argument})
      : super(
          retry: null,
          name: r'newestLinkedIdControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$newestLinkedIdControllerHash();

  @override
  String toString() {
    return r'newestLinkedIdControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  NewestLinkedIdController create() => NewestLinkedIdController();

  @override
  bool operator ==(Object other) {
    return other is NewestLinkedIdControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$newestLinkedIdControllerHash() =>
    r'b97f5f08862c659af19b300d4b6fbaf4c8d187dd';

final class NewestLinkedIdControllerFamily extends $Family
    with
        $ClassFamilyOverride<NewestLinkedIdController, AsyncValue<String?>,
            String?, FutureOr<String?>, String?> {
  NewestLinkedIdControllerFamily._()
      : super(
          retry: null,
          name: r'newestLinkedIdControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  NewestLinkedIdControllerProvider call({
    required String? id,
  }) =>
      NewestLinkedIdControllerProvider._(argument: id, from: this);

  @override
  String toString() => r'newestLinkedIdControllerProvider';
}

abstract class _$NewestLinkedIdController extends $AsyncNotifier<String?> {
  late final _$args = ref.$arg as String?;
  String? get id => _$args;

  FutureOr<String?> build({
    required String? id,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<String?>, String?>,
        AsyncValue<String?>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              id: _$args,
            ));
  }
}

/// Provider that resolves outgoing entry links to their actual JournalEntity objects.
///
/// This centralizes the resolution logic so that downstream providers can
/// filter/process the resolved entities without needing to watch individual
/// entryControllerProviders in loops.

@ProviderFor(resolvedOutgoingLinkedEntries)
final resolvedOutgoingLinkedEntriesProvider =
    ResolvedOutgoingLinkedEntriesFamily._();

/// Provider that resolves outgoing entry links to their actual JournalEntity objects.
///
/// This centralizes the resolution logic so that downstream providers can
/// filter/process the resolved entities without needing to watch individual
/// entryControllerProviders in loops.

final class ResolvedOutgoingLinkedEntriesProvider extends $FunctionalProvider<
    List<JournalEntity>,
    List<JournalEntity>,
    List<JournalEntity>> with $Provider<List<JournalEntity>> {
  /// Provider that resolves outgoing entry links to their actual JournalEntity objects.
  ///
  /// This centralizes the resolution logic so that downstream providers can
  /// filter/process the resolved entities without needing to watch individual
  /// entryControllerProviders in loops.
  ResolvedOutgoingLinkedEntriesProvider._(
      {required ResolvedOutgoingLinkedEntriesFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'resolvedOutgoingLinkedEntriesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$resolvedOutgoingLinkedEntriesHash();

  @override
  String toString() {
    return r'resolvedOutgoingLinkedEntriesProvider'
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
    return resolvedOutgoingLinkedEntries(
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
    return other is ResolvedOutgoingLinkedEntriesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$resolvedOutgoingLinkedEntriesHash() =>
    r'793c13331102795071985b3187b41f46ae2d5822';

/// Provider that resolves outgoing entry links to their actual JournalEntity objects.
///
/// This centralizes the resolution logic so that downstream providers can
/// filter/process the resolved entities without needing to watch individual
/// entryControllerProviders in loops.

final class ResolvedOutgoingLinkedEntriesFamily extends $Family
    with $FunctionalFamilyOverride<List<JournalEntity>, String> {
  ResolvedOutgoingLinkedEntriesFamily._()
      : super(
          retry: null,
          name: r'resolvedOutgoingLinkedEntriesProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Provider that resolves outgoing entry links to their actual JournalEntity objects.
  ///
  /// This centralizes the resolution logic so that downstream providers can
  /// filter/process the resolved entities without needing to watch individual
  /// entryControllerProviders in loops.

  ResolvedOutgoingLinkedEntriesProvider call(
    String id,
  ) =>
      ResolvedOutgoingLinkedEntriesProvider._(argument: id, from: this);

  @override
  String toString() => r'resolvedOutgoingLinkedEntriesProvider';
}

/// Provider that checks if there are any non-Task entries in the linked entries.
///
/// Used by LinkedEntriesWidget to determine whether to show the "Linked Entries"
/// section when hideTaskEntries is true.

@ProviderFor(hasNonTaskLinkedEntries)
final hasNonTaskLinkedEntriesProvider = HasNonTaskLinkedEntriesFamily._();

/// Provider that checks if there are any non-Task entries in the linked entries.
///
/// Used by LinkedEntriesWidget to determine whether to show the "Linked Entries"
/// section when hideTaskEntries is true.

final class HasNonTaskLinkedEntriesProvider
    extends $FunctionalProvider<bool, bool, bool> with $Provider<bool> {
  /// Provider that checks if there are any non-Task entries in the linked entries.
  ///
  /// Used by LinkedEntriesWidget to determine whether to show the "Linked Entries"
  /// section when hideTaskEntries is true.
  HasNonTaskLinkedEntriesProvider._(
      {required HasNonTaskLinkedEntriesFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'hasNonTaskLinkedEntriesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$hasNonTaskLinkedEntriesHash();

  @override
  String toString() {
    return r'hasNonTaskLinkedEntriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument = this.argument as String;
    return hasNonTaskLinkedEntries(
      ref,
      argument,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HasNonTaskLinkedEntriesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$hasNonTaskLinkedEntriesHash() =>
    r'4dc3405a0ba8a0008be8bbe58d4b4aa54c64c49f';

/// Provider that checks if there are any non-Task entries in the linked entries.
///
/// Used by LinkedEntriesWidget to determine whether to show the "Linked Entries"
/// section when hideTaskEntries is true.

final class HasNonTaskLinkedEntriesFamily extends $Family
    with $FunctionalFamilyOverride<bool, String> {
  HasNonTaskLinkedEntriesFamily._()
      : super(
          retry: null,
          name: r'hasNonTaskLinkedEntriesProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Provider that checks if there are any non-Task entries in the linked entries.
  ///
  /// Used by LinkedEntriesWidget to determine whether to show the "Linked Entries"
  /// section when hideTaskEntries is true.

  HasNonTaskLinkedEntriesProvider call(
    String id,
  ) =>
      HasNonTaskLinkedEntriesProvider._(argument: id, from: this);

  @override
  String toString() => r'hasNonTaskLinkedEntriesProvider';
}
