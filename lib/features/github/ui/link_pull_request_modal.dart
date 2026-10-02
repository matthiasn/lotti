import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/github_failure_message.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Keys the tests find the modal's controls by.
abstract final class LinkPullRequestKeys {
  static const urlField = Key('link_pull_request_url');
  static const linkButton = Key('link_pull_request_submit');
  static const cancelButton = Key('link_pull_request_cancel');
}

/// Asks for a pull request URL and links it to [taskId]. The pull request is
/// read from GitHub before anything is linked, so the modal stays open with
/// the reason when it cannot be.
Future<void> showLinkPullRequestModal(
  BuildContext context, {
  required String taskId,
}) => ModalUtils.showSinglePageModal<void>(
  context: context,
  title: context.messages.githubLinkPullRequestTitle,
  builder: (modalContext) => _LinkPullRequestForm(taskId: taskId),
);

class _LinkPullRequestForm extends ConsumerStatefulWidget {
  const _LinkPullRequestForm({required this.taskId});

  final String taskId;

  @override
  ConsumerState<_LinkPullRequestForm> createState() =>
      _LinkPullRequestFormState();
}

class _LinkPullRequestFormState extends ConsumerState<_LinkPullRequestForm> {
  final _controller = TextEditingController();
  var _linking = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_linking || _controller.text.trim().isEmpty) return;
    setState(() {
      _linking = true;
      _error = null;
    });
    final result = await ref
        .read(pullRequestServiceProvider)
        .linkPasted(taskId: widget.taskId, input: _controller.text);
    if (!mounted) return;
    if (result is PullRequestLinked) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _linking = false;
      _error = _messageFor(context.messages, result);
    });
  }

  static String? _messageFor(
    AppLocalizations messages,
    PullRequestLinkResult result,
  ) => switch (result) {
    PullRequestLinked() => null,
    PullRequestAlreadyLinked() => messages.githubLinkAlreadyLinked,
    PullRequestLinkRejected(:final reason) => switch (reason) {
      PullRequestRefRejection.empty => null,
      PullRequestRefRejection.notGitHub => messages.githubLinkNotGitHub,
      PullRequestRefRejection.notAPullRequest =>
        messages.githubLinkNotAPullRequest,
    },
    PullRequestLinkFailed(:final kind, :final retryAt) => gitHubFailureMessage(
      messages,
      kind,
      retryAt: retryAt,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesignSystemTextInput(
          key: LinkPullRequestKeys.urlField,
          controller: _controller,
          label: messages.githubLinkUrlLabel,
          hintText: messages.githubLinkUrlHint,
          helperText: _error == null ? messages.githubLinkUrlHelper : null,
          errorText: _error,
          autofocus: true,
          keyboardType: TextInputType.url,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _submit(),
        ),
        SizedBox(height: tokens.spacing.sectionGap),
        DesignSystemModalActionBar(
          secondary: [
            DesignSystemButton(
              key: LinkPullRequestKeys.cancelButton,
              label: messages.cancelButton,
              variant: DesignSystemButtonVariant.secondary,
              size: DesignSystemButtonSize.large,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          primary: DesignSystemButton(
            key: LinkPullRequestKeys.linkButton,
            label: messages.githubLinkButton,
            leadingIcon: LottiIcons.link,
            size: DesignSystemButtonSize.large,
            fullWidth: true,
            onPressed: _linking || _controller.text.trim().isEmpty
                ? null
                : _submit,
          ),
        ),
      ],
    );
  }
}
