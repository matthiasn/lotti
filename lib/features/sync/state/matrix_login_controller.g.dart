// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matrix_login_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$loginStateStreamHash() => r'799f4deff791f17893c37e2ae3eeaaad184486b0';

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

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LoginStateStreamRef = AutoDisposeStreamProviderRef<LoginState>;
String _$isLoggedInHash() => r'3b2979ba7a521872d8cf83091efdf290efcb6a9b';

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

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IsLoggedInRef = AutoDisposeFutureProviderRef<bool>;
String _$loggedInUserIdHash() => r'ca80d49453e2b9d26d4fdbcada7311ea5f2fbeea';

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

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LoggedInUserIdRef = AutoDisposeFutureProviderRef<String?>;
String _$matrixLoginControllerHash() =>
    r'b6b08d979ec2e6ebfe25ecf9c11f05d81a69f134';

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
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
