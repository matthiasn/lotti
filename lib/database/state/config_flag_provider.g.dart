// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config_flag_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides a stream of the status (bool) for a specific config flag.
/// Returns false by default if the flag doesn't exist or has no status.

@ProviderFor(configFlag)
final configFlagProvider = ConfigFlagFamily._();

/// Provides a stream of the status (bool) for a specific config flag.
/// Returns false by default if the flag doesn't exist or has no status.

final class ConfigFlagProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// Provides a stream of the status (bool) for a specific config flag.
  /// Returns false by default if the flag doesn't exist or has no status.
  ConfigFlagProvider._(
      {required ConfigFlagFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'configFlagProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$configFlagHash();

  @override
  String toString() {
    return r'configFlagProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    final argument = this.argument as String;
    return configFlag(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConfigFlagProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$configFlagHash() => r'cb8244b4da8af37d109e0cc56ecd8b977091e30e';

/// Provides a stream of the status (bool) for a specific config flag.
/// Returns false by default if the flag doesn't exist or has no status.

final class ConfigFlagFamily extends $Family
    with $FunctionalFamilyOverride<Stream<bool>, String> {
  ConfigFlagFamily._()
      : super(
          retry: null,
          name: r'configFlagProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Provides a stream of the status (bool) for a specific config flag.
  /// Returns false by default if the flag doesn't exist or has no status.

  ConfigFlagProvider call(
    String flagName,
  ) =>
      ConfigFlagProvider._(argument: flagName, from: this);

  @override
  String toString() => r'configFlagProvider';
}
