// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gemini_thinking_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controls whether Gemini reasoning/thinking content is surfaced inline.
///
/// UI can toggle this; CloudInferenceRepository reads it to override the
/// `includeThoughts` flag in the final thinking config.

@ProviderFor(GeminiIncludeThoughts)
final geminiIncludeThoughtsProvider = GeminiIncludeThoughtsProvider._();

/// Controls whether Gemini reasoning/thinking content is surfaced inline.
///
/// UI can toggle this; CloudInferenceRepository reads it to override the
/// `includeThoughts` flag in the final thinking config.
final class GeminiIncludeThoughtsProvider
    extends $NotifierProvider<GeminiIncludeThoughts, bool> {
  /// Controls whether Gemini reasoning/thinking content is surfaced inline.
  ///
  /// UI can toggle this; CloudInferenceRepository reads it to override the
  /// `includeThoughts` flag in the final thinking config.
  GeminiIncludeThoughtsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'geminiIncludeThoughtsProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$geminiIncludeThoughtsHash();

  @$internal
  @override
  GeminiIncludeThoughts create() => GeminiIncludeThoughts();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$geminiIncludeThoughtsHash() =>
    r'd32d47edf0fc43b5d9488cdcde4d0d73dfd0f5ec';

/// Controls whether Gemini reasoning/thinking content is surfaced inline.
///
/// UI can toggle this; CloudInferenceRepository reads it to override the
/// `includeThoughts` flag in the final thinking config.

abstract class _$GeminiIncludeThoughts extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<bool, bool>, bool, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}
