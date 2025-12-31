// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Repository for managing AI conversations.
///
/// Streaming expectations for tool calls (for providers and tests):
/// - Tool calls may arrive across multiple streamed chunks. The repository stitches
///   chunks using a stable `id` or `index` per tool call and accumulates `function.arguments`.
/// - Providers emitting OpenAI‑style deltas should keep id/index stable across chunks.
/// - In tests, you can bypass stream chunking complexity by stubbing `sendMessage` and directly
///   invoking the provided `ConversationStrategy` with predefined
///   `ChatCompletionMessageToolCall` objects. This preserves the strategy/handler execution path
///   while avoiding brittle mock setups.

@ProviderFor(ConversationRepository)
final conversationRepositoryProvider = ConversationRepositoryProvider._();

/// Repository for managing AI conversations.
///
/// Streaming expectations for tool calls (for providers and tests):
/// - Tool calls may arrive across multiple streamed chunks. The repository stitches
///   chunks using a stable `id` or `index` per tool call and accumulates `function.arguments`.
/// - Providers emitting OpenAI‑style deltas should keep id/index stable across chunks.
/// - In tests, you can bypass stream chunking complexity by stubbing `sendMessage` and directly
///   invoking the provided `ConversationStrategy` with predefined
///   `ChatCompletionMessageToolCall` objects. This preserves the strategy/handler execution path
///   while avoiding brittle mock setups.
final class ConversationRepositoryProvider
    extends $NotifierProvider<ConversationRepository, void> {
  /// Repository for managing AI conversations.
  ///
  /// Streaming expectations for tool calls (for providers and tests):
  /// - Tool calls may arrive across multiple streamed chunks. The repository stitches
  ///   chunks using a stable `id` or `index` per tool call and accumulates `function.arguments`.
  /// - Providers emitting OpenAI‑style deltas should keep id/index stable across chunks.
  /// - In tests, you can bypass stream chunking complexity by stubbing `sendMessage` and directly
  ///   invoking the provided `ConversationStrategy` with predefined
  ///   `ChatCompletionMessageToolCall` objects. This preserves the strategy/handler execution path
  ///   while avoiding brittle mock setups.
  ConversationRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'conversationRepositoryProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$conversationRepositoryHash();

  @$internal
  @override
  ConversationRepository create() => ConversationRepository();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$conversationRepositoryHash() =>
    r'e5fc85679c5ceec0439a6bf003d50758858b8296';

/// Repository for managing AI conversations.
///
/// Streaming expectations for tool calls (for providers and tests):
/// - Tool calls may arrive across multiple streamed chunks. The repository stitches
///   chunks using a stable `id` or `index` per tool call and accumulates `function.arguments`.
/// - Providers emitting OpenAI‑style deltas should keep id/index stable across chunks.
/// - In tests, you can bypass stream chunking complexity by stubbing `sendMessage` and directly
///   invoking the provided `ConversationStrategy` with predefined
///   `ChatCompletionMessageToolCall` objects. This preserves the strategy/handler execution path
///   while avoiding brittle mock setups.

abstract class _$ConversationRepository extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<void, void>, void, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}

/// Provider for accessing conversation events

@ProviderFor(conversationEvents)
final conversationEventsProvider = ConversationEventsFamily._();

/// Provider for accessing conversation events

final class ConversationEventsProvider extends $FunctionalProvider<
        AsyncValue<ConversationEvent>,
        ConversationEvent,
        Stream<ConversationEvent>>
    with
        $FutureModifier<ConversationEvent>,
        $StreamProvider<ConversationEvent> {
  /// Provider for accessing conversation events
  ConversationEventsProvider._(
      {required ConversationEventsFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'conversationEventsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$conversationEventsHash();

  @override
  String toString() {
    return r'conversationEventsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<ConversationEvent> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<ConversationEvent> create(Ref ref) {
    final argument = this.argument as String;
    return conversationEvents(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationEventsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$conversationEventsHash() =>
    r'7359731041c3c8e6b9e96c3362b3ccf815f59659';

/// Provider for accessing conversation events

final class ConversationEventsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<ConversationEvent>, String> {
  ConversationEventsFamily._()
      : super(
          retry: null,
          name: r'conversationEventsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Provider for accessing conversation events

  ConversationEventsProvider call(
    String conversationId,
  ) =>
      ConversationEventsProvider._(argument: conversationId, from: this);

  @override
  String toString() => r'conversationEventsProvider';
}

/// Provider for conversation messages

@ProviderFor(conversationMessages)
final conversationMessagesProvider = ConversationMessagesFamily._();

/// Provider for conversation messages

final class ConversationMessagesProvider extends $FunctionalProvider<
    List<ChatCompletionMessage>,
    List<ChatCompletionMessage>,
    List<ChatCompletionMessage>> with $Provider<List<ChatCompletionMessage>> {
  /// Provider for conversation messages
  ConversationMessagesProvider._(
      {required ConversationMessagesFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'conversationMessagesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$conversationMessagesHash();

  @override
  String toString() {
    return r'conversationMessagesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<List<ChatCompletionMessage>> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<ChatCompletionMessage> create(Ref ref) {
    final argument = this.argument as String;
    return conversationMessages(
      ref,
      argument,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ChatCompletionMessage> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ChatCompletionMessage>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationMessagesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$conversationMessagesHash() =>
    r'ff023f0f613dafddbf533de2f684bc9953d444bf';

/// Provider for conversation messages

final class ConversationMessagesFamily extends $Family
    with $FunctionalFamilyOverride<List<ChatCompletionMessage>, String> {
  ConversationMessagesFamily._()
      : super(
          retry: null,
          name: r'conversationMessagesProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Provider for conversation messages

  ConversationMessagesProvider call(
    String conversationId,
  ) =>
      ConversationMessagesProvider._(argument: conversationId, from: this);

  @override
  String toString() => r'conversationMessagesProvider';
}
