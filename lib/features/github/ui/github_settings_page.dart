import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/domain/github_token_template.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/github_failure_message.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/pages/sliver_box_adapter_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// What the page last learned about the user's other devices.
enum _SyncNote {
  /// The token went to the outbox.
  sent,

  /// The outbox did not take it; the user may try again.
  sendFailed,

  /// A change made here is owed: it is sent at the next start.
  owed,

  /// Sync caught up and no token arrived — said only while there is none.
  noToken,
}

/// Mobile / Beamer wrapper for the GitHub setting.
class GitHubSettingsPage extends StatelessWidget {
  const GitHubSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => SliverBoxAdapterPage(
    title: context.messages.settingsGitHubTitle,
    showBackButton: true,
    child: const GitHubSettingsBody(),
  );
}

/// Connects to GitHub with the user's personal access token, or shows whose
/// token it holds and lets the user remove it. Without one, it opens GitHub's
/// token form with Lotti's read-only permissions filled in, for the user to
/// paste the result back. The token syncs to the user's
/// other devices; a small action sends it to them again, or — on a device
/// without one — asks sync to catch up, rather than syncing on every visit.
class GitHubSettingsBody extends ConsumerStatefulWidget {
  const GitHubSettingsBody({super.key});

  @override
  ConsumerState<GitHubSettingsBody> createState() => _GitHubSettingsBodyState();
}

class _GitHubSettingsBodyState extends ConsumerState<GitHubSettingsBody> {
  final _tokenController = TextEditingController();
  var _showToken = false;
  var _connecting = false;
  String? _error;

  /// The other-devices action in flight, and what it last found.
  var _syncing = false;
  _SyncNote? _syncNote;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  /// Checks the typed token with GitHub and keeps it. A token GitHub refuses
  /// is said in the field's error slot; one this device could not keep — a
  /// keychain that refuses the write — is said in an error toast. A
  /// connection is confirmed with a toast.
  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    final outcome = await ref
        .read(gitHubAccountControllerProvider.notifier)
        .connect(_tokenController.text);
    if (!mounted) return;
    final owed = outcome is GitHubConnected && await _changeOwed();
    if (!mounted) return;
    final messages = context.messages;
    setState(() {
      _connecting = false;
      _error = switch (outcome) {
        GitHubConnectRefused(:final kind) => gitHubFailureMessage(
          messages,
          kind,
        ),
        GitHubConnected() || GitHubTokenNotStored() => null,
      };
      if (outcome is GitHubConnected) _tokenController.clear();
      _syncNote = owed ? _SyncNote.owed : null;
    });
    switch (outcome) {
      case GitHubConnected(:final login):
        context.showToast(
          tone: DesignSystemToastTone.success,
          title: messages.githubConnectedToast(login),
        );
      case GitHubTokenNotStored():
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: messages.githubConnectSaveFailedTitle,
          description: messages.githubConnectSaveFailed,
        );
      case GitHubConnectRefused():
        break;
    }
  }

  /// Opens GitHub's pre-filled token form in the browser. A browser that
  /// cannot be opened is said in an error toast, with where to make the token
  /// by hand — never thrown.
  Future<void> _createToken() async {
    var opened = false;
    try {
      opened = await launchUrl(
        gitHubTokenTemplateUri(),
        mode: LaunchMode.externalApplication,
      );
    } on Exception {
      opened = false;
    }
    if (opened || !mounted) return;
    context.showToast(
      tone: DesignSystemToastTone.error,
      title: context.messages.githubCreateTokenOpenFailedTitle,
      description: context.messages.githubCreateTokenOpenFailed,
    );
  }

  /// Forgets the token here and on the other devices, and says so with a
  /// toast — or, when this device could not forget it, says that instead.
  Future<void> _disconnect() async {
    final forgotten = await ref
        .read(gitHubAccountControllerProvider.notifier)
        .disconnect();
    if (!mounted) return;
    if (!forgotten) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.githubDisconnectFailedTitle,
        description: context.messages.githubDisconnectFailed,
      );
      return;
    }
    final owed = await _changeOwed();
    if (!mounted) return;
    setState(() => _syncNote = owed ? _SyncNote.owed : null);
    context.showToast(
      tone: DesignSystemToastTone.success,
      title: context.messages.githubDisconnectedToast,
    );
  }

  /// Whether a change made here still has to reach the outbox; a keychain
  /// that cannot be read answers no, which leaves the note unsaid.
  Future<bool> _changeOwed() =>
      ref.read(gitHubAccountControllerProvider.notifier).changeOwed();

  Future<void> _sendToOtherDevices() async {
    setState(() {
      _syncing = true;
      _syncNote = null;
    });
    bool? sent = false;
    try {
      sent = await ref
          .read(gitHubAccountControllerProvider.notifier)
          .sendToOtherDevices();
    } finally {
      // Whatever went wrong, the action is available again.
      if (mounted) {
        setState(() {
          _syncing = false;
          _syncNote = switch (sent) {
            true => _SyncNote.sent,
            false => _SyncNote.sendFailed,
            null => null,
          };
        });
      }
    }
  }

  Future<void> _checkOtherDevices() async {
    setState(() {
      _syncing = true;
      _syncNote = null;
    });
    final controller = ref.read(gitHubAccountControllerProvider.notifier);
    try {
      await controller.checkOtherDevices();
    } on Exception {
      // Best effort: a received token GitHub rejects shows as the account's
      // own error, and a catch-up that failed leaves the action to try again.
    } finally {
      // Whatever went wrong, the action is available again.
      if (mounted) {
        setState(() {
          _syncing = false;
          _syncNote = _SyncNote.noToken;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final account = ref.watch(gitHubAccountControllerProvider);
    final login = account.value;
    // A token from another device that GitHub rejected: say why, and take a
    // new one here.
    final rejected = switch (account.error) {
      GitHubException(:final kind) => gitHubFailureMessage(messages, kind),
      _ => null,
    };
    final canSync = ref.watch(gitHubAccountSyncProvider).canCheckOtherDevices;
    final secondary = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (login != null) ...[
            Row(
              children: [
                Icon(
                  LottiIcons.confirmCircled,
                  size: IconSizes.m,
                  color: tokens.colors.alert.success.ink,
                ),
                SizedBox(width: tokens.spacing.step3),
                Expanded(
                  child: Text(
                    messages.githubConnectedAs(login),
                    key: const Key('github_connected_as'),
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.step5),
            DesignSystemButton(
              key: const Key('github_disconnect'),
              label: messages.githubDisconnectButton,
              variant: DesignSystemButtonVariant.secondary,
              leadingIcon: LottiIcons.signOut,
              onPressed: _disconnect,
            ),
          ] else ...[
            Text(messages.githubTokenIntro, style: secondary),
            SizedBox(height: tokens.spacing.step5),
            DesignSystemButton(
              key: const Key('github_create_token'),
              label: messages.githubCreateTokenButton,
              variant: DesignSystemButtonVariant.secondary,
              leadingIcon: LottiIcons.openExternal,
              size: DesignSystemButtonSize.large,
              fullWidth: true,
              onPressed: _createToken,
            ),
            SizedBox(height: tokens.spacing.step5),
            DesignSystemTextInput(
              key: const Key('github_token'),
              controller: _tokenController,
              label: messages.githubTokenLabel,
              errorText: _error ?? rejected,
              obscureText: !_showToken,
              trailingIcon: _showToken ? LottiIcons.hidden : LottiIcons.visible,
              trailingIconKey: const Key('github_token_toggle'),
              trailingIconTooltip: _showToken
                  ? messages.githubTokenHide
                  : messages.githubTokenShow,
              onTrailingIconTap: () => setState(() => _showToken = !_showToken),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _connecting ? null : _connect(),
            ),
            SizedBox(height: tokens.spacing.step4),
            DesignSystemButton(
              key: const Key('github_connect'),
              label: messages.githubConnectButton,
              leadingIcon: LottiIcons.key,
              size: DesignSystemButtonSize.large,
              fullWidth: true,
              isLoading: _connecting,
              onPressed: _tokenController.text.trim().isEmpty ? null : _connect,
            ),
          ],
          if (canSync) ...[
            SizedBox(height: tokens.spacing.step4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: DesignSystemButton(
                key: const Key('github_other_devices'),
                label: login != null
                    ? messages.githubSendToOtherDevices
                    : messages.githubCheckOtherDevices,
                variant: DesignSystemButtonVariant.tertiary,
                size: DesignSystemButtonSize.dense,
                leadingIcon: LottiIcons.sync,
                onPressed: _syncing
                    ? null
                    : login != null
                    ? _sendToOtherDevices
                    : _checkOtherDevices,
              ),
            ),
            // Tied to the account as it is now: a token that arrives after
            // the check leaves no stale "none arrived" beside it.
            if (switch (_syncNote) {
                  _SyncNote.sent => messages.githubSentToOtherDevices,
                  _SyncNote.sendFailed => messages.githubSendFailed,
                  _SyncNote.owed => messages.githubChangeOwed,
                  _SyncNote.noToken when login == null =>
                    messages.githubNoTokenFromOtherDevices,
                  _ => null,
                }
                case final note?)
              Text(note, key: const Key('github_sync_note'), style: secondary),
          ],
          if (login == null) ...[
            SizedBox(height: tokens.spacing.step5),
            Text(
              messages.githubTokenChecksCaveat,
              key: const Key('github_token_checks_caveat'),
              style: secondary,
            ),
          ],
          SizedBox(height: tokens.spacing.step5),
          Row(
            key: const Key('github_token_privacy'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LottiIcons.lock,
                size: IconSizes.s,
                color: tokens.colors.text.mediumEmphasis,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Text(messages.githubTokenPrivacy, style: secondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
