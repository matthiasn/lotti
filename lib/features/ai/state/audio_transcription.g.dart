// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_transcription.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$audioTranscriptionControllerHash() =>
    r'679f95340335aa002592c96ca8d756f40ff435fd';

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

abstract class _$AudioTranscriptionController
    extends BuildlessAutoDisposeNotifier<String> {
  late final String id;

  String build({
    required String id,
  });
}

/// See also [AudioTranscriptionController].
@ProviderFor(AudioTranscriptionController)
const audioTranscriptionControllerProvider =
    AudioTranscriptionControllerFamily();

/// See also [AudioTranscriptionController].
class AudioTranscriptionControllerFamily extends Family<String> {
  /// See also [AudioTranscriptionController].
  const AudioTranscriptionControllerFamily();

  /// See also [AudioTranscriptionController].
  AudioTranscriptionControllerProvider call({
    required String id,
  }) {
    return AudioTranscriptionControllerProvider(
      id: id,
    );
  }

  @override
  AudioTranscriptionControllerProvider getProviderOverride(
    covariant AudioTranscriptionControllerProvider provider,
  ) {
    return call(
      id: provider.id,
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
  String? get name => r'audioTranscriptionControllerProvider';
}

/// See also [AudioTranscriptionController].
class AudioTranscriptionControllerProvider
    extends AutoDisposeNotifierProviderImpl<AudioTranscriptionController,
        String> {
  /// See also [AudioTranscriptionController].
  AudioTranscriptionControllerProvider({
    required String id,
  }) : this._internal(
          () => AudioTranscriptionController()..id = id,
          from: audioTranscriptionControllerProvider,
          name: r'audioTranscriptionControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$audioTranscriptionControllerHash,
          dependencies: AudioTranscriptionControllerFamily._dependencies,
          allTransitiveDependencies:
              AudioTranscriptionControllerFamily._allTransitiveDependencies,
          id: id,
        );

  AudioTranscriptionControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  String runNotifierBuild(
    covariant AudioTranscriptionController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(AudioTranscriptionController Function() create) {
    return ProviderOverride(
      origin: this,
      override: AudioTranscriptionControllerProvider._internal(
        () => create()..id = id,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<AudioTranscriptionController, String>
      createElement() {
    return _AudioTranscriptionControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AudioTranscriptionControllerProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AudioTranscriptionControllerRef
    on AutoDisposeNotifierProviderRef<String> {
  /// The parameter `id` of this provider.
  String get id;
}

class _AudioTranscriptionControllerProviderElement
    extends AutoDisposeNotifierProviderElement<AudioTranscriptionController,
        String> with AudioTranscriptionControllerRef {
  _AudioTranscriptionControllerProviderElement(super.provider);

  @override
  String get id => (origin as AudioTranscriptionControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
