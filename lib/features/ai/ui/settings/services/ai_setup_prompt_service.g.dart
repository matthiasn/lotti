// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_setup_prompt_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Service that manages the automatic AI setup prompt for new users.
///
/// This service:
/// 1. Checks if any supported AI providers (Gemini or OpenAI) exist
/// 2. Tracks whether the user has dismissed the prompt permanently
/// 3. Waits for What's New modal to be dismissed first
/// 4. Determines whether to show the setup prompt

@ProviderFor(AiSetupPromptService)
final aiSetupPromptServiceProvider = AiSetupPromptServiceProvider._();

/// Service that manages the automatic AI setup prompt for new users.
///
/// This service:
/// 1. Checks if any supported AI providers (Gemini or OpenAI) exist
/// 2. Tracks whether the user has dismissed the prompt permanently
/// 3. Waits for What's New modal to be dismissed first
/// 4. Determines whether to show the setup prompt
final class AiSetupPromptServiceProvider
    extends $AsyncNotifierProvider<AiSetupPromptService, bool> {
  /// Service that manages the automatic AI setup prompt for new users.
  ///
  /// This service:
  /// 1. Checks if any supported AI providers (Gemini or OpenAI) exist
  /// 2. Tracks whether the user has dismissed the prompt permanently
  /// 3. Waits for What's New modal to be dismissed first
  /// 4. Determines whether to show the setup prompt
  AiSetupPromptServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'aiSetupPromptServiceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$aiSetupPromptServiceHash();

  @$internal
  @override
  AiSetupPromptService create() => AiSetupPromptService();
}

String _$aiSetupPromptServiceHash() =>
    r'a393e9e1eb9e17b14c5e9ffedee4625cde3239d7';

/// Service that manages the automatic AI setup prompt for new users.
///
/// This service:
/// 1. Checks if any supported AI providers (Gemini or OpenAI) exist
/// 2. Tracks whether the user has dismissed the prompt permanently
/// 3. Waits for What's New modal to be dismissed first
/// 4. Determines whether to show the setup prompt

abstract class _$AiSetupPromptService extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<bool>, bool>,
        AsyncValue<bool>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
