// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Riverpod controller for a single AI chat session.
///
/// Owns UI-facing state (messages, streaming flags, errors) and delegates
/// sending to `ChatRepository`. Enforces explicit model selection and manages
/// streaming placeholders for assistant messages.

@ProviderFor(ChatSessionController)
final chatSessionControllerProvider = ChatSessionControllerFamily._();

/// Riverpod controller for a single AI chat session.
///
/// Owns UI-facing state (messages, streaming flags, errors) and delegates
/// sending to `ChatRepository`. Enforces explicit model selection and manages
/// streaming placeholders for assistant messages.
final class ChatSessionControllerProvider
    extends $NotifierProvider<ChatSessionController, ChatSessionUiModel> {
  /// Riverpod controller for a single AI chat session.
  ///
  /// Owns UI-facing state (messages, streaming flags, errors) and delegates
  /// sending to `ChatRepository`. Enforces explicit model selection and manages
  /// streaming placeholders for assistant messages.
  ChatSessionControllerProvider._(
      {required ChatSessionControllerFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'chatSessionControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$chatSessionControllerHash();

  @override
  String toString() {
    return r'chatSessionControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ChatSessionController create() => ChatSessionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatSessionUiModel value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatSessionUiModel>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChatSessionControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatSessionControllerHash() =>
    r'90f79f43074b2e54248429fa3e7a2e0552ea3b38';

/// Riverpod controller for a single AI chat session.
///
/// Owns UI-facing state (messages, streaming flags, errors) and delegates
/// sending to `ChatRepository`. Enforces explicit model selection and manages
/// streaming placeholders for assistant messages.

final class ChatSessionControllerFamily extends $Family
    with
        $ClassFamilyOverride<ChatSessionController, ChatSessionUiModel,
            ChatSessionUiModel, ChatSessionUiModel, String> {
  ChatSessionControllerFamily._()
      : super(
          retry: null,
          name: r'chatSessionControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Riverpod controller for a single AI chat session.
  ///
  /// Owns UI-facing state (messages, streaming flags, errors) and delegates
  /// sending to `ChatRepository`. Enforces explicit model selection and manages
  /// streaming placeholders for assistant messages.

  ChatSessionControllerProvider call(
    String categoryId,
  ) =>
      ChatSessionControllerProvider._(argument: categoryId, from: this);

  @override
  String toString() => r'chatSessionControllerProvider';
}

/// Riverpod controller for a single AI chat session.
///
/// Owns UI-facing state (messages, streaming flags, errors) and delegates
/// sending to `ChatRepository`. Enforces explicit model selection and manages
/// streaming placeholders for assistant messages.

abstract class _$ChatSessionController extends $Notifier<ChatSessionUiModel> {
  late final _$args = ref.$arg as String;
  String get categoryId => _$args;

  ChatSessionUiModel build(
    String categoryId,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ChatSessionUiModel, ChatSessionUiModel>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<ChatSessionUiModel, ChatSessionUiModel>,
        ChatSessionUiModel,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              _$args,
            ));
  }
}
