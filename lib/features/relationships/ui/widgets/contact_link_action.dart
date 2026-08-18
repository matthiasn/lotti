import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/relationships/service/contacts_service.dart';
import 'package:lotti/features/relationships/state/contact_import_controller.dart';
import 'package:lotti/features/relationships/state/contact_link_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// What a linked person's overflow menu offers.
enum _LinkMenuChoice { refresh, relink }

/// Links a person to an OS contact, or refreshes the one they already have
/// (plan v2 phase 7 item 2, ADR 0041).
///
/// Renders nothing where there is no address book, so the desktop app — which
/// enters channels by hand (ADR 0041 §2) — never shows an action it cannot
/// perform.
///
/// A person with no link on this device gets a single button. A person who is
/// already linked gets a menu, because "copy anything new across" and "point
/// this at a different contact" are genuinely different intents and silently
/// picking one would be wrong either way.
class ContactLinkAction extends ConsumerWidget {
  const ContactLinkAction({required this.relationship, super.key});

  final RelationshipEntry relationship;

  bool get _isLinked {
    final ref = relationship.data.contactRefs[contactRefPlatformKey()];
    return ref != null && ref.isNotEmpty;
  }

  Future<void> _run(
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
      // Neither is a failure, but neither did what the user pressed for,
      // so both read as a warning rather than a success. The design system
      // has no neutral tone.
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
      // Backing out of the picker is an answer, not a failure. `unsupported`
      // cannot arrive here at all — the action is not rendered without an
      // address book — but stays in the switch so a new outcome has to be
      // triaged rather than silently falling through to silence.
      ContactLinkOutcome.cancelled || ContactLinkOutcome.unsupported => (
        null,
        DesignSystemToastTone.warning,
      ),
    };

    if (title == null) return;
    context.showToast(tone: tone, title: title);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.read(contactsServiceProvider).isSupported) {
      return const SizedBox.shrink();
    }

    if (!_isLinked) {
      return IconButton(
        tooltip: context.messages.relationshipLinkContact,
        icon: const Icon(Icons.person_search_rounded),
        onPressed: () => _run(
          context,
          ref,
          (controller) => controller.linkContact(
            relationship,
          ),
        ),
      );
    }

    return PopupMenuButton<_LinkMenuChoice>(
      tooltip: context.messages.relationshipUpdateFromContact,
      icon: const Icon(Icons.contact_page_rounded),
      onSelected: (choice) => _run(
        context,
        ref,
        (controller) => switch (choice) {
          _LinkMenuChoice.refresh => controller.refreshFromContact(
            relationship,
          ),
          _LinkMenuChoice.relink => controller.linkContact(relationship),
        },
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _LinkMenuChoice.refresh,
          child: Text(context.messages.relationshipUpdateFromContact),
        ),
        PopupMenuItem(
          value: _LinkMenuChoice.relink,
          child: Text(context.messages.relationshipRelinkContact),
        ),
      ],
    );
  }
}
