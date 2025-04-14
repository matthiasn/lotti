// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_transcription.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$aiAudioTranscriptionControllerHash() =>
    r'778ad1d1e780eb1de23208be1922c1b9685ece7c';

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

abstract class _$AiAudioTranscriptionController
    extends BuildlessAutoDisposeNotifier<String> {
  late final String id;

  String build({
    required String id,
  });
}

/// See also [AiAudioTranscriptionController].
@ProviderFor(AiAudioTranscriptionController)
const aiAudioTranscriptionControllerProvider =
    AiAudioTranscriptionControllerFamily();

/// See also [AiAudioTranscriptionController].
class AiAudioTranscriptionControllerFamily extends Family<String> {
  /// See also [AiAudioTranscriptionController].
  const AiAudioTranscriptionControllerFamily();

  /// See also [AiAudioTranscriptionController].
  AiAudioTranscriptionControllerProvider call({
    required String id,
  }) {
    return AiAudioTranscriptionControllerProvider(
      id: id,
    );
  }

  @override
  AiAudioTranscriptionControllerProvider getProviderOverride(
    covariant AiAudioTranscriptionControllerProvider provider,
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
  String? get name => r'aiAudioTranscriptionControllerProvider';
}

/// See also [AiAudioTranscriptionController].
class AiAudioTranscriptionControllerProvider
    extends AutoDisposeNotifierProviderImpl<AiAudioTranscriptionController,
        String> {
  /// See also [AiAudioTranscriptionController].
  AiAudioTranscriptionControllerProvider({
    required String id,
  }) : this._internal(
          () => AiAudioTranscriptionController()..id = id,
          from: aiAudioTranscriptionControllerProvider,
          name: r'aiAudioTranscriptionControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$aiAudioTranscriptionControllerHash,
          dependencies: AiAudioTranscriptionControllerFamily._dependencies,
          allTransitiveDependencies:
              AiAudioTranscriptionControllerFamily._allTransitiveDependencies,
          id: id,
        );

  AiAudioTranscriptionControllerProvider._internal(
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
    covariant AiAudioTranscriptionController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(AiAudioTranscriptionController Function() create) {
    return ProviderOverride(
      origin: this,
      override: AiAudioTranscriptionControllerProvider._internal(
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
  AutoDisposeNotifierProviderElement<AiAudioTranscriptionController, String>
      createElement() {
    return _AiAudioTranscriptionControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AiAudioTranscriptionControllerProvider && other.id == id;
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
mixin AiAudioTranscriptionControllerRef
    on AutoDisposeNotifierProviderRef<String> {
  /// The parameter `id` of this provider.
  String get id;
}

class _AiAudioTranscriptionControllerProviderElement
    extends AutoDisposeNotifierProviderElement<AiAudioTranscriptionController,
        String> with AiAudioTranscriptionControllerRef {
  _AiAudioTranscriptionControllerProviderElement(super.provider);

  @override
  String get id => (origin as AiAudioTranscriptionControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
