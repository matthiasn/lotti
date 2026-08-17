import 'dart:async';

import 'package:flutter/material.dart';
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
  ContactAction.call => Icons.call_rounded,
  ContactAction.message => Icons.sms_rounded,
  ContactAction.email => Icons.mail_outline_rounded,
};

String _labelForAction(BuildContext context, ContactAction action) =>
    switch (action) {
      ContactAction.call => context.messages.relationshipActionCall,
      ContactAction.message => context.messages.relationshipActionMessage,
      ContactAction.email => context.messages.relationshipActionEmail,
    };

/// Call / message / email buttons for one contact channel (plan v2 phase 7
/// item 4).
///
/// Only actions the platform can actually service are rendered. The check
/// runs once per channel when the row is built rather than on press, so the
/// user never taps a button that turns out to do nothing — a tablet with no
/// dialer and a desktop with no mail client both simply show fewer buttons.
///
/// A successful launch writes the device-local pending-interaction marker,
/// which is what lets the next resume offer a pre-filled check-in
/// (ADR 0041 D4). A launch the platform refuses writes nothing: there was no
/// conversation to log.
class ContactQuickActions extends ConsumerStatefulWidget {
  const ContactQuickActions({
    required this.relationshipId,
    required this.channel,
    super.key,
  });

  final String relationshipId;
  final ContactChannel channel;

  @override
  ConsumerState<ContactQuickActions> createState() =>
      _ContactQuickActionsState();
}

class _ContactQuickActionsState extends ConsumerState<ContactQuickActions> {
  /// Null until the platform has been asked; empty means "asked, nothing is
  /// available", which renders nothing rather than a row of dead buttons.
  Set<ContactAction>? _available;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveAvailability());
  }

  @override
  void didUpdateWidget(ContactQuickActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Editing the channel's value can change what it can do — a landline
    // corrected to a mobile gains a message button.
    if (oldWidget.channel != widget.channel) {
      unawaited(_resolveAvailability());
    }
  }

  Future<void> _resolveAvailability() async {
    final launcher = ref.read(contactLauncherProvider);
    final offered = contactActionsFor(widget.channel.type);
    final available = <ContactAction>{};

    for (final action in offered) {
      if (await launcher.canLaunch(widget.channel, action)) {
        available.add(action);
      }
    }

    if (!mounted) return;
    setState(() => _available = available);
  }

  Future<void> _handlePressed(ContactAction action) async {
    final launcher = ref.read(contactLauncherProvider);
    final store = ref.read(pendingInteractionStoreProvider);

    final launched = await launcher.launch(widget.channel, action);

    if (!launched) {
      if (!mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.relationshipActionFailed,
      );
      return;
    }

    await store.remember(
      relationshipId: widget.relationshipId,
      interactionType: interactionTypeForAction(action),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final available = _available;
    if (available == null || available.isEmpty) {
      return const SizedBox.shrink();
    }

    // Rendered in ContactAction declaration order so the buttons do not
    // reshuffle between channels.
    final actions = ContactAction.values
        .where(available.contains)
        .toList(growable: false);

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: tokens.spacing.step1,
      children: [
        for (final action in actions)
          IconButton(
            icon: Icon(_iconForAction(action)),
            color: tokens.colors.interactive.enabled,
            tooltip: _labelForAction(context, action),
            onPressed: () => unawaited(_handlePressed(action)),
          ),
      ],
    );
  }
}
