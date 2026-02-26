// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'evolution_chat_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages the lifecycle of an evolution chat session for a specific template.
///
/// On [build], starts a new multi-turn session via
/// [TemplateEvolutionWorkflow.startSession]. The user can then send messages,
/// approve/reject proposals, and end the session.

@ProviderFor(EvolutionChatState)
final evolutionChatStateProvider = EvolutionChatStateFamily._();

/// Manages the lifecycle of an evolution chat session for a specific template.
///
/// On [build], starts a new multi-turn session via
/// [TemplateEvolutionWorkflow.startSession]. The user can then send messages,
/// approve/reject proposals, and end the session.
final class EvolutionChatStateProvider
    extends $AsyncNotifierProvider<EvolutionChatState, EvolutionChatData> {
  /// Manages the lifecycle of an evolution chat session for a specific template.
  ///
  /// On [build], starts a new multi-turn session via
  /// [TemplateEvolutionWorkflow.startSession]. The user can then send messages,
  /// approve/reject proposals, and end the session.
  EvolutionChatStateProvider._(
      {required EvolutionChatStateFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'evolutionChatStateProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$evolutionChatStateHash();

  @override
  String toString() {
    return r'evolutionChatStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  EvolutionChatState create() => EvolutionChatState();

  @override
  bool operator ==(Object other) {
    return other is EvolutionChatStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$evolutionChatStateHash() =>
    r'd766647ccabeea76ec253feb8856cd911e61029a';

/// Manages the lifecycle of an evolution chat session for a specific template.
///
/// On [build], starts a new multi-turn session via
/// [TemplateEvolutionWorkflow.startSession]. The user can then send messages,
/// approve/reject proposals, and end the session.

final class EvolutionChatStateFamily extends $Family
    with
        $ClassFamilyOverride<EvolutionChatState, AsyncValue<EvolutionChatData>,
            EvolutionChatData, FutureOr<EvolutionChatData>, String> {
  EvolutionChatStateFamily._()
      : super(
          retry: null,
          name: r'evolutionChatStateProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Manages the lifecycle of an evolution chat session for a specific template.
  ///
  /// On [build], starts a new multi-turn session via
  /// [TemplateEvolutionWorkflow.startSession]. The user can then send messages,
  /// approve/reject proposals, and end the session.

  EvolutionChatStateProvider call(
    String templateId,
  ) =>
      EvolutionChatStateProvider._(argument: templateId, from: this);

  @override
  String toString() => r'evolutionChatStateProvider';
}

/// Manages the lifecycle of an evolution chat session for a specific template.
///
/// On [build], starts a new multi-turn session via
/// [TemplateEvolutionWorkflow.startSession]. The user can then send messages,
/// approve/reject proposals, and end the session.

abstract class _$EvolutionChatState extends $AsyncNotifier<EvolutionChatData> {
  late final _$args = ref.$arg as String;
  String get templateId => _$args;

  FutureOr<EvolutionChatData> build(
    String templateId,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<EvolutionChatData>, EvolutionChatData>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<EvolutionChatData>, EvolutionChatData>,
        AsyncValue<EvolutionChatData>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              _$args,
            ));
  }
}
