import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// What the user can do under a door. Every callback takes the door's id,
/// except [onOpen], which needs what the door wrote; the surface decides
/// what each one writes or opens.
class FrontDoorActions {
  const FrontDoorActions({
    required this.onFile,
    required this.onDecline,
    required this.onUndoDecline,
    required this.onTakeBack,
    required this.onOpen,
    required this.onMakeTask,
    required this.onSaveNote,
    required this.onStartGoal,
    required this.onNewProject,
  });

  /// File the proposal under its task — the one tap of decision 1.
  final ValueChanged<String> onFile;

  /// Say no to what a waiting door offers: a proposal's words go to the
  /// inbox, an inbox item is left where it is.
  final ValueChanged<String> onDecline;

  /// A left door waits again as what it was.
  final ValueChanged<String> onUndoDecline;

  /// Take back what the door wrote: the filed entry, the note or the task.
  final ValueChanged<String> onTakeBack;

  /// Open what the door wrote.
  final ValueChanged<FrontDoorEntry> onOpen;

  /// Make a task of an inbox item.
  final ValueChanged<String> onMakeTask;

  /// Save an inbox item as a note.
  final ValueChanged<String> onSaveNote;

  /// Open the goal wizard for an inbox item.
  final ValueChanged<String> onStartGoal;

  /// Open the project creation for an inbox item.
  final ValueChanged<String> onNewProject;
}

/// The segment a door answers, quoted on one line: cut at a word boundary
/// inside [budget] characters, with the closing mark kept, so a long
/// segment never ends in a sliced word and an open quote.
String frontDoorQuote(String text, {int budget = 44}) {
  final trimmed = text.trim();
  if (trimmed.length <= budget) return '“$trimmed”';
  final cut = trimmed.lastIndexOf(' ', budget);
  final head =
      (cut > 0 ? trimmed.substring(0, cut) : trimmed.substring(0, budget))
          .trimRight();
  return '“$head…”';
}

/// What came back through the doors of one routed turn: her answer, part
/// by part. It sits inside her reply bubble under her own line
/// ([embedded]), a hairline between the two; until she has replied it
/// hangs off the user's bubble on a rail — never a third bubble between
/// theirs and hers.
///
/// One door per segment, a hairline between doors. Each door is labelled
/// by the part it answers — the quoted segment, set apart by weight, is
/// where the eye lands — and under the label sits what came of it: an
/// owner's answer in body type, or a question or receipt a tier below.
/// A settled or failed door carries a glyph so its state is more than a
/// shade of grey. One physical rule in every door: the tap that writes
/// leads the row, filled (decision 1); the way out that writes nothing sits
/// at the trailing edge, quiet; other ways follow on their own line.
///
/// Specialist text is shown as the specialist's, under its owner's name —
/// never reworded by the front agent (decision 2).
class FrontDoorCard extends StatelessWidget {
  const FrontDoorCard({
    required this.doors,
    this.actions,
    this.busyDoorIds = const {},
    this.failedDoorIds = const {},
    this.embedded = false,
    super.key,
  });

  final List<FrontDoorEntry> doors;

  /// Null renders the card without its controls.
  final FrontDoorActions? actions;

  /// Doors whose action is in flight: their controls are disabled.
  final Set<String> busyDoorIds;

  /// Doors whose last action did not go through: they say so, and offer
  /// the controls again.
  final Set<String> failedDoorIds;

  /// Inside her bubble, under her line: a hairline below her line rather
  /// than a rail of its own.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final hairline = tokens.colors.decorative.level02;
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, door) in doors.indexed) ...[
          if (index > 0 || embedded)
            Padding(
              // A wider step above every rule than below it, so a row
              // never sits on the line beneath it.
              padding: EdgeInsets.only(
                top: tokens.spacing.step3,
                bottom: tokens.spacing.step2,
              ),
              child: DesignSystemDivider(color: hairline),
            ),
          _Door(
            key: ValueKey('front-door-${door.record.segmentIndex}'),
            door: door,
            actions: actions,
            busy: busyDoorIds.contains(door.doorId),
            failed: failedDoorIds.contains(door.doorId),
            // One door is the whole bubble right above it; labelling it
            // with its own words would say them twice.
            labelled: doors.length > 1,
          ),
        ],
      ],
    );
    if (embedded) return column;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: tokens.colors.decorative.level03),
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: tokens.spacing.step4,
          top: tokens.spacing.step1,
          bottom: tokens.spacing.step1,
        ),
        child: column,
      ),
    );
  }
}

/// The tier a door's line sits at.
enum _Tier {
  /// Asks the user for something: a proposal's question, where an inbox
  /// item should go.
  ask,

  /// An owner's or a specialist's words.
  answer,

  /// Reports what happened, or is happening.
  report,
}

class _Door extends StatelessWidget {
  const _Door({
    required this.door,
    required this.actions,
    required this.busy,
    required this.failed,
    required this.labelled,
    super.key,
  });

  final FrontDoorEntry door;
  final FrontDoorActions? actions;
  final bool busy;
  final bool failed;

  /// Whether the segment labels the door.
  final bool labelled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final record = door.record;
    final owner = _ownerName(messages, record);
    final index = record.segmentIndex;
    final styles = tokens.typography.styles;
    // The label is the segment, the one semibold in a door; an answer is
    // content, in body type; a question or a receipt sits a size under it,
    // in the same ink; attribution and caveats are captions.
    final label = bodyLabelStyle(tokens, small: true);
    final content = styles.body.bodyMedium.copyWith(
      color: tokens.colors.text.highEmphasis,
    );
    final line = styles.body.bodySmall.copyWith(
      color: tokens.colors.text.highEmphasis,
    );
    final aside = styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final success = tokens.colors.alert.success.ink;
    final error = tokens.colors.alert.error.ink;

    final (
      InlineSpan text,
      _Tier tier,
      IconData? glyph,
      Color? ink,
    ) = switch (record.outcome) {
      null => (
        TextSpan(text: messages.frontDoorWalking(owner)),
        _Tier.report,
        null,
        null,
      ),
      FrontDoorAnswer(:final text) => (
        TextSpan(text: text),
        _Tier.answer,
        null,
        null,
      ),
      FrontDoorChatTurn() when door.specialistReply != null => (
        TextSpan(text: door.specialistReply),
        _Tier.answer,
        null,
        null,
      ),
      FrontDoorChatTurn() => (
        TextSpan(text: messages.frontDoorAwaitingReply(owner)),
        _Tier.report,
        null,
        null,
      ),
      FrontDoorSkipped(:final reason) => (
        TextSpan(
          text: switch (reason) {
            FrontDoorSkipReason.noAgent => messages.frontDoorNoAgent(owner),
            FrontDoorSkipReason.inferenceUnavailable =>
              messages.frontDoorInferenceUnavailable(owner),
            FrontDoorSkipReason.noDoor => messages.frontDoorNoDoor,
          },
        ),
        _Tier.report,
        null,
        null,
      ),
      FrontDoorFailed() => (
        TextSpan(text: messages.frontDoorFailed(owner)),
        _Tier.report,
        LottiIcons.warning,
        error,
      ),
      FrontDoorProposal(:final unfiled) => (
        TextSpan(
          text: unfiled
              ? messages.frontDoorUnfiled(owner)
              : messages.frontDoorProposal(owner),
        ),
        _Tier.ask,
        null,
        null,
      ),
      FrontDoorInbox(:final ownerId) => (
        TextSpan(
          text: ownerId == null
              ? messages.frontDoorInbox
              : messages.frontDoorInboxInstead,
        ),
        _Tier.ask,
        null,
        null,
      ),
      FrontDoorFiled(:final ownerId) => (
        ownerId == null
            ? TextSpan(text: messages.frontDoorSavedAsNote)
            : TextSpan(text: messages.frontDoorFiledUnder(owner)),
        _Tier.report,
        LottiIcons.confirmCircled,
        success,
      ),
      FrontDoorDeclined(:final ownerId) => (
        TextSpan(
          text: ownerId == null
              ? messages.frontDoorLeft
              : messages.frontDoorDeclined,
        ),
        _Tier.report,
        null,
        null,
      ),
      FrontDoorTaskCreated() => (
        TextSpan(text: messages.frontDoorTaskCreated),
        _Tier.report,
        LottiIcons.confirmCircled,
        success,
      ),
    };
    final lineStyle = switch (tier) {
      _Tier.answer => content,
      _Tier.ask || _Tier.report => line,
    };

    // A tier below the line: who answered, with what caveat.
    final asides = <String>[
      if (tier == _Tier.answer) messages.frontDoorAttribution(owner),
      if (record.outcome case FrontDoorAnswer(:final summaryBased))
        if (summaryBased) messages.frontDoorSummaryBased,
      if (record.outcome case FrontDoorAnswer(:final incomplete))
        if (incomplete) messages.frontDoorIncomplete,
    ];
    final controls = actions == null
        ? null
        : _controls(context, actions!, record.outcome);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelled) ...[
          // The part this door answers, on one line; the bubble above has
          // it whole.
          Text(
            frontDoorQuote(record.text),
            key: ValueKey('front-door-segment-$index'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            semanticsLabel: record.text,
            style: label,
          ),
          SizedBox(height: tokens.spacing.step1),
        ],
        Text.rich(
          _withGlyph(text, glyph, ink, ValueKey('front-door-glyph-$index')),
          key: ValueKey('front-door-text-$index'),
          style: lineStyle,
        ),
        if (asides.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.step1),
          Text(
            asides.join(' · '),
            key: ValueKey('front-door-status-$index'),
            style: aside,
          ),
        ],
        if (failed) ...[
          SizedBox(height: tokens.spacing.step2),
          Text.rich(
            _withGlyph(
              TextSpan(text: messages.frontDoorActionFailed),
              LottiIcons.warning,
              error,
              ValueKey('front-door-failed-glyph-$index'),
            ),
            key: ValueKey('front-door-failed-$index'),
            style: line.copyWith(color: error),
          ),
        ],
        if (controls != null) ...[
          // An ask breathes before its tap; a receipt keeps its ways close.
          SizedBox(
            height: tier == _Tier.ask
                ? tokens.spacing.step3
                : tokens.spacing.step2,
          ),
          controls,
        ],
      ],
    );
  }

  /// [line] with [glyph] on its first line, when it has one.
  static InlineSpan _withGlyph(
    InlineSpan line,
    IconData? glyph,
    Color? ink,
    Key glyphKey,
  ) {
    if (glyph == null) return line;
    return TextSpan(
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(glyph, key: glyphKey, size: IconSizes.s, color: ink),
        ),
        const TextSpan(text: ' '),
        line,
      ],
    );
  }

  /// The controls an outcome offers, or null when it offers none. One
  /// physical rule: the tap that writes leads the row, filled; the way out
  /// that writes nothing sits at the trailing edge, quiet; other ways
  /// follow on their own line. Every control is the same size, shrunk to
  /// its words, so the words — not tap slack — set the rhythm.
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

    Widget primary(String name, String label, VoidCallback action) =>
        DesignSystemButton(
          key: ValueKey('front-door-$name-$index'),
          label: label,
          isLoading: busy,
          onPressed: guarded(action),
        );
    Widget quiet(
      String name,
      String label,
      VoidCallback action, {
      IconData? icon,
      bool leads = false,
      bool trails = false,
    }) => DesignSystemButton(
      key: ValueKey('front-door-$name-$index'),
      label: label,
      leadingIcon: icon,
      variant: DesignSystemButtonVariant.quiet,
      alignsLabelToLeadingEdge: leads,
      alignsLabelToTrailingEdge: trails,
      onPressed: guarded(action),
    );
    Widget row(Widget leading, Widget trailing) => Row(
      children: [leading, const Spacer(), trailing],
    );

    switch (outcome) {
      case FrontDoorProposal():
        // The one tap, filled; after a failure it reads as the retry it is.
        // Saying no sends the words to the inbox, and says so.
        return row(
          primary(
            'file',
            failed ? messages.frontDoorTryAgain : messages.frontDoorFile,
            () => actions.onFile(id),
          ),
          quiet('decline', messages.frontDoorNotThis, () {
            actions.onDecline(id);
          }, trails: true),
        );
      case FrontDoorDeclined():
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: quiet(
            'undo',
            messages.frontDoorUndo,
            () => actions.onUndoDecline(id),
            leads: true,
          ),
        );
      case FrontDoorFiled() || FrontDoorTaskCreated():
        // What was written can be opened, and undone — the undo at the far
        // edge, away from the tap that merely looks.
        return row(
          quiet(
            'open',
            messages.frontDoorOpen,
            () => actions.onOpen(door),
            leads: true,
          ),
          quiet('take-back', messages.frontDoorUndo, () {
            actions.onTakeBack(id);
          }, trails: true),
        );
      case FrontDoorInbox(:final newKind):
        // The tap that writes in place — a task — leads; leaving it sits at
        // the far edge; the ways that open a wizard, or keep the words as
        // they are, follow on their own line, the router's guess first.
        final ways = <(String, String, IconData, ValueChanged<String>)>[
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
        final guess = switch (newKind) {
          FrontNewKind.goal => 'goal',
          FrontNewKind.project => 'project',
          FrontNewKind.task || null => null,
        };
        ways.sort((a, b) {
          if (a.$1 == guess) return -1;
          if (b.$1 == guess) return 1;
          return 0;
        });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row(
              primary('task', messages.frontDoorMakeTask, () {
                actions.onMakeTask(id);
              }),
              quiet('decline', messages.frontDoorLeaveIt, () {
                actions.onDecline(id);
              }, trails: true),
            ),
            SizedBox(height: tokens.spacing.step1),
            Wrap(
              spacing: tokens.spacing.step2,
              runSpacing: tokens.spacing.step1,
              children: [
                for (final (i, (name, label, icon, action)) in ways.indexed)
                  quiet(
                    name,
                    label,
                    () => action(id),
                    icon: icon,
                    leads: i == 0,
                  ),
              ],
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
