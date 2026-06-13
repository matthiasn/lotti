// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_playback_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Orchestrates a single TTS utterance — ensure model → synthesize → play —
/// and exposes the [TtsPlaybackState] that the AI-card header's play button
/// binds to.
///
/// App-wide (keepAlive) so playback survives header rebuilds and only one
/// utterance plays at a time. [TtsPlaybackState.sourceId] tracks which content
/// is active so each header reflects only its own play/stop state.

@ProviderFor(TtsPlaybackController)
final ttsPlaybackControllerProvider = TtsPlaybackControllerProvider._();

/// Orchestrates a single TTS utterance — ensure model → synthesize → play —
/// and exposes the [TtsPlaybackState] that the AI-card header's play button
/// binds to.
///
/// App-wide (keepAlive) so playback survives header rebuilds and only one
/// utterance plays at a time. [TtsPlaybackState.sourceId] tracks which content
/// is active so each header reflects only its own play/stop state.
final class TtsPlaybackControllerProvider
    extends $NotifierProvider<TtsPlaybackController, TtsPlaybackState> {
  /// Orchestrates a single TTS utterance — ensure model → synthesize → play —
  /// and exposes the [TtsPlaybackState] that the AI-card header's play button
  /// binds to.
  ///
  /// App-wide (keepAlive) so playback survives header rebuilds and only one
  /// utterance plays at a time. [TtsPlaybackState.sourceId] tracks which content
  /// is active so each header reflects only its own play/stop state.
  TtsPlaybackControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ttsPlaybackControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ttsPlaybackControllerHash();

  @$internal
  @override
  TtsPlaybackController create() => TtsPlaybackController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TtsPlaybackState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TtsPlaybackState>(value),
    );
  }
}

String _$ttsPlaybackControllerHash() =>
    r'05988532496d9412f2240bc9fd319430c3bf228e';

/// Orchestrates a single TTS utterance — ensure model → synthesize → play —
/// and exposes the [TtsPlaybackState] that the AI-card header's play button
/// binds to.
///
/// App-wide (keepAlive) so playback survives header rebuilds and only one
/// utterance plays at a time. [TtsPlaybackState.sourceId] tracks which content
/// is active so each header reflects only its own play/stop state.

abstract class _$TtsPlaybackController extends $Notifier<TtsPlaybackState> {
  TtsPlaybackState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<TtsPlaybackState, TtsPlaybackState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TtsPlaybackState, TtsPlaybackState>,
              TtsPlaybackState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
