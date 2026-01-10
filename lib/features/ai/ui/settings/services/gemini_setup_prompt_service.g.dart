// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gemini_setup_prompt_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Service that manages the automatic Gemini setup prompt for new users.
///
/// This service:
/// 1. Checks if any Gemini providers exist
/// 2. Tracks whether the user has dismissed the prompt
/// 3. Determines whether to show the setup prompt

@ProviderFor(GeminiSetupPromptService)
final geminiSetupPromptServiceProvider = GeminiSetupPromptServiceProvider._();

/// Service that manages the automatic Gemini setup prompt for new users.
///
/// This service:
/// 1. Checks if any Gemini providers exist
/// 2. Tracks whether the user has dismissed the prompt
/// 3. Determines whether to show the setup prompt
final class GeminiSetupPromptServiceProvider
    extends $AsyncNotifierProvider<GeminiSetupPromptService, bool> {
  /// Service that manages the automatic Gemini setup prompt for new users.
  ///
  /// This service:
  /// 1. Checks if any Gemini providers exist
  /// 2. Tracks whether the user has dismissed the prompt
  /// 3. Determines whether to show the setup prompt
  GeminiSetupPromptServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'geminiSetupPromptServiceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$geminiSetupPromptServiceHash();

  @$internal
  @override
  GeminiSetupPromptService create() => GeminiSetupPromptService();
}

String _$geminiSetupPromptServiceHash() =>
    r'50d09f13038f692b039544e54a391116065295b6';

/// Service that manages the automatic Gemini setup prompt for new users.
///
/// This service:
/// 1. Checks if any Gemini providers exist
/// 2. Tracks whether the user has dismissed the prompt
/// 3. Determines whether to show the setup prompt

abstract class _$GeminiSetupPromptService extends $AsyncNotifier<bool> {
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
