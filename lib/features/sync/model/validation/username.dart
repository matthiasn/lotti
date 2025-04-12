import 'package:formz/formz.dart';

enum UserNameValidationError { tooShort }

class UserName extends FormzInput<String, UserNameValidationError> {
  const UserName.pure([super.value = '']) : super.pure();
  const UserName.dirty([super.value = '']) : super.dirty();

  @override
  UserNameValidationError? validator(String value) {
    return value.length >= 6 ? null : UserNameValidationError.tooShort;
  }
}
