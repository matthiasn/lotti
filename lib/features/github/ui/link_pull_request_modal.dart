import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/github/github_repository.dart';
import 'package:lotti/classes/github/pull_request_ref.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/domain/open_pull_request.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/github_failure_message.dart';
import 'package:lotti/features/github/ui/linked_elsewhere.dart';
import 'package:lotti/features/github/ui/pull_request_glyph.dart';
import 'package:lotti/features/github/ui/pull_request_row.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Keys the tests find the modal's controls by.
abstract final class LinkPullRequestKeys {
  static const urlField = Key('link_pull_request_url');
  static const linkButton = Key('link_pull_request_submit');
  static const linkHereToo = Key('link_pull_request_here_too');
  static const keepElsewhere = Key('link_pull_request_keep_elsewhere');
  static Key openPullRequest(int number) => Key('open_pull_request_$number');
}

/// Links a pull request to [taskId]: one picked from the open pull requests
/// of the task's repository that no task holds yet, or one pasted.
///
/// The pull request is read from GitHub, and checked again against the
/// tasks that hold it, before anything is linked
/// (`specs/tla/PullRequestAssignment.tla`), so the modal stays open with the
/// reason when it cannot be. One another task holds is asked about: the user
/// links it here too, or keeps it where it is.
Future<void> showLinkPullRequestModal(
  BuildContext context, {
  required String taskId,
}) => ModalUtils.showSinglePageModal<void>(
  context: context,
  title: context.messages.githubLinkPullRequestTitle,
  // The footer is part of the form, not a sticky bar: the sheet's default
  // bottom inset would add a second gap below it.
  padding: EdgeInsets.all(context.designTokens.spacing.step5),
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

  /// The open question: other tasks hold the pull request the user chose.
  PullRequestLinkedElsewhere? _elsewhere;

  /// The row [_error] or [_elsewhere] is about, when a pick led to it: said
  /// there, not at a field nobody typed in. Null after a paste.
  PullRequestRef? _picked;

  void _clearOutcome() {
    _error = null;
    _elsewhere = null;
    _picked = null;
  }

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

  /// The user's answer to [_elsewhere]: link it to this task as well.
  Future<void> _linkHereToo() async {
    final ref_ = _elsewhere?.ref;
    if (_linking != null || ref_ == null) return;
    await _run(
      // Where the question came from, so progress and a failure land there.
      _picked ?? _controller.text,
      () => ref
          .read(pullRequestServiceProvider)
          .link(taskId: widget.taskId, ref: ref_, alsoElsewhere: true),
    );
  }

  Future<void> _run(
    Object what,
    Future<PullRequestLinkResult> Function() link,
  ) async {
    setState(() {
      _linking = what;
      _clearOutcome();
    });
    PullRequestLinkResult result;
    try {
      result = await link();
    } on Exception {
      // A database failure while checking or storing: nothing was linked, and
      // the modal must stay usable to try again.
      result = const PullRequestLinkNotStored();
    }
    if (!mounted) return;
    if (result is PullRequestLinked) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _linking = null;
      _picked = what is PullRequestRef ? what : null;
      if (result is PullRequestLinkedElsewhere) {
        _elsewhere = result;
      } else {
        _error = _messageFor(context.messages, result);
      }
    });
  }

  static String? _messageFor(
    AppLocalizations messages,
    PullRequestLinkResult result,
  ) => switch (result) {
    PullRequestLinked() => null,
    PullRequestAlreadyLinked() => messages.githubLinkAlreadyLinked,
    // Asked about instead, in [_ElsewhereQuestion].
    PullRequestLinkedElsewhere() => null,
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
    final pasted = _controller.text.trim().isNotEmpty;
    final pastedLinking = _linking is String;
    final error = _error;
    final question = switch (_elsewhere) {
      final elsewhere? => _ElsewhereQuestion(
        taskIds: elsewhere.taskIds,
        linking: _linking != null,
        onLinkHereToo: _linkHereToo,
        onKeep: () => setState(_clearOutcome),
      ),
      null => null,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesignSystemTextInput(
          key: LinkPullRequestKeys.urlField,
          controller: _controller,
          label: messages.githubLinkUrlLabel,
          // The sheet's own surface shows through: field and picker are
          // framed alike, neither a darker well.
          filled: false,
          hintText: messages.githubLinkUrlHint,
          errorText: _picked == null ? _error : null,
          keyboardType: TextInputType.url,
          // Link sits in the field it submits, appearing in place once there
          // is something to link: a picked row links on its own tap, so a
          // button waiting under the list read as "pick, then confirm", and
          // one that appeared there reflowed the sheet under the typing.
          trailingIcon: pasted ? LottiIcons.link : null,
          // One primary at a time: while the question below is open, its
          // answer leads.
          emphasizeTrailingIcon:
              pasted && _linking == null && _elsewhere == null,
          trailingIconBusy: pastedLinking,
          trailingIconBusyLabel: messages.githubPickerLinking,
          onTrailingIconTap: pasted && _linking == null ? _linkPasted : null,
          trailingIconTooltip: messages.githubLinkButton,
          trailingIconKey: LinkPullRequestKeys.linkButton,
          onChanged: (_) => setState(_clearOutcome),
          onSubmitted: (_) => _linkPasted(),
        ),
        if (_picked == null && question != null) ...[
          SizedBox(height: tokens.spacing.step3),
          question,
        ],
        // The one hint sits with the field it is about; the picker is a
        // section of its own.
        SizedBox(
          height: repository == null
              ? tokens.spacing.step3
              : tokens.spacing.step5,
        ),
        if (repository == null)
          _Note(text: messages.githubPickerNoRepository)
        else
          _OpenPullRequests(
            repository: repository,
            linking: _linking is PullRequestRef
                ? _linking! as PullRequestRef
                : null,
            picked: _picked,
            outcome: _picked == null
                ? null
                : question ??
                      (error == null ? null : _Note(text: error, error: true)),
            busy: _linking != null,
            onPick: _linkPicked,
          ),
      ],
    );
  }
}

/// The repository's open pull requests no task holds, to pick from: rows in
/// a frame of their own, so the list reads as one thing to choose from
/// rather than more of the form.
class _OpenPullRequests extends ConsumerWidget {
  const _OpenPullRequests({
    required this.repository,
    required this.linking,
    required this.picked,
    required this.outcome,
    required this.busy,
    required this.onPick,
  });

  final GitHubRepository repository;

  /// The pull request being linked, if one was picked.
  final PullRequestRef? linking;

  /// The pull request a pick did not link, and what came of it — the
  /// reason, or the question to answer — shown under its row, which stays
  /// tinted to say which one is meant.
  final PullRequestRef? picked;
  final Widget? outcome;

  /// Something is being linked — a picked row, or what was pasted: every
  /// other row steps back, rather than looking live and swallowing a tap.
  final bool busy;
  final ValueChanged<PullRequestRef> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final listing = ref.watch(openPullRequestsProvider(repository));
    final heading = Padding(
      // The field label's gap, in a quieter ink than it: this line says
      // the rows are the other way to link, and the titles under it lead.
      padding: EdgeInsets.only(bottom: tokens.spacing.step2),
      child: Text(
        messages.githubPickerOpenIn(repository.toString()),
        style: tokens.typography.styles.subtitle.subtitle2.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
    );

    final outcome = this.outcome;
    final listed = switch (listing) {
      AsyncData(value: OpenPullRequestsListed(:final available)) =>
        available.any((pr) => pr.ref == picked),
      _ => false,
    };
    final body = switch (listing) {
      AsyncData(value: OpenPullRequestsListed(:final available)) =>
        available.isEmpty
            // Alone: a heading inviting a pick would contradict it.
            ? _Note(text: messages.githubPickerEmpty(repository.toString()))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  _Panel(
                    children: [
                      for (final pr in available) ...[
                        _OpenPullRequestRow(
                          pr: pr,
                          size: ref
                              .watch(openPullRequestSizesProvider(repository))
                              .value?[pr.ref.number],
                          linking: linking == pr.ref,
                          asked: picked == pr.ref,
                          // The row being linked stays live, so it keeps
                          // full strength while the others step back; a
                          // second tap on it is ignored by the form.
                          onTap: !busy || linking == pr.ref
                              ? () => onPick(pr.ref)
                              : null,
                        ),
                        if (outcome != null && picked == pr.ref)
                          Padding(
                            // On the row's own text inset, and closed off
                            // below as one block with it.
                            padding: EdgeInsets.fromLTRB(
                              tokens.spacing.step5 + tokens.spacing.step1,
                              tokens.spacing.step2,
                              tokens.spacing.step5 + tokens.spacing.step1,
                              tokens.spacing.step4,
                            ),
                            child: outcome,
                          ),
                      ],
                    ],
                  ),
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
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading,
          Semantics(
            container: true,
            label: messages.githubPickerLoading,
            child: const _Panel(
              children: [_SkeletonRow(), _SkeletonRow(), _SkeletonRow()],
            ),
          ),
        ],
      ),
    };
    if (outcome == null || listed) return body;
    // Its row is gone — listed anew meanwhile: said above the list instead,
    // never dropped.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        outcome,
        SizedBox(height: tokens.spacing.step5),
        body,
      ],
    );
  }
}

/// The frame around the picker's rows — a hairline on the sheet's own
/// surface, as the field's is — inset so each row's rounded hover fill
/// floats inside its edge.
class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: tokens.spacing.step1),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// One open pull request: its state glyph, number and title, and the line
/// of who opened it, when, and how large it is. Tapping it links it at once,
/// which its trailing link glyph says in the action ink — the one mark on
/// the row in it, a phone having no pointer to light it.
class _OpenPullRequestRow extends StatelessWidget {
  const _OpenPullRequestRow({
    required this.pr,
    required this.size,
    required this.linking,
    required this.asked,
    required this.onTap,
  });

  final OpenPullRequest pr;
  final PullRequestSize? size;
  final bool linking;

  /// What a pick of this pull request came to is shown under it.
  final bool asked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final parts = openPullRequestParts(
      messages,
      pr: pr,
      now: clock.now(),
      size: size,
    );
    return DesignSystemListItem(
      key: LinkPullRequestKeys.openPullRequest(pr.ref.number),
      onTap: onTap,
      activated: linking || asked,
      activatedBackgroundColor: tokens.colors.surface.selected,
      borderRadius: BorderRadius.circular(tokens.radii.m),
      titleContent: PullRequestTitle(
        number: pr.ref.number,
        title: pr.title,
        style: pullRequestTitleStyle(context),
        // As a linked row's: a title is what tells two pull requests apart.
        maxLines: 3,
      ),
      subtitleSpans: pullRequestStatusSpans(context, parts),
      subtitleMaxLines: 2,
      size: DesignSystemListItemSize.small,
      // The card's rails: both at the title, the trailing one centred on
      // the glyph.
      leading: Align(
        alignment: Alignment.topCenter,
        child: PullRequestGlyph(
          status: PullRequestStatus.open,
          draft: pr.draft,
        ),
      ),
      // One slot, one size: the glyph gives way to the spinner without the
      // title reflowing.
      trailingExtra: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: IconSizes.l,
          height: tokens.spacing.step7,
          child: Center(
            // The glyph's size, as every busy state on these surfaces:
            // progress in place, not a larger mark than what it replaces.
            child: linking
                ? DesignSystemSpinner(
                    size: IconSizes.m,
                    semanticsLabel: messages.githubPickerLinking,
                  )
                : Icon(
                    LottiIcons.link,
                    size: IconSizes.m,
                    color: onTap != null
                        ? tokens.colors.interactive.enabled
                        : tokens.colors.text.lowEmphasis,
                  ),
          ),
        ),
      ),
    );
  }
}

/// A row's shape while the pull requests load — glyph, title line, meta
/// line — on the real row's metrics, so the list does not jump when it
/// arrives.
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final lineHeight = tokens.typography.lineHeight;
    // The list item's padding plus the focus border it reserves.
    final inset = tokens.spacing.step1;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5 + inset,
        vertical: tokens.spacing.step3 + inset,
      ),
      child: Row(
        children: [
          DesignSystemSkeleton(
            width: tokens.spacing.step7,
            height: tokens.spacing.step7,
            borderRadius: tokens.radii.s,
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: lineHeight.subtitle2,
                  child: Center(
                    child: DesignSystemSkeleton(height: tokens.spacing.step4),
                  ),
                ),
                SizedBox(height: tokens.spacing.step1),
                SizedBox(
                  height: lineHeight.caption,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DesignSystemSkeleton(
                      width: tokens.spacing.step13,
                      height: tokens.spacing.step3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          // The link glyph's slot and size, so the right edge does not pop
          // in, and reads as a glyph, not a button.
          SizedBox(
            width: IconSizes.l,
            child: Center(
              child: DesignSystemSkeleton(
                width: IconSizes.m,
                height: IconSizes.m,
                borderRadius: tokens.radii.xs,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Other tasks hold the pull request the user chose: link it here too, or
/// leave it where it is. Names the other task when there is one and the
/// viewer may see it.
class _ElsewhereQuestion extends ConsumerWidget {
  const _ElsewhereQuestion({
    required this.taskIds,
    required this.linking,
    required this.onLinkHereToo,
    required this.onKeep,
  });

  final Set<String> taskIds;
  final bool linking;
  final VoidCallback onLinkHereToo;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final titles = watchLinkedElsewhereTitles(ref, taskIds);
    final title = soleLinkedElsewhereTitle(titles);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title != null
              ? messages.githubLinkedElsewhereNamed(title)
              : messages.githubLinkedElsewhere(titles.length),
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        Wrap(
          spacing: tokens.spacing.step3,
          runSpacing: tokens.spacing.step3,
          children: [
            DesignSystemButton(
              key: LinkPullRequestKeys.linkHereToo,
              label: messages.githubLinkHereToo,
              leadingIcon: LottiIcons.link,
              onPressed: linking ? null : onLinkHereToo,
            ),
            DesignSystemButton(
              key: LinkPullRequestKeys.keepElsewhere,
              label: messages.githubLinkElsewhereDecline,
              variant: DesignSystemButtonVariant.secondary,
              onPressed: linking ? null : onKeep,
            ),
          ],
        ),
      ],
    );
  }
}

/// A line of the sheet's own prose: a hint, or — as an [error] — why a
/// pick did not link, announced when it appears as a field's error is.
class _Note extends StatelessWidget {
  const _Note({required this.text, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Semantics(
      container: error,
      liveRegion: error,
      child: Text(
        text,
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: error
              ? tokens.colors.alert.error.ink
              : tokens.colors.text.mediumEmphasis,
        ),
      ),
    );
  }
}
