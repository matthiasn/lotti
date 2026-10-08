import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/service/contact_launcher.dart';
import 'package:lotti/features/relationships/ui/widgets/contact_quick_actions.dart';
import 'package:lotti/features/speech/ui/widgets/recording/glass_record_button.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The person page's sticky bottom bar (design 2026-09-06 §2–3), replacing
/// the floating button: *Log check-in* · the app's record button · the
/// platform's actionable channel. The same glass strip the task page
/// docks, and the same shape on it — one filled pill, the shared
/// [GlassRecordButton], round glass controls, hugging and centred — so the
/// two pages end the same way. The filled primary never stretches to the
/// column: on a desktop window that made it a bar-wide slab beside two
/// pills, which no other strip in the app does.
///
/// The channel control is the first channel, in the person's own order,
/// that the platform can actually open — a call on a phone, email on a
/// desktop with a mail client, nothing at all where neither exists. The
/// check runs once when the bar is built, like the channel row's buttons,
/// so the user never taps a control that turns out to do nothing.
class RelationshipActionBar extends ConsumerStatefulWidget {
  const RelationshipActionBar({
    required this.relationship,
    required this.onLogCheckIn,
    required this.onSpeak,
    super.key,
  });

  final RelationshipEntry relationship;
  final VoidCallback onLogCheckIn;
  final VoidCallback onSpeak;

  @override
  ConsumerState<RelationshipActionBar> createState() =>
      _RelationshipActionBarState();
}

class _RelationshipActionBarState extends ConsumerState<RelationshipActionBar> {
  /// Null until the platform has been asked; stays null when no channel is
  /// launchable, which renders the bar with two controls.
  ReachableChannel? _reachable;

  /// Bumped per resolution so one that started before the channels changed
  /// cannot land after the newer one and offer a channel that is gone.
  int _resolution = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveReachable());
  }

  @override
  void didUpdateWidget(RelationshipActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // By value: a rebuilt entity with the same channels must not re-probe
    // the platform, and a changed list must, whatever its identity.
    if (!listEquals(
      oldWidget.relationship.data.contactChannels,
      widget.relationship.data.contactChannels,
    )) {
      unawaited(_resolveReachable());
    }
  }

  Future<void> _resolveReachable() async {
    final generation = ++_resolution;
    final found = await firstReachableChannel(
      ref.read(contactLauncherProvider),
      widget.relationship.data.contactChannels,
    );
    if (!mounted || generation != _resolution) return;
    setState(() => _reachable = found);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final messages = context.messages;
    final reachable = _reachable;
    // The glass extends edge to edge and into the home-indicator inset; the
    // controls sit above it (the task bar's rule) and on the page's reading
    // column, so a desktop window does not stretch the pill across it.
    final safeBottomInset = MediaQuery.paddingOf(context).bottom;

    return DesignSystemGlassStrip(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final column = detailContentInsets(
            context,
            availableWidth: constraints.maxWidth,
          );
          return Padding(
            padding: EdgeInsets.fromLTRB(
              column.left,
              spacing.step4,
              column.right,
              spacing.step4 + safeBottomInset,
            ),
            child: _controls(context, tokens, messages, reachable),
          );
        },
      ),
    );
  }

  Widget _controls(
    BuildContext context,
    DsTokens tokens,
    AppLocalizations messages,
    ReachableChannel? reachable,
  ) {
    final spacing = tokens.spacing;

    // Centred and hugging, like the task and entry bars: a `Wrap` rather
    // than a `Row`, so at large text on a narrow phone the controls take a
    // second line instead of overflowing. One filled pill and round glass
    // discs — the channel included. It used to take its word when the row
    // could afford one, which made this the only strip in the app with
    // two pills; the Reach card already shows the bare handset carries the
    // scent here, and the word stays in the control's accessible name.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: spacing.step4,
      runSpacing: spacing.step4,
      children: [
        DsGlassPill(
          key: const ValueKey('person-action-log-check-in'),
          label: messages.relationshipLogCheckIn,
          icon: LottiIcons.greeting,
          fillColor: tokens.colors.interactive.enabled,
          foregroundColor: tokens.colors.text.onInteractiveAlert,
          onTap: widget.onLogCheckIn,
        ),
        // The app's one record button, as the task and entry bars carry
        // it: the accent ring idle, the alert fill while this person's take
        // is running. A labelled "Dictate" pill here was a second mic shape
        // beside the two bars it is meant to match.
        GlassRecordButton(
          key: const ValueKey('person-action-speak'),
          linkedId: widget.relationship.id,
          onPressed: widget.onSpeak,
        ),
        if (reachable != null)
          DsGlassRoundButton(
            key: const ValueKey('person-action-channel'),
            icon: contactActionIcon(reachable.action),
            semanticLabel: contactActionLabel(context, reachable.action),
            onPressed: () => unawaited(
              launchContactAction(
                context,
                ref,
                relationshipId: widget.relationship.id,
                channel: reachable.channel,
                action: reachable.action,
              ),
            ),
          ),
      ],
    );
  }
}
