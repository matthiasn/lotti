// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_waveform_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Resolves the waveform data for a [AudioWaveformRequest] via
/// [AudioWaveformService] (disk cache + extraction), returning `null` when the
/// source file is missing or extraction fails.
///
/// Extraction is comparatively expensive, so the result is pinned with a
/// 15-minute keep-alive: the provider stays cached while a player card is
/// repeatedly scrolled in/out of view, then auto-releases so long sessions
/// don't accumulate amplitude lists for every clip ever shown. The keep-alive
/// link is closed early on dispose by cancelling the timer.

@ProviderFor(audioWaveform)
final audioWaveformProvider = AudioWaveformFamily._();

/// Resolves the waveform data for a [AudioWaveformRequest] via
/// [AudioWaveformService] (disk cache + extraction), returning `null` when the
/// source file is missing or extraction fails.
///
/// Extraction is comparatively expensive, so the result is pinned with a
/// 15-minute keep-alive: the provider stays cached while a player card is
/// repeatedly scrolled in/out of view, then auto-releases so long sessions
/// don't accumulate amplitude lists for every clip ever shown. The keep-alive
/// link is closed early on dispose by cancelling the timer.

final class AudioWaveformProvider
    extends
        $FunctionalProvider<
          AsyncValue<AudioWaveformData?>,
          AudioWaveformData?,
          FutureOr<AudioWaveformData?>
        >
    with
        $FutureModifier<AudioWaveformData?>,
        $FutureProvider<AudioWaveformData?> {
  /// Resolves the waveform data for a [AudioWaveformRequest] via
  /// [AudioWaveformService] (disk cache + extraction), returning `null` when the
  /// source file is missing or extraction fails.
  ///
  /// Extraction is comparatively expensive, so the result is pinned with a
  /// 15-minute keep-alive: the provider stays cached while a player card is
  /// repeatedly scrolled in/out of view, then auto-releases so long sessions
  /// don't accumulate amplitude lists for every clip ever shown. The keep-alive
  /// link is closed early on dispose by cancelling the timer.
  AudioWaveformProvider._({
    required AudioWaveformFamily super.from,
    required AudioWaveformRequest super.argument,
  }) : super(
         retry: null,
         name: r'audioWaveformProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$audioWaveformHash();

  @override
  String toString() {
    return r'audioWaveformProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<AudioWaveformData?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AudioWaveformData?> create(Ref ref) {
    final argument = this.argument as AudioWaveformRequest;
    return audioWaveform(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AudioWaveformProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$audioWaveformHash() => r'6b355266d3590bbdf948e9f0b0b89efda13b61fa';

/// Resolves the waveform data for a [AudioWaveformRequest] via
/// [AudioWaveformService] (disk cache + extraction), returning `null` when the
/// source file is missing or extraction fails.
///
/// Extraction is comparatively expensive, so the result is pinned with a
/// 15-minute keep-alive: the provider stays cached while a player card is
/// repeatedly scrolled in/out of view, then auto-releases so long sessions
/// don't accumulate amplitude lists for every clip ever shown. The keep-alive
/// link is closed early on dispose by cancelling the timer.

final class AudioWaveformFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<AudioWaveformData?>,
          AudioWaveformRequest
        > {
  AudioWaveformFamily._()
    : super(
        retry: null,
        name: r'audioWaveformProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Resolves the waveform data for a [AudioWaveformRequest] via
  /// [AudioWaveformService] (disk cache + extraction), returning `null` when the
  /// source file is missing or extraction fails.
  ///
  /// Extraction is comparatively expensive, so the result is pinned with a
  /// 15-minute keep-alive: the provider stays cached while a player card is
  /// repeatedly scrolled in/out of view, then auto-releases so long sessions
  /// don't accumulate amplitude lists for every clip ever shown. The keep-alive
  /// link is closed early on dispose by cancelling the timer.

  AudioWaveformProvider call(AudioWaveformRequest request) =>
      AudioWaveformProvider._(argument: request, from: this);

  @override
  String toString() => r'audioWaveformProvider';
}
