// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_sessions_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ChatSessionsController)
final chatSessionsControllerProvider = ChatSessionsControllerFamily._();

final class ChatSessionsControllerProvider
    extends $NotifierProvider<ChatSessionsController, ChatStateUiModel> {
  ChatSessionsControllerProvider._(
      {required ChatSessionsControllerFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'chatSessionsControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$chatSessionsControllerHash();

  @override
  String toString() {
    return r'chatSessionsControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ChatSessionsController create() => ChatSessionsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatStateUiModel value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatStateUiModel>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChatSessionsControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatSessionsControllerHash() =>
    r'c12d488bbd7639b12c974ab2901429e6db494bab';

final class ChatSessionsControllerFamily extends $Family
    with
        $ClassFamilyOverride<ChatSessionsController, ChatStateUiModel,
            ChatStateUiModel, ChatStateUiModel, String> {
  ChatSessionsControllerFamily._()
      : super(
          retry: null,
          name: r'chatSessionsControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  ChatSessionsControllerProvider call(
    String categoryId,
  ) =>
      ChatSessionsControllerProvider._(argument: categoryId, from: this);

  @override
  String toString() => r'chatSessionsControllerProvider';
}

abstract class _$ChatSessionsController extends $Notifier<ChatStateUiModel> {
  late final _$args = ref.$arg as String;
  String get categoryId => _$args;

  ChatStateUiModel build(
    String categoryId,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ChatStateUiModel, ChatStateUiModel>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<ChatStateUiModel, ChatStateUiModel>,
        ChatStateUiModel,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              _$args,
            ));
  }
}
