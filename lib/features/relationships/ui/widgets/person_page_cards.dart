import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/widgets/contact_quick_actions.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// A section card's title row: the heading, an optional count or caption
/// beside it, and an optional trailing action — one shape for every card on
/// the person page.
class PersonCardHeader extends StatelessWidget {
  const PersonCardHeader({
    required this.title,
    this.caption,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      children: [
        Text(
          title,
          style: tokens.typography.styles.subtitle.subtitle2.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        if (caption != null) ...[
          SizedBox(width: tokens.spacing.step3),
          caption!,
        ],
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

/// The "Next time" card (design 2026-09-06 Q9): what the latest check-in
/// asked to bring up, and what to leave alone — the one thing worth reading
/// before the next call, sourced from the user's own words, never from the
/// agent. Renders nothing when the latest check-in carries neither.
class NextTimeCard extends StatelessWidget {
  const NextTimeCard({required this.latest, super.key});

  final CheckInEntry? latest;

  static String? _attentionOf(CheckInEntry? latest) =>
      _nonBlank(latest?.data.payAttentionTo);

  static String? _avoidOf(CheckInEntry? latest) =>
      _nonBlank(latest?.data.avoid);

  static String? _nonBlank(String? text) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Whether the card would render anything for [latest] — exposed so the
  /// page can decide on the gap after it with the same rule the card uses.
  static bool hasContent(CheckInEntry? latest) =>
      _attentionOf(latest) != null || _avoidOf(latest) != null;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final attention = _attentionOf(latest);
    final avoid = _avoidOf(latest);
    if (attention == null && avoid == null) return const SizedBox.shrink();

    Widget tile(String caption, String text, Key key) => Container(
      key: key,
      width: double.infinity,
      padding: EdgeInsets.all(tokens.spacing.step4),
      decoration: BoxDecoration(
        color: tokens.colors.background.level03,
        borderRadius: BorderRadius.circular(tokens.radii.m),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            caption,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step1),
          Text(
            text,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ],
      ),
    );

    return DesignSystemSectionCard(
      key: const ValueKey('person-next-time-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonCardHeader(
            title: messages.relationshipNextTimeTitle,
            trailing: Text(
              relationshipTimestampLabelOf(context, latest!.meta.dateFrom),
              style: relationshipTimestampStyle(tokens),
            ),
          ),
          SizedBox(height: tokens.spacing.step4),
          if (attention != null)
            tile(
              messages.relationshipPayAttentionTo,
              attention,
              const ValueKey('person-next-time-attention'),
            ),
          if (attention != null && avoid != null)
            SizedBox(height: tokens.spacing.step3),
          if (avoid != null)
            tile(
              messages.checkInAvoidLabel,
              avoid,
              const ValueKey('person-next-time-avoid'),
            ),
        ],
      ),
    );
  }
}

/// The "Reach" card: the person's contact channels with the actions the
/// device can service, under the privacy line the feature stands on — the
/// channels stay on the device and never enter AI context (ADR 0041 §5).
/// Renders nothing for a person without channels.
class ReachCard extends StatelessWidget {
  const ReachCard({
    required this.relationshipId,
    required this.channels,
    super.key,
  });

  final String relationshipId;
  final List<ContactChannel> channels;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    if (channels.isEmpty) return const SizedBox.shrink();

    return DesignSystemSectionCard(
      key: const ValueKey('person-reach-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonCardHeader(title: messages.relationshipReachTitle),
          SizedBox(height: tokens.spacing.step1),
          Text(
            messages.relationshipReachPrivacy,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          for (final channel in channels)
            _ReachRow(relationshipId: relationshipId, channel: channel),
        ],
      ),
    );
  }
}

class _ReachRow extends StatelessWidget {
  const _ReachRow({required this.relationshipId, required this.channel});

  final String relationshipId;
  final ContactChannel channel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final label = channel.label;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
      child: Row(
        children: [
          Container(
            width: tokens.spacing.step8,
            height: tokens.spacing.step8,
            decoration: BoxDecoration(
              color: tokens.colors.background.level03,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              contactChannelTypeIcon(channel.type),
              size: IconSizes.m,
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(width: tokens.spacing.step4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  channel.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.body.bodyMedium.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
                Text(
                  label == null || label.isEmpty
                      ? contactChannelTypeLabel(context, channel.type)
                      : label,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          // Renders nothing until the platform confirms it can service an
          // action, and nothing at all for a channel with no launchable
          // scheme (plan v2 phase 7 item 4).
          ContactQuickActions(relationshipId: relationshipId, channel: channel),
        ],
      ),
    );
  }
}
