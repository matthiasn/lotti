import 'package:flutter/material.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/relationship_type_selector.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// How long the undo offer stays reachable.
///
/// Longer than the toast default: this is the only recovery from a link that
/// commits on a single tap, and it arrives at the bottom of the window while
/// the eye is still on the modal that was just dismissed. At large
/// accessibility text sizes four seconds is not enough to read it and reach
/// Undo. The countdown strip makes the remaining window visible rather than
/// leaving it to be guessed.
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

  messenger.showDesignSystemToast(
    tone: DesignSystemToastTone.success,
    // Relation in the title, task in the description: the toast caps its
    // title at one line, and the relation phrase plus a real task title ran
    // past it — ellipsizing away the one fact the message exists to record,
    // on a flow that commits without confirming. The description slot takes
    // two lines and is what the component is for.
    title: phrase,
    description: linkedTaskTitle,
    duration: _undoWindow,
    countdown: true,
    replaceCurrent: true,
    action: ToastAction(
      label: messages.linkCreatedUndo,
      onPressed: () async {
        // Dismiss first: without it the confirmation, its live Undo control
        // and the draining countdown all stayed on screen asserting a link
        // that no longer exists — and the control could be pressed again.
        messenger.hideCurrentSnackBar();
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
          showLinkFailureMessage(
            messenger: messenger,
            message: messages.unlinkTaskFailedMessage,
          );
        }
      },
    ),
  );
}

/// Reports a failure in the linking flow.
///
/// On the design system's own error toast rather than a hand-built SnackBar:
/// a rejected cycle, a failed unlink, a failed retype and a failed undo all
/// arrived on the same slab as the "link created" confirmation, tinted by
/// whichever colour scheme the user happens to have chosen. The one moment
/// the flow has to say *no* looked exactly like the moment it says yes — and
/// a hand-picked ink on an alert fill was near-black on dark red in light
/// theme. The component owns both the tone and its on-colour.
void showLinkFailureMessage({
  required ScaffoldMessengerState messenger,
  required String message,
}) {
  messenger.showDesignSystemToast(
    tone: DesignSystemToastTone.error,
    title: message,
    replaceCurrent: true,
  );
}
