// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_sessions_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatSessionsControllerHash() =>
    r'2013150f1549934adbc96189b648816c239adde1';

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

abstract class _$ChatSessionsController
    extends BuildlessAutoDisposeNotifier<ChatStateUiModel> {
  late final String categoryId;

  ChatStateUiModel build(
    String categoryId,
  );
}

/// See also [ChatSessionsController].
@ProviderFor(ChatSessionsController)
const chatSessionsControllerProvider = ChatSessionsControllerFamily();

/// See also [ChatSessionsController].
class ChatSessionsControllerFamily extends Family<ChatStateUiModel> {
  /// See also [ChatSessionsController].
  const ChatSessionsControllerFamily();

  /// See also [ChatSessionsController].
  ChatSessionsControllerProvider call(
    String categoryId,
  ) {
    return ChatSessionsControllerProvider(
      categoryId,
    );
  }

  @override
  ChatSessionsControllerProvider getProviderOverride(
    covariant ChatSessionsControllerProvider provider,
  ) {
    return call(
      provider.categoryId,
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
  String? get name => r'chatSessionsControllerProvider';
}

/// See also [ChatSessionsController].
class ChatSessionsControllerProvider extends AutoDisposeNotifierProviderImpl<
    ChatSessionsController, ChatStateUiModel> {
  /// See also [ChatSessionsController].
  ChatSessionsControllerProvider(
    String categoryId,
  ) : this._internal(
          () => ChatSessionsController()..categoryId = categoryId,
          from: chatSessionsControllerProvider,
          name: r'chatSessionsControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$chatSessionsControllerHash,
          dependencies: ChatSessionsControllerFamily._dependencies,
          allTransitiveDependencies:
              ChatSessionsControllerFamily._allTransitiveDependencies,
          categoryId: categoryId,
        );

  ChatSessionsControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.categoryId,
  }) : super.internal();

  final String categoryId;

  @override
  ChatStateUiModel runNotifierBuild(
    covariant ChatSessionsController notifier,
  ) {
    return notifier.build(
      categoryId,
    );
  }

  @override
  Override overrideWith(ChatSessionsController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChatSessionsControllerProvider._internal(
        () => create()..categoryId = categoryId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        categoryId: categoryId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<ChatSessionsController, ChatStateUiModel>
      createElement() {
    return _ChatSessionsControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatSessionsControllerProvider &&
        other.categoryId == categoryId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, categoryId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ChatSessionsControllerRef
    on AutoDisposeNotifierProviderRef<ChatStateUiModel> {
  /// The parameter `categoryId` of this provider.
  String get categoryId;
}

class _ChatSessionsControllerProviderElement
    extends AutoDisposeNotifierProviderElement<ChatSessionsController,
        ChatStateUiModel> with ChatSessionsControllerRef {
  _ChatSessionsControllerProviderElement(super.provider);

  @override
  String get categoryId =>
      (origin as ChatSessionsControllerProvider).categoryId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
