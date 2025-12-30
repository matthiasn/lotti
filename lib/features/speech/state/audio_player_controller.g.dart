// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_player_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$playerFactoryHash() => r'9a4d2eab410bb6538a834d2463d9eda80fe4a642';

/// Provider for the player factory, can be overridden in tests.
///
/// Copied from [playerFactory].
@ProviderFor(playerFactory)
final playerFactoryProvider = Provider<PlayerFactory>.internal(
  playerFactory,
  name: r'playerFactoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$playerFactoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PlayerFactoryRef = ProviderRef<PlayerFactory>;
String _$audioPlayerControllerHash() =>
    r'3a2da4d03ef25f519b6fb8e715115ae9b73a6da2';

/// Notifier managing audio player state.
/// Marked as keepAlive since audio state should persist for the entire app
/// lifecycle.
///
/// Copied from [AudioPlayerController].
@ProviderFor(AudioPlayerController)
final audioPlayerControllerProvider =
    NotifierProvider<AudioPlayerController, AudioPlayerState>.internal(
  AudioPlayerController.new,
  name: r'audioPlayerControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$audioPlayerControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AudioPlayerController = Notifier<AudioPlayerState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
