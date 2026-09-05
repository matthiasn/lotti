import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Asks for the sync account password and retries a removal the homeserver
/// refused, resolving `true` once the retry succeeds.
///
/// [onSubmit] performs the retry with the entered password and returns `null`
/// on success — the sheet closes — or a localized message to show beneath the
/// field. A failed attempt therefore leaves the sheet open with the reason
/// attached to the input, so a mistyped password costs one correction rather
/// than a restart of the whole confirm-and-delete flow.
Future<bool> showSyncReauthModal({
  required BuildContext context,
  required String deviceName,
  required Future<String?> Function(String password) onSubmit,
}) async {
  final confirmed = await ModalUtils.showSinglePageModal<bool>(
    context: context,
    title: context.messages.syncReauthTitle,
    builder: (_) => SyncReauthForm(
      deviceName: deviceName,
      onSubmit: onSubmit,
    ),
  );
  return confirmed ?? false;
}

/// The body of [showSyncReauthModal], exposed so it can be driven directly in
/// tests without a modal route.
@visibleForTesting
class SyncReauthForm extends StatefulWidget {
  const SyncReauthForm({
    required this.deviceName,
    required this.onSubmit,
    super.key,
  });

  final String deviceName;
  final Future<String?> Function(String password) onSubmit;

  @override
  State<SyncReauthForm> createState() => _SyncReauthFormState();
}

class _SyncReauthFormState extends State<SyncReauthForm> {
  final _controller = TextEditingController();

  /// True while a retry is in flight, so a second Enter press cannot fire a
  /// duplicate deletion against a server that is merely slow.
  bool _busy = false;
  String? _error;
  bool _hasInput = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasInput = _controller.text.isNotEmpty;
    // Editing after a rejection retracts the verdict: leaving the old error
    // under a field the user has since changed reads as a fresh rejection.
    if (hasInput == _hasInput && _error == null) return;
    setState(() {
      _hasInput = hasInput;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_busy || !_hasInput) return;
    setState(() => _busy = true);
    final error = await widget.onSubmit(_controller.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          messages.syncReauthExplanation(widget.deviceName),
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step5),
        DesignSystemTextInput(
          key: const Key('sync_reauth_password'),
          controller: _controller,
          label: messages.syncReauthPasswordLabel,
          obscureText: true,
          autofocus: true,
          enabled: !_busy,
          errorText: _error,
          onSubmitted: (_) => _submit(),
        ),
        SizedBox(height: tokens.spacing.step7),
        DesignSystemModalActionBar(
          secondary: [
            DesignSystemButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              label: messages.settingsMatrixCancel,
              variant: DesignSystemButtonVariant.secondary,
              size: DesignSystemButtonSize.large,
            ),
          ],
          primary: DesignSystemButton(
            key: const Key('sync_reauth_submit'),
            // Disabled on an empty field: an empty password can only ever come
            // back as the same rejection the user is already looking at.
            onPressed: _hasInput ? _submit : null,
            isLoading: _busy,
            label: messages.deleteDeviceLabel,
            variant: DesignSystemButtonVariant.danger,
            size: DesignSystemButtonSize.large,
            fullWidth: true,
          ),
        ),
      ],
    );
  }
}
