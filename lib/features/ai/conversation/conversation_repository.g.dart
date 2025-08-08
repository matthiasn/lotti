// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$conversationEventsHash() =>
    r'985b20700b7fbbf678c18053543c4e2bbbdfda09';

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

/// Provider for accessing conversation events
///
/// Copied from [conversationEvents].
@ProviderFor(conversationEvents)
const conversationEventsProvider = ConversationEventsFamily();

/// Provider for accessing conversation events
///
/// Copied from [conversationEvents].
class ConversationEventsFamily extends Family<AsyncValue<ConversationEvent>> {
  /// Provider for accessing conversation events
  ///
  /// Copied from [conversationEvents].
  const ConversationEventsFamily();

  /// Provider for accessing conversation events
  ///
  /// Copied from [conversationEvents].
  ConversationEventsProvider call(
    String conversationId,
  ) {
    return ConversationEventsProvider(
      conversationId,
    );
  }

  @override
  ConversationEventsProvider getProviderOverride(
    covariant ConversationEventsProvider provider,
  ) {
    return call(
      provider.conversationId,
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
  String? get name => r'conversationEventsProvider';
}

/// Provider for accessing conversation events
///
/// Copied from [conversationEvents].
class ConversationEventsProvider
    extends AutoDisposeStreamProvider<ConversationEvent> {
  /// Provider for accessing conversation events
  ///
  /// Copied from [conversationEvents].
  ConversationEventsProvider(
    String conversationId,
  ) : this._internal(
          (ref) => conversationEvents(
            ref as ConversationEventsRef,
            conversationId,
          ),
          from: conversationEventsProvider,
          name: r'conversationEventsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$conversationEventsHash,
          dependencies: ConversationEventsFamily._dependencies,
          allTransitiveDependencies:
              ConversationEventsFamily._allTransitiveDependencies,
          conversationId: conversationId,
        );

  ConversationEventsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.conversationId,
  }) : super.internal();

  final String conversationId;

  @override
  Override overrideWith(
    Stream<ConversationEvent> Function(ConversationEventsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ConversationEventsProvider._internal(
        (ref) => create(ref as ConversationEventsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        conversationId: conversationId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<ConversationEvent> createElement() {
    return _ConversationEventsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationEventsProvider &&
        other.conversationId == conversationId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, conversationId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ConversationEventsRef on AutoDisposeStreamProviderRef<ConversationEvent> {
  /// The parameter `conversationId` of this provider.
  String get conversationId;
}

class _ConversationEventsProviderElement
    extends AutoDisposeStreamProviderElement<ConversationEvent>
    with ConversationEventsRef {
  _ConversationEventsProviderElement(super.provider);

  @override
  String get conversationId =>
      (origin as ConversationEventsProvider).conversationId;
}

String _$conversationMessagesHash() =>
    r'ff023f0f613dafddbf533de2f684bc9953d444bf';

/// Provider for conversation messages
///
/// Copied from [conversationMessages].
@ProviderFor(conversationMessages)
const conversationMessagesProvider = ConversationMessagesFamily();

/// Provider for conversation messages
///
/// Copied from [conversationMessages].
class ConversationMessagesFamily extends Family<List<ChatCompletionMessage>> {
  /// Provider for conversation messages
  ///
  /// Copied from [conversationMessages].
  const ConversationMessagesFamily();

  /// Provider for conversation messages
  ///
  /// Copied from [conversationMessages].
  ConversationMessagesProvider call(
    String conversationId,
  ) {
    return ConversationMessagesProvider(
      conversationId,
    );
  }

  @override
  ConversationMessagesProvider getProviderOverride(
    covariant ConversationMessagesProvider provider,
  ) {
    return call(
      provider.conversationId,
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
  String? get name => r'conversationMessagesProvider';
}

/// Provider for conversation messages
///
/// Copied from [conversationMessages].
class ConversationMessagesProvider
    extends AutoDisposeProvider<List<ChatCompletionMessage>> {
  /// Provider for conversation messages
  ///
  /// Copied from [conversationMessages].
  ConversationMessagesProvider(
    String conversationId,
  ) : this._internal(
          (ref) => conversationMessages(
            ref as ConversationMessagesRef,
            conversationId,
          ),
          from: conversationMessagesProvider,
          name: r'conversationMessagesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$conversationMessagesHash,
          dependencies: ConversationMessagesFamily._dependencies,
          allTransitiveDependencies:
              ConversationMessagesFamily._allTransitiveDependencies,
          conversationId: conversationId,
        );

  ConversationMessagesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.conversationId,
  }) : super.internal();

  final String conversationId;

  @override
  Override overrideWith(
    List<ChatCompletionMessage> Function(ConversationMessagesRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ConversationMessagesProvider._internal(
        (ref) => create(ref as ConversationMessagesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        conversationId: conversationId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<List<ChatCompletionMessage>> createElement() {
    return _ConversationMessagesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationMessagesProvider &&
        other.conversationId == conversationId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, conversationId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ConversationMessagesRef
    on AutoDisposeProviderRef<List<ChatCompletionMessage>> {
  /// The parameter `conversationId` of this provider.
  String get conversationId;
}

class _ConversationMessagesProviderElement
    extends AutoDisposeProviderElement<List<ChatCompletionMessage>>
    with ConversationMessagesRef {
  _ConversationMessagesProviderElement(super.provider);

  @override
  String get conversationId =>
      (origin as ConversationMessagesProvider).conversationId;
}

String _$conversationRepositoryHash() =>
    r'7b2a5a7a648362a2060b48304555fef87b7f56e8';

/// Repository for managing AI conversations
///
/// Copied from [ConversationRepository].
@ProviderFor(ConversationRepository)
final conversationRepositoryProvider =
    AutoDisposeNotifierProvider<ConversationRepository, void>.internal(
  ConversationRepository.new,
  name: r'conversationRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$conversationRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ConversationRepository = AutoDisposeNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
