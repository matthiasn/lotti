import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/service/contact_launcher.dart';
import 'package:lotti/features/relationships/service/pending_interaction_store.dart';
import 'package:lotti/features/relationships/util/contact_channel_uri.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The check-in an action would eventually be logged as.
///
/// Email maps to [CheckInInteractionType.message] because the check-in
/// vocabulary (ADR 0038) has no separate email kind and both are "I wrote to
/// them" rather than "we spoke". The user can change it in the capture sheet;
/// this only decides what the prompt starts on.
CheckInInteractionType interactionTypeForAction(ContactAction action) =>
    switch (action) {
      ContactAction.call => CheckInInteractionType.call,
      ContactAction.message ||
      ContactAction.email => CheckInInteractionType.message,
    };

IconData _iconForAction(ContactAction action) => switch (action) {
  ContactAction.call => LottiIcons.call,
  ContactAction.message => LottiIcons.sms,
  ContactAction.email => LottiIcons.mail,
};

String _labelForAction(BuildContext context, ContactAction action) =>
    switch (action) {
      ContactAction.call => context.messages.relationshipActionCall,
      ContactAction.message => context.messages.relationshipActionMessage,
      ContactAction.email => context.messages.relationshipActionEmail,
    };

/// The icon a contact action wears wherever it is offered.
IconData contactActionIcon(ContactAction action) => _iconForAction(action);

/// The localized label of a contact action.
String contactActionLabel(BuildContext context, ContactAction action) =>
    _labelForAction(context, action);

/// Hands [channel] to the platform for [action] and, on success, writes the
/// device-local pending-interaction marker the next resume turns into a
/// pre-filled check-in offer (ADR 0041 D4). A launch the platform refuses
/// writes nothing — there was no conversation to log — and says so.
///
/// Shared by the person page's contact row and every other place a channel
/// is launched, so each remembers a placed call the same way.
Future<void> launchContactAction(
  BuildContext context,
  WidgetRef ref, {
  required String relationshipId,
  required ContactChannel channel,
  required ContactAction action,
}) async {
  final launcher = ref.read(contactLauncherProvider);
  final store = ref.read(pendingInteractionStoreProvider);
  final messages = context.messages;

  final launched = await launcher.launch(channel, action);

  if (!launched) {
    if (!context.mounted) return;
    context.showToast(
      tone: DesignSystemToastTone.error,
      title: messages.relationshipActionFailed,
    );
    return;
  }

  await store.remember(
    relationshipId: relationshipId,
    interactionType: interactionTypeForAction(action),
  );
}
