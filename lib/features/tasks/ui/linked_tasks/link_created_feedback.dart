import 'package:flutter/material.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/relationship_type_selector.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// How long the undo offer stays reachable.
const _undoWindow = Duration(seconds: 10);

/// Confirms a link that was just created, and offers to take it back.
///
/// Picking a task in the link and blocker pickers commits on the single tap
/// that selects it — deliberately, since that speed is the point of the flow.
/// The cost is that a mis-tap, or the right task under the wrong relation,
/// silently persists a real edge whose only removal path is the card's manage
/// mode. This restores recovery without reintroducing a confirm step: the
/// commit still happens on one tap, and undoing it is one more.
///
/// Shown on [messenger] rather than the modal's own context because the modal
/// pops as part of committing — capture the messenger before popping.
void showLinkCreatedFeedback({
  required BuildContext context,
  required ScaffoldMessengerState messenger,
  required JournalRepository repository,
  required DirectedRelation relation,
  required String fromId,
  required String toId,
  required String linkedTaskTitle,
}) {
  final messages = context.messages;
  final phrase = directedRelationLabel(context, relation);

  messenger.showSnackBar(
    SnackBar(
      content: Text(messages.linkCreatedMessage(phrase, linkedTaskTitle)),
      // Longer than the 4s default. This is the only recovery from a link
      // that commits on a single tap, and it arrives at the bottom of the
      // window while the eye is still on the modal that was just dismissed —
      // at large accessibility text sizes, four seconds is not enough to
      // read it and reach Undo.
      duration: _undoWindow,
      action: SnackBarAction(
        label: messages.linkCreatedUndo,
        onPressed: () async {
          // Same triple the link was written under, so undo can only ever
          // remove the edge this message is about — not some other
          // relationship the two tasks also hold.
          try {
            await repository.removeTypedLink(
              fromId: fromId,
              toId: toId,
              linkType: entryLinkTypeDbName(relation.type),
            );
          } catch (_) {
            // Awaited and reported, matching the unlink path. Fire-and-forget
            // made a failed undo indistinguishable from a successful one, on
            // the one control whose entire job is taking something back.
            messenger.showSnackBar(
              SnackBar(content: Text(messages.unlinkTaskFailedMessage)),
            );
          }
        },
      ),
    ),
  );
}
