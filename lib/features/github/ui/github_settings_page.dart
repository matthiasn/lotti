import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/github_failure_message.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

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

/// Connects this device to GitHub with the user's personal access token,
/// or shows whose token it holds and lets the user remove it.
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

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    final failure = await ref
        .read(gitHubAccountControllerProvider.notifier)
        .connect(_tokenController.text);
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _error = failure == null
          ? null
          : gitHubFailureMessage(context.messages, failure);
      if (failure == null) _tokenController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final login = ref.watch(gitHubAccountControllerProvider).value;
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
              onPressed: () => ref
                  .read(gitHubAccountControllerProvider.notifier)
                  .disconnect(),
            ),
          ] else ...[
            Text(messages.githubTokenIntro, style: secondary),
            SizedBox(height: tokens.spacing.step5),
            DesignSystemTextInput(
              key: const Key('github_token'),
              controller: _tokenController,
              label: messages.githubTokenLabel,
              errorText: _error,
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
              onPressed: _connecting || _tokenController.text.trim().isEmpty
                  ? null
                  : _connect,
            ),
          ],
          SizedBox(height: tokens.spacing.step5),
          Row(
            key: const Key('github_token_kept_on_device'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LottiIcons.lock,
                size: IconSizes.s,
                color: tokens.colors.text.mediumEmphasis,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Text(messages.githubTokenKeptOnDevice, style: secondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
