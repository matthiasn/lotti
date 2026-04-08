// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'soul_evolution_chat_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages the lifecycle of a standalone soul evolution chat session.
///
/// Parameterized by [soulId]. On [build], starts a new multi-turn session
/// via [TemplateEvolutionWorkflow.startSoulSession]. The user can then send
/// messages, approve/reject soul proposals, and end the session.

@ProviderFor(SoulEvolutionChatState)
final soulEvolutionChatStateProvider = SoulEvolutionChatStateFamily._();

/// Manages the lifecycle of a standalone soul evolution chat session.
///
/// Parameterized by [soulId]. On [build], starts a new multi-turn session
/// via [TemplateEvolutionWorkflow.startSoulSession]. The user can then send
/// messages, approve/reject soul proposals, and end the session.
final class SoulEvolutionChatStateProvider
    extends $AsyncNotifierProvider<SoulEvolutionChatState, EvolutionChatData> {
  /// Manages the lifecycle of a standalone soul evolution chat session.
  ///
  /// Parameterized by [soulId]. On [build], starts a new multi-turn session
  /// via [TemplateEvolutionWorkflow.startSoulSession]. The user can then send
  /// messages, approve/reject soul proposals, and end the session.
  SoulEvolutionChatStateProvider._({
    required SoulEvolutionChatStateFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'soulEvolutionChatStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$soulEvolutionChatStateHash();

  @override
  String toString() {
    return r'soulEvolutionChatStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SoulEvolutionChatState create() => SoulEvolutionChatState();

  @override
  bool operator ==(Object other) {
    return other is SoulEvolutionChatStateProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$soulEvolutionChatStateHash() =>
    r'dd36355dabcd849234b5235a53a34539d98e88a2';

/// Manages the lifecycle of a standalone soul evolution chat session.
///
/// Parameterized by [soulId]. On [build], starts a new multi-turn session
/// via [TemplateEvolutionWorkflow.startSoulSession]. The user can then send
/// messages, approve/reject soul proposals, and end the session.

final class SoulEvolutionChatStateFamily extends $Family
    with
        $ClassFamilyOverride<
          SoulEvolutionChatState,
          AsyncValue<EvolutionChatData>,
          EvolutionChatData,
          FutureOr<EvolutionChatData>,
          String
        > {
  SoulEvolutionChatStateFamily._()
    : super(
        retry: null,
        name: r'soulEvolutionChatStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Manages the lifecycle of a standalone soul evolution chat session.
  ///
  /// Parameterized by [soulId]. On [build], starts a new multi-turn session
  /// via [TemplateEvolutionWorkflow.startSoulSession]. The user can then send
  /// messages, approve/reject soul proposals, and end the session.

  SoulEvolutionChatStateProvider call(String soulId) =>
      SoulEvolutionChatStateProvider._(argument: soulId, from: this);

  @override
  String toString() => r'soulEvolutionChatStateProvider';
}

/// Manages the lifecycle of a standalone soul evolution chat session.
///
/// Parameterized by [soulId]. On [build], starts a new multi-turn session
/// via [TemplateEvolutionWorkflow.startSoulSession]. The user can then send
/// messages, approve/reject soul proposals, and end the session.

abstract class _$SoulEvolutionChatState
    extends $AsyncNotifier<EvolutionChatData> {
  late final _$args = ref.$arg as String;
  String get soulId => _$args;

  FutureOr<EvolutionChatData> build(String soulId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<EvolutionChatData>, EvolutionChatData>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<EvolutionChatData>, EvolutionChatData>,
              AsyncValue<EvolutionChatData>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
