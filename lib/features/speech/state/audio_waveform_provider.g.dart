// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_waveform_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$audioWaveformHash() => r'6b355266d3590bbdf948e9f0b0b89efda13b61fa';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [audioWaveform].
@ProviderFor(audioWaveform)
const audioWaveformProvider = AudioWaveformFamily();

/// See also [audioWaveform].
class AudioWaveformFamily extends Family<AsyncValue<AudioWaveformData?>> {
  /// See also [audioWaveform].
  const AudioWaveformFamily();

  /// See also [audioWaveform].
  AudioWaveformProvider call(
    AudioWaveformRequest request,
  ) {
    return AudioWaveformProvider(
      request,
    );
  }

  @override
  AudioWaveformProvider getProviderOverride(
    covariant AudioWaveformProvider provider,
  ) {
    return call(
      provider.request,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'audioWaveformProvider';
}

/// See also [audioWaveform].
class AudioWaveformProvider
    extends AutoDisposeFutureProvider<AudioWaveformData?> {
  /// See also [audioWaveform].
  AudioWaveformProvider(
    AudioWaveformRequest request,
  ) : this._internal(
          (ref) => audioWaveform(
            ref as AudioWaveformRef,
            request,
          ),
          from: audioWaveformProvider,
          name: r'audioWaveformProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$audioWaveformHash,
          dependencies: AudioWaveformFamily._dependencies,
          allTransitiveDependencies:
              AudioWaveformFamily._allTransitiveDependencies,
          request: request,
        );

  AudioWaveformProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.request,
  }) : super.internal();

  final AudioWaveformRequest request;

  @override
  Override overrideWith(
    FutureOr<AudioWaveformData?> Function(AudioWaveformRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AudioWaveformProvider._internal(
        (ref) => create(ref as AudioWaveformRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        request: request,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<AudioWaveformData?> createElement() {
    return _AudioWaveformProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AudioWaveformProvider && other.request == request;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, request.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AudioWaveformRef on AutoDisposeFutureProviderRef<AudioWaveformData?> {
  /// The parameter `request` of this provider.
  AudioWaveformRequest get request;
}

class _AudioWaveformProviderElement
    extends AutoDisposeFutureProviderElement<AudioWaveformData?>
    with AudioWaveformRef {
  _AudioWaveformProviderElement(super.provider);

  @override
  AudioWaveformRequest get request => (origin as AudioWaveformProvider).request;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
