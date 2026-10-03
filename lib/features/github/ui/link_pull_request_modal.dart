import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/domain/github_repository.dart';
import 'package:lotti/features/github/domain/open_pull_request.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/github_failure_message.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/relative_age_label.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Keys the tests find the modal's controls by.
abstract final class LinkPullRequestKeys {
  static const urlField = Key('link_pull_request_url');
  static const linkButton = Key('link_pull_request_submit');
  static const cancelButton = Key('link_pull_request_cancel');
  static Key openPullRequest(int number) => Key('open_pull_request_$number');
}

/// Links a pull request to [taskId]: one picked from the open pull requests
/// of the task's repository that no task holds yet, or one pasted.
///
/// The pull request is read from GitHub, and checked again against the
/// tasks that hold it, before anything is linked
/// (`specs/tla/PullRequestAssignment.tla`), so the modal stays open with the
/// reason when it cannot be.
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

  /// What is being linked: the pasted text, or a picked pull request.
  Object? _linking;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _linkPasted() async {
    if (_linking != null || _controller.text.trim().isEmpty) return;
    await _run(
      _controller.text,
      () => ref
          .read(pullRequestServiceProvider)
          .linkPasted(taskId: widget.taskId, input: _controller.text),
    );
  }

  Future<void> _linkPicked(PullRequestRef pr) async {
    if (_linking != null) return;
    await _run(
      pr,
      () => ref
          .read(pullRequestServiceProvider)
          .link(taskId: widget.taskId, ref: pr),
    );
  }

  Future<void> _run(
    Object what,
    Future<PullRequestLinkResult> Function() link,
  ) async {
    setState(() {
      _linking = what;
      _error = null;
    });
    final result = await link();
    if (!mounted) return;
    if (result is PullRequestLinked) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _linking = null;
      _error = _messageFor(context.messages, result);
    });
  }

  static String? _messageFor(
    AppLocalizations messages,
    PullRequestLinkResult result,
  ) => switch (result) {
    PullRequestLinked() => null,
    PullRequestAlreadyLinked() => messages.githubLinkAlreadyLinked,
    PullRequestLinkedElsewhere() => messages.githubLinkedElsewhere,
    PullRequestLinkNotStored() => messages.githubLinkNotStored,
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
    final repository = ref
        .watch(taskGitHubRepositoryProvider(widget.taskId))
        .value;
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
          keyboardType: TextInputType.url,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _linkPasted(),
        ),
        SizedBox(height: tokens.spacing.step5),
        if (repository == null)
          _Note(text: messages.githubPickerNoRepository)
        else
          _OpenPullRequests(
            repository: repository,
            linking: _linking is PullRequestRef
                ? _linking! as PullRequestRef
                : null,
            onPick: _linkPicked,
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
            onPressed: _linking != null || _controller.text.trim().isEmpty
                ? null
                : _linkPasted,
          ),
        ),
      ],
    );
  }
}

/// The repository's open pull requests no task holds, to pick from.
class _OpenPullRequests extends ConsumerWidget {
  const _OpenPullRequests({
    required this.repository,
    required this.linking,
    required this.onPick,
  });

  final GitHubRepository repository;

  /// The pull request being linked, if one was picked.
  final PullRequestRef? linking;
  final ValueChanged<PullRequestRef> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final listing = ref.watch(openPullRequestsProvider(repository));
    final heading = Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step3),
      child: Text(
        messages.githubPickerOpenIn(repository.toString()),
        style: tokens.typography.styles.subtitle.subtitle2.copyWith(
          color: tokens.colors.text.highEmphasis,
        ),
      ),
    );

    return switch (listing) {
      AsyncData(value: OpenPullRequestsListed(:final available)) =>
        available.isEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  _Note(
                    text: messages.githubPickerEmpty(repository.toString()),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  for (var i = 0; i < available.length; i++) ...[
                    if (i > 0) const DesignSystemDivider(),
                    _OpenPullRequestRow(
                      pr: available[i],
                      linking: linking == available[i].ref,
                      onTap: linking == null
                          ? () => onPick(available[i].ref)
                          : null,
                    ),
                  ],
                ],
              ),
      AsyncData(value: OpenPullRequestsFailed(:final kind, :final retryAt)) =>
        _Note(
          text: gitHubFailureMessage(messages, kind, retryAt: retryAt),
        ),
      AsyncError() => _Note(
        text: gitHubFailureMessage(
          messages,
          GitHubFailureKind.invalidResponse,
        ),
      ),
      _ => Padding(
        padding: EdgeInsets.all(tokens.spacing.step5),
        child: Center(
          child: DesignSystemSpinner(
            size: IconSizes.l,
            semanticsLabel: messages.githubPickerLoading,
          ),
        ),
      ),
    };
  }
}

class _OpenPullRequestRow extends StatelessWidget {
  const _OpenPullRequestRow({
    required this.pr,
    required this.linking,
    required this.onTap,
  });

  final OpenPullRequest pr;
  final bool linking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final details = [
      if (pr.authorLogin != null) '@${pr.authorLogin}',
      if (pr.draft) messages.githubStatusDraft,
      relativeAgoLabel(messages, clock.now().difference(pr.updatedAt)),
    ].join(' · ');
    return DesignSystemListItem(
      key: LinkPullRequestKeys.openPullRequest(pr.ref.number),
      onTap: onTap,
      title: '#${pr.ref.number} ${pr.title}',
      titleMaxLines: 2,
      subtitle: details,
      size: DesignSystemListItemSize.small,
      leading: Icon(
        LottiIcons.merge,
        size: IconSizes.m,
        color: tokens.colors.interactive.enabled,
      ),
      trailingExtra: linking
          ? DesignSystemSpinner(
              size: IconSizes.m,
              semanticsLabel: messages.githubPickerLinking,
            )
          : null,
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Text(
      text,
      style: tokens.typography.styles.body.bodySmall.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
    );
  }
}
