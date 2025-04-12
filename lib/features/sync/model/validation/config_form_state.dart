import 'package:formz/formz.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/sync/model/validation/homeserver.dart';
import 'package:lotti/features/sync/model/validation/password.dart';
import 'package:lotti/features/sync/model/validation/username.dart';

part 'config_form_state.freezed.dart';

@freezed
class LoginFormState with _$LoginFormState {
  const factory LoginFormState({
    @Default(HomeServer.pure()) HomeServer homeServer,
    @Default(UserName.pure()) UserName userName,
    @Default(Password.pure()) Password password,
    @Default(FormzSubmissionStatus.initial) FormzSubmissionStatus status,
    @Default(false) bool isLoggedIn,
    @Default(false) bool loginFailed,
  }) = _LoginFormState;
}
