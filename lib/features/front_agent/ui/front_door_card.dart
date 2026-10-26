import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// What the user can do under a door. Every callback takes the door's id;
/// the surface decides what each one writes.
class FrontDoorActions {
  const FrontDoorActions({
    required this.onFile,
    required this.onDecline,
    required this.onUnfile,
    required this.onMakeTask,
    required this.onSaveNote,
    required this.onStartGoal,
    required this.onNewProject,
  });

  /// File the proposal under its task — the one tap of decision 1.
  final ValueChanged<String> onFile;

  /// Do not file the proposal.
  final ValueChanged<String> onDecline;

  /// Take a filed entry back out.
  final ValueChanged<String> onUnfile;

  /// Make a task of an inbox item.
  final ValueChanged<String> onMakeTask;

  /// Save an inbox item as a note.
  final ValueChanged<String> onSaveNote;

  /// Open the goal wizard for an inbox item.
  final ValueChanged<String> onStartGoal;

  /// Open the project creation for an inbox item.
  final ValueChanged<String> onNewProject;
}

/// What came back through the doors of one routed turn, under the user's
/// bubble: per segment, who was asked and what they said — or what waits
/// for the user: a proposal to file their words under a task, with its one
/// tap (decision 1), or an inbox item with the chips that take it
/// somewhere.
///
/// Specialist text is shown as the specialist's, under its owner's name —
/// never reworded by the front agent (decision 2). A door still being
/// walked, a specialist still replying, and every reason a segment was not
/// taken anywhere each read as one quiet line, so the user always sees what
/// happened to each part of what they said.
class FrontDoorCard extends StatelessWidget {
  const FrontDoorCard({
    required this.doors,
    this.actions,
    this.busyDoorIds = const {},
    this.failedDoorIds = const {},
    super.key,
  });

  final List<FrontDoorEntry> doors;

  /// Null renders the card without its buttons and chips.
  final FrontDoorActions? actions;

  /// Doors whose action is in flight: their controls are disabled.
  final Set<String> busyDoorIds;

  /// Doors whose last action did not go through: they say so, and offer
  /// the controls again.
  final Set<String> failedDoorIds;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level01,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, door) in doors.indexed) ...[
              if (index > 0) SizedBox(height: tokens.spacing.step3),
              _Door(
                key: ValueKey('front-door-${door.record.segmentIndex}'),
                door: door,
                actions: actions,
                busy: busyDoorIds.contains(door.doorId),
                failed: failedDoorIds.contains(door.doorId),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Door extends StatelessWidget {
  const _Door({
    required this.door,
    required this.actions,
    required this.busy,
    required this.failed,
    super.key,
  });

  final FrontDoorEntry door;
  final FrontDoorActions? actions;
  final bool busy;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final record = door.record;
    final owner = _ownerName(messages, record);
    final caption = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final body = tokens.typography.styles.body.bodyMedium.copyWith(
      color: tokens.colors.text.highEmphasis,
    );

    final (String? text, String status) = switch (record.outcome) {
      null => (null, messages.frontDoorWalking(owner)),
      FrontDoorAnswer(:final text) => (
        text,
        messages.frontDoorAttribution(owner),
      ),
      FrontDoorChatTurn() when door.specialistReply != null => (
        door.specialistReply,
        messages.frontDoorAttribution(owner),
      ),
      FrontDoorChatTurn() => (null, messages.frontDoorAwaitingReply(owner)),
      FrontDoorSkipped(:final reason) => (
        null,
        switch (reason) {
          FrontDoorSkipReason.noAgent => messages.frontDoorNoAgent(owner),
          FrontDoorSkipReason.inferenceUnavailable =>
            messages.frontDoorInferenceUnavailable(owner),
          FrontDoorSkipReason.noDoor => messages.frontDoorNoDoor,
        },
      ),
      FrontDoorFailed() => (null, messages.frontDoorFailed(owner)),
      FrontDoorProposal(:final unfiled) => (
        null,
        unfiled
            ? messages.frontDoorUnfiled(owner)
            : messages.frontDoorProposal(owner),
      ),
      FrontDoorFiled(:final ownerId) => (
        null,
        ownerId == null
            ? messages.frontDoorSavedAsNote
            : messages.frontDoorFiledUnder(owner),
      ),
      FrontDoorDeclined() => (null, messages.frontDoorDeclined),
      FrontDoorInbox() => (null, messages.frontDoorInbox),
      FrontDoorTaskCreated() => (null, messages.frontDoorTaskCreated),
    };
    final notes = <String>[
      if (record.outcome case FrontDoorAnswer(:final summaryBased))
        if (summaryBased) messages.frontDoorSummaryBased,
      if (record.outcome case FrontDoorAnswer(:final incomplete))
        if (incomplete) messages.frontDoorIncomplete,
      if (failed) messages.frontDoorActionFailed,
    ];
    final controls = actions == null
        ? null
        : _controls(context, actions!, record.outcome);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The segment this door answers, quoted, so a multi-part turn reads
        // part by part.
        Text(
          '“${record.text}”',
          key: ValueKey('front-door-segment-${record.segmentIndex}'),
          style: caption.copyWith(fontStyle: FontStyle.italic),
        ),
        if (text != null) ...[
          SizedBox(height: tokens.spacing.step1),
          Text(
            text,
            key: ValueKey('front-door-text-${record.segmentIndex}'),
            style: body,
          ),
        ],
        SizedBox(height: tokens.spacing.step1),
        Text(
          [status, ...notes].join(' · '),
          key: ValueKey('front-door-status-${record.segmentIndex}'),
          style: caption.copyWith(
            color: failed ? tokens.colors.alert.error.ink : null,
          ),
        ),
        if (controls != null) ...[
          SizedBox(height: tokens.spacing.step2),
          controls,
        ],
      ],
    );
  }

  /// The controls an outcome offers, or null when it offers none.
  Widget? _controls(
    BuildContext context,
    FrontDoorActions actions,
    FrontDoorOutcome? outcome,
  ) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final id = door.doorId;
    final index = door.record.segmentIndex;
    void Function()? guarded(VoidCallback action) => busy ? null : action;

    switch (outcome) {
      case FrontDoorProposal():
        // One tap files; a quiet exit does not out-shout it.
        return Wrap(
          spacing: tokens.spacing.step2,
          runSpacing: tokens.spacing.step2,
          children: [
            DesignSystemButton(
              key: ValueKey('front-door-file-$index'),
              label: messages.frontDoorFile,
              onPressed: guarded(() => actions.onFile(id)),
            ),
            DesignSystemButton(
              key: ValueKey('front-door-decline-$index'),
              label: messages.frontDoorNotThis,
              variant: DesignSystemButtonVariant.tertiary,
              onPressed: guarded(() => actions.onDecline(id)),
            ),
          ],
        );
      case FrontDoorFiled(:final ownerId) when ownerId != null:
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: DesignSystemButton(
            key: ValueKey('front-door-unfile-$index'),
            label: messages.frontDoorUnfile,
            variant: DesignSystemButtonVariant.tertiary,
            onPressed: guarded(() => actions.onUnfile(id)),
          ),
        );
      case FrontDoorInbox(:final newKind):
        // What the router thought it would become leads; the rest follow.
        final chips = <(String, String, IconData, ValueChanged<String>)>[
          (
            'task',
            messages.frontDoorMakeTask,
            LottiIcons.confirmCircled,
            actions.onMakeTask,
          ),
          (
            'goal',
            messages.frontDoorStartGoal,
            LottiIcons.focus,
            actions.onStartGoal,
          ),
          if (newKind == FrontNewKind.project)
            (
              'project',
              messages.frontDoorNewProject,
              LottiIcons.folder,
              actions.onNewProject,
            ),
          (
            'note',
            messages.frontDoorSaveNote,
            LottiIcons.note,
            actions.onSaveNote,
          ),
        ];
        final leadName = switch (newKind) {
          FrontNewKind.task => 'task',
          FrontNewKind.goal => 'goal',
          FrontNewKind.project => 'project',
          null => null,
        };
        chips.sort((a, b) {
          if (a.$1 == leadName) return -1;
          if (b.$1 == leadName) return 1;
          return 0;
        });
        return Wrap(
          spacing: tokens.spacing.step2,
          runSpacing: tokens.spacing.step2,
          children: [
            for (final (name, label, icon, action) in chips)
              DesignSystemChip(
                key: ValueKey('front-door-$name-$index'),
                label: label,
                leadingIcon: icon,
                size: DesignSystemChipSize.compactPillTouch,
                outlined: true,
                onPressed: guarded(() => action(id)),
              ),
          ],
        );
      case _:
        return null;
    }
  }

  /// The owner's title when the walker found one, else the kind of thing
  /// the segment went to, so the line never names an id.
  static String _ownerName(AppLocalizations messages, FrontDoorRecord record) {
    final title = record.ownerTitle?.trim();
    if (title != null && title.isNotEmpty) return title;
    return switch (record.kind) {
      FrontDestinationKind.task => messages.frontDoorKindTask,
      FrontDestinationKind.project => messages.frontDoorKindProject,
      FrontDestinationKind.goal => messages.frontDoorKindGoal,
      FrontDestinationKind.person => messages.frontDoorKindPerson,
      FrontDestinationKind.day ||
      FrontDestinationKind.newThing ||
      FrontDestinationKind.journal ||
      FrontDestinationKind.unrouted => messages.frontDoorKindOther,
    };
  }
}
