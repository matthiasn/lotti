// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_page_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$journalPageControllerHash() =>
    r'4bbafb33f63228c13db0ad66940d5a0085ed47ec';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$JournalPageController
    extends BuildlessNotifier<JournalPageState> {
  late final bool showTasks;

  JournalPageState build(
    bool showTasks,
  );
}

/// Controller for managing journal/tasks page state.
///
/// Uses a family provider pattern with showTasks as the family key.
/// keepAlive: true to preserve state when switching tabs.
///
/// Copied from [JournalPageController].
@ProviderFor(JournalPageController)
const journalPageControllerProvider = JournalPageControllerFamily();

/// Controller for managing journal/tasks page state.
///
/// Uses a family provider pattern with showTasks as the family key.
/// keepAlive: true to preserve state when switching tabs.
///
/// Copied from [JournalPageController].
class JournalPageControllerFamily extends Family<JournalPageState> {
  /// Controller for managing journal/tasks page state.
  ///
  /// Uses a family provider pattern with showTasks as the family key.
  /// keepAlive: true to preserve state when switching tabs.
  ///
  /// Copied from [JournalPageController].
  const JournalPageControllerFamily();

  /// Controller for managing journal/tasks page state.
  ///
  /// Uses a family provider pattern with showTasks as the family key.
  /// keepAlive: true to preserve state when switching tabs.
  ///
  /// Copied from [JournalPageController].
  JournalPageControllerProvider call(
    bool showTasks,
  ) {
    return JournalPageControllerProvider(
      showTasks,
    );
  }

  @override
  JournalPageControllerProvider getProviderOverride(
    covariant JournalPageControllerProvider provider,
  ) {
    return call(
      provider.showTasks,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'journalPageControllerProvider';
}

/// Controller for managing journal/tasks page state.
///
/// Uses a family provider pattern with showTasks as the family key.
/// keepAlive: true to preserve state when switching tabs.
///
/// Copied from [JournalPageController].
class JournalPageControllerProvider
    extends NotifierProviderImpl<JournalPageController, JournalPageState> {
  /// Controller for managing journal/tasks page state.
  ///
  /// Uses a family provider pattern with showTasks as the family key.
  /// keepAlive: true to preserve state when switching tabs.
  ///
  /// Copied from [JournalPageController].
  JournalPageControllerProvider(
    bool showTasks,
  ) : this._internal(
          () => JournalPageController()..showTasks = showTasks,
          from: journalPageControllerProvider,
          name: r'journalPageControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$journalPageControllerHash,
          dependencies: JournalPageControllerFamily._dependencies,
          allTransitiveDependencies:
              JournalPageControllerFamily._allTransitiveDependencies,
          showTasks: showTasks,
        );

  JournalPageControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.showTasks,
  }) : super.internal();

  final bool showTasks;

  @override
  JournalPageState runNotifierBuild(
    covariant JournalPageController notifier,
  ) {
    return notifier.build(
      showTasks,
    );
  }

  @override
  Override overrideWith(JournalPageController Function() create) {
    return ProviderOverride(
      origin: this,
      override: JournalPageControllerProvider._internal(
        () => create()..showTasks = showTasks,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        showTasks: showTasks,
      ),
    );
  }

  @override
  NotifierProviderElement<JournalPageController, JournalPageState>
      createElement() {
    return _JournalPageControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is JournalPageControllerProvider &&
        other.showTasks == showTasks;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, showTasks.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin JournalPageControllerRef on NotifierProviderRef<JournalPageState> {
  /// The parameter `showTasks` of this provider.
  bool get showTasks;
}

class _JournalPageControllerProviderElement
    extends NotifierProviderElement<JournalPageController, JournalPageState>
    with JournalPageControllerRef {
  _JournalPageControllerProviderElement(super.provider);

  @override
  bool get showTasks => (origin as JournalPageControllerProvider).showTasks;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
