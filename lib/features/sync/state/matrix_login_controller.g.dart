// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matrix_login_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MatrixLoginController)
final matrixLoginControllerProvider = MatrixLoginControllerProvider._();

final class MatrixLoginControllerProvider
    extends $AsyncNotifierProvider<MatrixLoginController, LoginState?> {
  MatrixLoginControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'matrixLoginControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$matrixLoginControllerHash();

  @$internal
  @override
  MatrixLoginController create() => MatrixLoginController();
}

String _$matrixLoginControllerHash() =>
    r'c8dc0869b85df72976c8abffe680c1064e518ae2';

abstract class _$MatrixLoginController extends $AsyncNotifier<LoginState?> {
  FutureOr<LoginState?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<LoginState?>, LoginState?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<LoginState?>, LoginState?>,
        AsyncValue<LoginState?>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(loginStateStream)
final loginStateStreamProvider = LoginStateStreamProvider._();

final class LoginStateStreamProvider extends $FunctionalProvider<
        AsyncValue<LoginState>, LoginState, Stream<LoginState>>
    with $FutureModifier<LoginState>, $StreamProvider<LoginState> {
  LoginStateStreamProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'loginStateStreamProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$loginStateStreamHash();

  @$internal
  @override
  $StreamProviderElement<LoginState> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<LoginState> create(Ref ref) {
    return loginStateStream(ref);
  }
}

String _$loginStateStreamHash() => r'4fd12bd9f4848820865ea30bde95611b52ea971b';

@ProviderFor(isLoggedIn)
final isLoggedInProvider = IsLoggedInProvider._();

final class IsLoggedInProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  IsLoggedInProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'isLoggedInProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$isLoggedInHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return isLoggedIn(ref);
  }
}

String _$isLoggedInHash() => r'3b2979ba7a521872d8cf83091efdf290efcb6a9b';

@ProviderFor(loggedInUserId)
final loggedInUserIdProvider = LoggedInUserIdProvider._();

final class LoggedInUserIdProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  LoggedInUserIdProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'loggedInUserIdProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$loggedInUserIdHash();

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    return loggedInUserId(ref);
  }
}

String _$loggedInUserIdHash() => r'a3c60a78a7bbfc372bb1a342fb5251f23c95768c';
