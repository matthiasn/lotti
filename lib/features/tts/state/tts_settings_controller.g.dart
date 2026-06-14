// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the user's TTS preferences — selected voice, model, and playback
/// speed — persisted locally via [SettingsDb].
///
/// These are device-local preferences (which voice sounds best on this
/// device, how fast to read), so unlike theming they are intentionally not
/// enqueued for cross-device sync.

@ProviderFor(TtsSettingsController)
final ttsSettingsControllerProvider = TtsSettingsControllerProvider._();

/// Holds the user's TTS preferences — selected voice, model, and playback
/// speed — persisted locally via [SettingsDb].
///
/// These are device-local preferences (which voice sounds best on this
/// device, how fast to read), so unlike theming they are intentionally not
/// enqueued for cross-device sync.
final class TtsSettingsControllerProvider
    extends $NotifierProvider<TtsSettingsController, TtsSettings> {
  /// Holds the user's TTS preferences — selected voice, model, and playback
  /// speed — persisted locally via [SettingsDb].
  ///
  /// These are device-local preferences (which voice sounds best on this
  /// device, how fast to read), so unlike theming they are intentionally not
  /// enqueued for cross-device sync.
  TtsSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ttsSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ttsSettingsControllerHash();

  @$internal
  @override
  TtsSettingsController create() => TtsSettingsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TtsSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TtsSettings>(value),
    );
  }
}

String _$ttsSettingsControllerHash() =>
    r'ed53678067a3f0102e1b15a1eafc2be4c1165526';

/// Holds the user's TTS preferences — selected voice, model, and playback
/// speed — persisted locally via [SettingsDb].
///
/// These are device-local preferences (which voice sounds best on this
/// device, how fast to read), so unlike theming they are intentionally not
/// enqueued for cross-device sync.

abstract class _$TtsSettingsController extends $Notifier<TtsSettings> {
  TtsSettings build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<TtsSettings, TtsSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TtsSettings, TtsSettings>,
              TtsSettings,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
