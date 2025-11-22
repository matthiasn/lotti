// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gemini_thinking_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$geminiIncludeThoughtsHash() =>
    r'd32d47edf0fc43b5d9488cdcde4d0d73dfd0f5ec';

/// Controls whether Gemini reasoning/thinking content is surfaced inline.
///
/// UI can toggle this; CloudInferenceRepository reads it to override the
/// `includeThoughts` flag in the final thinking config.
///
/// Copied from [GeminiIncludeThoughts].
@ProviderFor(GeminiIncludeThoughts)
final geminiIncludeThoughtsProvider =
    NotifierProvider<GeminiIncludeThoughts, bool>.internal(
  GeminiIncludeThoughts.new,
  name: r'geminiIncludeThoughtsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$geminiIncludeThoughtsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GeminiIncludeThoughts = Notifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
