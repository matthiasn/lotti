// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matrix_login_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$loginStateStreamHash() => r'e643511b02c1a28f58434438896b333d978320d7';

/// See also [loginStateStream].
@ProviderFor(loginStateStream)
final loginStateStreamProvider = AutoDisposeStreamProvider<LoginState>.internal(
  loginStateStream,
  name: r'loginStateStreamProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$loginStateStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef LoginStateStreamRef = AutoDisposeStreamProviderRef<LoginState>;
String _$isLoggedInHash() => r'e6fca2a8e06f31e155da7448053c88df2f721a12';

/// See also [isLoggedIn].
@ProviderFor(isLoggedIn)
final isLoggedInProvider = AutoDisposeFutureProvider<bool>.internal(
  isLoggedIn,
  name: r'isLoggedInProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$isLoggedInHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef IsLoggedInRef = AutoDisposeFutureProviderRef<bool>;
String _$loggedInUserIdHash() => r'5461bb2f51c4fd99c3ccdbfab6cdf6e2aa0acacc';

/// See also [loggedInUserId].
@ProviderFor(loggedInUserId)
final loggedInUserIdProvider = AutoDisposeFutureProvider<String?>.internal(
  loggedInUserId,
  name: r'loggedInUserIdProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$loggedInUserIdHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef LoggedInUserIdRef = AutoDisposeFutureProviderRef<String?>;
String _$matrixLoginControllerHash() =>
    r'3fb97078ff542a174f4a09aa988aae4be681b33d';

/// See also [MatrixLoginController].
@ProviderFor(MatrixLoginController)
final matrixLoginControllerProvider = AutoDisposeAsyncNotifierProvider<
    MatrixLoginController, LoginState?>.internal(
  MatrixLoginController.new,
  name: r'matrixLoginControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$matrixLoginControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MatrixLoginController = AutoDisposeAsyncNotifier<LoginState?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
