import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// What came back through the doors of one routed turn, under the user's
/// bubble: per segment, who was asked and what they said.
///
/// Specialist text is shown as the specialist's, under its owner's name —
/// never reworded by the front agent (decision 2). A door still being
/// walked, a specialist still replying, and every reason a segment was not
/// taken anywhere each read as one quiet line, so the user always sees what
/// happened to each part of what they said.
class FrontDoorCard extends StatelessWidget {
  const FrontDoorCard({required this.doors, super.key});

  final List<FrontDoorEntry> doors;

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
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Door extends StatelessWidget {
  const _Door({required this.door, super.key});

  final FrontDoorEntry door;

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
          FrontDoorSkipReason.statementsLater =>
            messages.frontDoorStatementsLater,
          FrontDoorSkipReason.noAgent => messages.frontDoorNoAgent(owner),
          FrontDoorSkipReason.inferenceUnavailable =>
            messages.frontDoorInferenceUnavailable(owner),
          FrontDoorSkipReason.noDoor => messages.frontDoorNoDoor,
        },
      ),
      FrontDoorFailed() => (null, messages.frontDoorFailed(owner)),
    };
    final notes = <String>[
      if (record.outcome case FrontDoorAnswer(:final summaryBased))
        if (summaryBased) messages.frontDoorSummaryBased,
      if (record.outcome case FrontDoorAnswer(:final incomplete))
        if (incomplete) messages.frontDoorIncomplete,
    ];

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
          style: caption,
        ),
      ],
    );
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
