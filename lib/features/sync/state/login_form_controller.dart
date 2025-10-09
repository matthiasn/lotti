import 'package:flutter/material.dart';
import 'package:formz/formz.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/model/validation/config_form_state.dart';
import 'package:lotti/features/sync/model/validation/homeserver.dart';
import 'package:lotti/features/sync/model/validation/password.dart';
import 'package:lotti/features/sync/model/validation/username.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'login_form_controller.g.dart';

@riverpod
class LoginFormController extends _$LoginFormController {
  MatrixService get _matrixService => ref.read(matrixServiceProvider);

  final homeServerController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  Future<LoginFormState?> build() async {
    final config = await ref.watch(matrixServiceProvider).loadConfig();

    passwordController.text = config?.password ?? '';
    usernameController.text = config?.user ?? '';
    homeServerController.text = config?.homeServer ?? '';

    final status = Formz.validate([
      HomeServer.pure(homeServerController.text),
      UserName.pure(usernameController.text),
      Password.pure(passwordController.text),
    ])
        ? FormzSubmissionStatus.success
        : FormzSubmissionStatus.failure;

    return LoginFormState(
      homeServer: HomeServer.dirty(config?.homeServer ?? ''),
      userName: UserName.dirty(config?.user ?? ''),
      password: Password.dirty(config?.password ?? ''),
      status: status,
    );
  }

  void homeServerChanged(String value) {
    final homeServer = HomeServer.dirty(value);
    final data = state.valueOrNull;
    state = AsyncData(
      data?.copyWith(
        homeServer: homeServer,
        status: Formz.validate([homeServer, data.userName, data.password])
            ? FormzSubmissionStatus.success
            : FormzSubmissionStatus.failure,
        loginFailed: false,
      ),
    );
  }

  void passwordChanged(String value) {
    final password = Password.dirty(value);
    final data = state.valueOrNull;
    state = AsyncData(
      data?.copyWith(
        password: password,
        status: Formz.validate([data.homeServer, data.userName, password])
            ? FormzSubmissionStatus.success
            : FormzSubmissionStatus.failure,
        loginFailed: false,
      ),
    );
  }

  void usernameChanged(String value) {
    final userName = UserName.dirty(value);
    final data = state.valueOrNull;
    state = AsyncData(
      data?.copyWith(
        userName: userName,
        status: Formz.validate([data.homeServer, data.password, userName])
            ? FormzSubmissionStatus.success
            : FormzSubmissionStatus.failure,
        loginFailed: false,
      ),
    );
  }

  Future<bool> login() async {
    final data = state.valueOrNull;
    if (data == null) {
      return false;
    }

    final config = MatrixConfig(
      homeServer: data.homeServer.value,
      user: data.userName.value,
      password: data.password.value,
    );

    await _matrixService.setConfig(config);
    final loginSuccessful = await _matrixService.login();

    state = AsyncData(
      data.copyWith(
        isLoggedIn: loginSuccessful,
        loginFailed: !loginSuccessful,
      ),
    );

    return loginSuccessful;
  }

  Future<void> deleteConfig() async {
    await _matrixService.deleteConfig();
    state = const AsyncLoading();
    ref.invalidateSelf();
  }
}
