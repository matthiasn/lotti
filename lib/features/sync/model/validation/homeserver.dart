import 'package:formz/formz.dart';

enum HomeServerValidationError { invalid }

class HomeServer extends FormzInput<String, HomeServerValidationError> {
  const HomeServer.pure([super.value = '']) : super.pure();
  const HomeServer.dirty([super.value = '']) : super.dirty();

  @override
  HomeServerValidationError? validator(String value) {
    final urlRegex = RegExp(
      r'^https://([\w-]+\.)+[\w-]+(/[\w-./?%&=]*)?$',
    );
    return urlRegex.hasMatch(value) ? null : HomeServerValidationError.invalid;
  }
}
