import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/relationships/state/contact_link_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Whether *this device* holds an OS-contact ref for the person (plan v2
/// phase 7 item 2, ADR 0041). Refs written by other devices live under their
/// own keys and deliberately do not count: offering "update from contact"
/// for an address book this device does not have would resolve to nothing —
/// or to the wrong person.
bool contactIsLinkedOnThisDevice(
  RelationshipEntry relationship,
  String? refKey,
) {
  if (refKey == null) return false;
  final ref = relationship.data.contactRefs[refKey];
  return ref != null && ref.isNotEmpty;
}

/// Runs one contact-link intent — link, refresh, or re-link — and turns its
/// outcome into the one toast the user should see.
///
/// Neither `noChanges` nor `contactMissing` is a failure, but neither did
/// what the user pressed for, so both read as a warning rather than a success
/// (the design system has no neutral tone). Backing out of the picker is an
/// answer, not a failure, and says nothing.
Future<void> runContactLinkAction(
  BuildContext context,
  WidgetRef ref,
  Future<ContactLinkOutcome> Function(ContactLinkController) action,
) async {
  final outcome = await action(ref.read(contactLinkControllerProvider));
  if (!context.mounted) return;

  final messages = context.messages;
  final (title, tone) = switch (outcome) {
    ContactLinkOutcome.linked => (
      messages.relationshipContactLinked,
      DesignSystemToastTone.success,
    ),
    ContactLinkOutcome.noChanges => (
      messages.relationshipContactNoChanges,
      DesignSystemToastTone.warning,
    ),
    ContactLinkOutcome.contactMissing => (
      messages.relationshipContactMissing,
      DesignSystemToastTone.warning,
    ),
    ContactLinkOutcome.saveFailed => (
      messages.relationshipContactLinkFailed,
      DesignSystemToastTone.error,
    ),
    // `unsupported` cannot arrive here — the menu never offers the intent
    // without an address book — but stays in the switch so a new outcome
    // has to be triaged rather than silently falling through to silence.
    ContactLinkOutcome.cancelled || ContactLinkOutcome.unsupported => (
      null,
      DesignSystemToastTone.warning,
    ),
  };

  if (title == null) return;
  context.showToast(tone: tone, title: title);
}
