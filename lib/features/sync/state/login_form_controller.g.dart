// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_form_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LoginFormController)
final loginFormControllerProvider = LoginFormControllerProvider._();

final class LoginFormControllerProvider
    extends $AsyncNotifierProvider<LoginFormController, LoginFormState?> {
  LoginFormControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'loginFormControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$loginFormControllerHash();

  @$internal
  @override
  LoginFormController create() => LoginFormController();
}

String _$loginFormControllerHash() =>
    r'8259e4871396354bb4d513a1a7410f31d4f56f83';

abstract class _$LoginFormController extends $AsyncNotifier<LoginFormState?> {
  FutureOr<LoginFormState?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<LoginFormState?>, LoginFormState?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<LoginFormState?>, LoginFormState?>,
        AsyncValue<LoginFormState?>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
