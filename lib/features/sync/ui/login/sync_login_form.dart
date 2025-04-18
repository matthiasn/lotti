import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/login_form_controller.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class SyncLoginForm extends ConsumerStatefulWidget {
  const SyncLoginForm({
    required this.pageIndexNotifier,
    super.key,
  });

  final ValueNotifier<int> pageIndexNotifier;

  @override
  ConsumerState<SyncLoginForm> createState() => _SyncLoginFormState();
}

class _SyncLoginFormState extends ConsumerState<SyncLoginForm> {
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();

    final isLoggedIn = ref.read(isLoggedInProvider).valueOrNull ?? false;
    if (isLoggedIn) {
      widget.pageIndexNotifier.value = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loginNotifier = ref.read(loginFormControllerProvider.notifier);
    final loginState = ref.watch(loginFormControllerProvider).valueOrNull;

    if (loginState == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 90,
          child: TextField(
            onChanged: loginNotifier.homeServerChanged,
            controller: loginNotifier.homeServerController,
            decoration: InputDecoration(
              labelText: context.messages.settingsMatrixHomeServerLabel,
              errorText: loginState.homeServer.isNotValid &&
                      !loginState.homeServer.isPure
                  ? context.messages.settingsMatrixEnterValidUrl
                  : null,
            ),
          ),
        ),
        SizedBox(
          height: 90,
          child: TextField(
            onChanged: loginNotifier.usernameChanged,
            controller: loginNotifier.usernameController,
            decoration: InputDecoration(
              labelText: context.messages.settingsMatrixUserLabel,
              errorText:
                  loginState.userName.isNotValid && !loginState.userName.isPure
                      ? context.messages.settingsMatrixUserNameTooShort
                      : null,
            ),
          ),
        ),
        SizedBox(
          height: 90,
          child: TextField(
            onChanged: loginNotifier.passwordChanged,
            controller: loginNotifier.passwordController,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: context.messages.settingsMatrixPasswordLabel,
              errorText:
                  loginState.password.isNotValid && !loginState.password.isPure
                      ? context.messages.settingsMatrixPasswordTooShort
                      : null,
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword
                      ? Icons.remove_red_eye_outlined
                      : Icons.remove_red_eye,
                  color: context.colorScheme.outline,
                  semanticLabel: 'Password',
                ),
                onPressed: () => setState(() {
                  _showPassword = !_showPassword;
                }),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: Column(
            children: [
              if (loginState.loginFailed)
                Text(
                  context.messages.settingsMatrixLoginFailed,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colorScheme.error,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
