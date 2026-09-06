import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/service/contact_launcher.dart';
import 'package:lotti/features/relationships/ui/widgets/contact_quick_actions.dart';
import 'package:lotti/features/relationships/util/contact_channel_uri.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// A contact channel paired with the one action the platform will service
/// for it — what the action bar's third control launches.
typedef ReachableChannel = ({ContactChannel channel, ContactAction action});

/// The person page's sticky bottom bar (design 2026-09-06 §2–3), replacing
/// the floating button: *Log check-in* · mic · the platform's actionable
/// channel. The same glass strip the task page docks, so the two pages
/// end the same way.
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
    if (oldWidget.relationship.data.contactChannels !=
        widget.relationship.data.contactChannels) {
      unawaited(_resolveReachable());
    }
  }

  Future<void> _resolveReachable() async {
    final generation = ++_resolution;
    final launcher = ref.read(contactLauncherProvider);
    ReachableChannel? found;
    for (final channel in widget.relationship.data.contactChannels) {
      for (final action in contactActionsFor(channel.type)) {
        if (await launcher.canLaunch(channel, action)) {
          found = (channel: channel, action: action);
          break;
        }
      }
      if (found != null) break;
    }
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
    return Row(
      children: [
        Expanded(
          child: DsGlassPill(
            key: const ValueKey('person-action-log-check-in'),
            label: messages.relationshipLogCheckIn,
            icon: LottiIcons.greeting,
            expand: true,
            fillColor: tokens.colors.interactive.enabled,
            foregroundColor: tokens.colors.text.onInteractiveAlert,
            onTap: widget.onLogCheckIn,
          ),
        ),
        SizedBox(width: spacing.step4),
        DsGlassRoundButton(
          key: const ValueKey('person-action-speak'),
          icon: LottiIcons.mic,
          semanticLabel: messages.checkInSpeakButton,
          onPressed: widget.onSpeak,
        ),
        if (reachable != null) ...[
          SizedBox(width: spacing.step4),
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
      ],
    );
  }
}
