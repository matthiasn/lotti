import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_modal.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_row.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/person_name.dart';
import 'package:lotti/features/relationships/service/contact_launcher.dart';
import 'package:lotti/features/relationships/ui/widgets/contact_quick_actions.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form_modal.dart';
import 'package:lotti/features/relationships/util/contact_channel_uri.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The person's ways to reach them, under their name: one labelled button per
/// action this device can actually service — *Call*, *Message*, *Email* —
/// never a row of unlabelled glyphs, and never a button that turns out to do
/// nothing (design panel 2026-10-15).
///
/// A call is never placed by one tap. *Call* opens a sheet that names the
/// person and lists the numbers it can dial; choosing one is the
/// confirmation, so a person with several numbers is asked which, and a
/// mis-tap on the page costs a sheet, not a call. Messages and emails, which
/// the user still has to write and send, open at once when there is a single
/// channel for them.
///
/// Renders nothing until the platform has answered, and nothing for a person
/// without a launchable channel. A launch writes the pending-interaction
/// marker as everywhere else ([launchContactAction]), so coming back offers
/// to log what happened.
class PersonContactRow extends ConsumerStatefulWidget {
  const PersonContactRow({
    required this.relationship,
    this.trailing = const [],
    super.key,
  });

  final RelationshipEntry relationship;

  /// Controls that flow on after the contact verbs in the same row — the
  /// header's reminders control — so a phone gets one row of actions, not
  /// an orphaned second line.
  final List<Widget> trailing;

  @override
  ConsumerState<PersonContactRow> createState() => _PersonContactRowState();
}

class _PersonContactRowState extends ConsumerState<PersonContactRow> {
  /// The channels each action can reach, in the person's own order. Null
  /// until the platform has been asked.
  Map<ContactAction, List<ContactChannel>>? _reachable;

  /// Which resolution is current: a probe that finishes after the channels
  /// changed again answers for channels the person no longer has.
  var _generation = 0;

  List<ContactChannel> get _channels =>
      widget.relationship.data.contactChannels;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(PersonContactRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.relationship.data.contactChannels != _channels) {
      // The old answers name channels that may be gone: offer nothing until
      // the new ones are known, rather than a button that dials a removed
      // number.
      setState(() => _reachable = null);
      _resolve();
    }
  }

  /// Asks the platform which actions each channel can take. Started from
  /// `initState` without awaiting, so it owns its errors: a channel the
  /// platform cannot answer for is one the row does not offer.
  Future<void> _resolve() async {
    final generation = ++_generation;
    final channels = _channels;
    final launcher = ref.read(contactLauncherProvider);
    final reachable = <ContactAction, List<ContactChannel>>{};
    for (final channel in channels) {
      for (final action in contactActionsFor(channel.type)) {
        bool launchable;
        try {
          launchable = await launcher.canLaunch(channel, action);
        } catch (_) {
          launchable = false;
        }
        if (launchable) {
          reachable.putIfAbsent(action, () => []).add(channel);
        }
      }
    }
    if (!mounted || generation != _generation) return;
    setState(() => _reachable = reachable);
  }

  String get _name => widget.relationship.shortName;

  Future<void> _pressed(
    ContactAction action,
    List<ContactChannel> channels,
  ) async {
    final messages = context.messages;
    final channel = action != ContactAction.call && channels.length == 1
        ? channels.single
        : await DsActionModal.show<ContactChannel>(
            context: context,
            title: switch (action) {
              ContactAction.call => messages.relationshipCallConfirmTitle(
                _name,
              ),
              _ => contactActionLabel(context, action),
            },
            builder: (sheetContext) => DsActionModalList(
              children: [
                for (final channel in channels)
                  DsActionRow(
                    key: ValueKey('person-contact-choice-${channel.value}'),
                    icon: contactActionIcon(action),
                    title: channel.value,
                    subtitle: _labelOf(sheetContext, channel),
                    tone: DsActionRowTone.accent,
                    onTap: () => Navigator.of(sheetContext).pop(channel),
                  ),
              ],
            ),
          );
    if (channel == null || !mounted) return;
    await launchContactAction(
      context,
      ref,
      relationshipId: widget.relationship.meta.id,
      channel: channel,
      action: action,
    );
  }

  String _labelOf(BuildContext context, ContactChannel channel) {
    final label = channel.label?.trim();
    return label == null || label.isEmpty
        ? contactChannelTypeLabel(context, channel.type)
        : label;
  }

  @override
  Widget build(BuildContext context) {
    final reachable = _reachable ?? const {};
    final trailing = widget.trailing;
    if (reachable.isEmpty && trailing.isEmpty) return const SizedBox.shrink();
    final tokens = context.designTokens;
    return Wrap(
      key: const ValueKey('person-contact-row'),
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Declaration order, so the buttons never reshuffle between people.
        for (final action in ContactAction.values)
          if (reachable[action] case final channels?)
            DesignSystemButton(
              key: ValueKey('person-contact-${action.name}'),
              label: contactActionLabel(context, action),
              leadingIcon: contactActionIcon(action),
              variant: DesignSystemButtonVariant.secondary,
              // Dense: the header's actions sit under the name in one row on
              // a phone, and must not outrank the section headings below.
              size: DesignSystemButtonSize.dense,
              onPressed: () => _pressed(action, channels),
            ),
        ...trailing,
      ],
    );
  }
}
