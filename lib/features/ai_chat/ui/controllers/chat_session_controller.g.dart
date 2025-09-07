// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatSessionControllerHash() =>
    r'aa5735d8d01f56a2c5d18bac0c58deb3aa38edd0';

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

abstract class _$ChatSessionController
    extends BuildlessAutoDisposeNotifier<ChatSessionUiModel> {
  late final String categoryId;

  ChatSessionUiModel build(
    String categoryId,
  );
}

/// See also [ChatSessionController].
@ProviderFor(ChatSessionController)
const chatSessionControllerProvider = ChatSessionControllerFamily();

/// See also [ChatSessionController].
class ChatSessionControllerFamily extends Family<ChatSessionUiModel> {
  /// See also [ChatSessionController].
  const ChatSessionControllerFamily();

  /// See also [ChatSessionController].
  ChatSessionControllerProvider call(
    String categoryId,
  ) {
    return ChatSessionControllerProvider(
      categoryId,
    );
  }

  @override
  ChatSessionControllerProvider getProviderOverride(
    covariant ChatSessionControllerProvider provider,
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
  String? get name => r'chatSessionControllerProvider';
}

/// See also [ChatSessionController].
class ChatSessionControllerProvider extends AutoDisposeNotifierProviderImpl<
    ChatSessionController, ChatSessionUiModel> {
  /// See also [ChatSessionController].
  ChatSessionControllerProvider(
    String categoryId,
  ) : this._internal(
          () => ChatSessionController()..categoryId = categoryId,
          from: chatSessionControllerProvider,
          name: r'chatSessionControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$chatSessionControllerHash,
          dependencies: ChatSessionControllerFamily._dependencies,
          allTransitiveDependencies:
              ChatSessionControllerFamily._allTransitiveDependencies,
          categoryId: categoryId,
        );

  ChatSessionControllerProvider._internal(
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
  ChatSessionUiModel runNotifierBuild(
    covariant ChatSessionController notifier,
  ) {
    return notifier.build(
      categoryId,
    );
  }

  @override
  Override overrideWith(ChatSessionController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChatSessionControllerProvider._internal(
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
  AutoDisposeNotifierProviderElement<ChatSessionController, ChatSessionUiModel>
      createElement() {
    return _ChatSessionControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatSessionControllerProvider &&
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
mixin ChatSessionControllerRef
    on AutoDisposeNotifierProviderRef<ChatSessionUiModel> {
  /// The parameter `categoryId` of this provider.
  String get categoryId;
}

class _ChatSessionControllerProviderElement
    extends AutoDisposeNotifierProviderElement<ChatSessionController,
        ChatSessionUiModel> with ChatSessionControllerRef {
  _ChatSessionControllerProviderElement(super.provider);

  @override
  String get categoryId => (origin as ChatSessionControllerProvider).categoryId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
