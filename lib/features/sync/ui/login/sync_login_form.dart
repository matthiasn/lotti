import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/login_form_controller.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/sync/ui/qr_scan_login_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';

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
  bool _showQrScanner = false;

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
    // Show QR scanner if toggled
    if (_showQrScanner) {
      return QrScanLoginWidget(
        onLoginSuccess: () {
          // Navigate to room discovery page after successful QR login
          widget.pageIndexNotifier.value = 1;
        },
      );
    }

    final loginNotifier = ref.read(loginFormControllerProvider.notifier);
    final loginState = ref.watch(loginFormControllerProvider).valueOrNull;

    if (loginState == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // QR Scan button for mobile devices
        if (isMobile) ...[
          _ScanQrSection(
            onTap: () => setState(() => _showQrScanner = true),
          ),
          const SizedBox(height: 16),
          _OrDivider(),
          const SizedBox(height: 16),
        ],
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

/// Section prompting user to scan QR for quick setup.
class _ScanQrSection extends StatelessWidget {
  const _ScanQrSection({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.qr_code_scanner,
            size: 40,
            color: context.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            context.messages.syncSetupEnterPin,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          LottiPrimaryButton(
            onPressed: onTap,
            label: context.messages.syncSetupScanQr,
          ),
        ],
      ),
    );
  }
}

/// Divider with "or" text.
class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
              color: context.colorScheme.outline.withValues(alpha: 0.3)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.outline,
            ),
          ),
        ),
        Expanded(
          child: Divider(
              color: context.colorScheme.outline.withValues(alpha: 0.3)),
        ),
      ],
    );
  }
}
