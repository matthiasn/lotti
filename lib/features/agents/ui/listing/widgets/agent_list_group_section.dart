import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/widgets/agent_list_row.dart';
import 'package:lotti/features/agents/ui/listing/widgets/soul_avatar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Group section header. Click-to-toggle [expanded].
///
/// Implementing this as a regular widget rather than a
/// [SliverPersistentHeader] sidesteps the sliver-geometry assertion that
/// fired when groups switched axes — the trade-off is no
/// position:sticky behaviour, which is fine for a settings page.
class AgentListGroupHeader extends StatelessWidget {
  const AgentListGroupHeader({
    required this.group,
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final AgentListGroup group;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final messages = context.messages;

    final headerStyle = tokens.typography.styles.subtitle.subtitle2.copyWith(
      color: colors.text.highEmphasis,
    );
    final identity = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (group.leading case final AgentListAvatarLeading l) ...[
          SoulAvatar(label: l.label, hue: l.hue),
          SizedBox(width: tokens.spacing.step3),
        ] else if (group.leading case final AgentListIconLeading l) ...[
          Icon(l.icon, size: 18, color: l.color ?? colors.text.lowEmphasis),
          SizedBox(width: tokens.spacing.step3),
        ],
        Flexible(
          child: Text(
            group.label,
            style: headerStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return Material(
      color: colors.background.level01,
      child: InkWell(
        onTap: onToggle,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colors.decorative.level01),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step3,
              vertical: tokens.spacing.step3,
            ),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 14,
                  color: colors.text.lowEmphasis,
                ),
                SizedBox(width: tokens.spacing.step3),
                Expanded(child: identity),
                if (group.activeCount != null && group.activeCount! > 0)
                  Padding(
                    padding: EdgeInsets.only(right: tokens.spacing.step3),
                    child: Text(
                      messages.agentInstancesGroupActiveCount(
                        group.activeCount!,
                      ),
                      style: tokens.typography.styles.others.caption.copyWith(
                        fontFamily: 'Inconsolata',
                        color: colors.interactive.enabled,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                Text(
                  '· ${group.items.length}',
                  style: monoMetaStyle(tokens, colors),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Body of the group: list of [AgentListRow]s, separated by 1px gaps so
/// hover backgrounds visually merge.
class AgentListGroupBody extends StatelessWidget {
  const AgentListGroupBody({required this.group, super.key});

  final AgentListGroup group;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step2),
      child: Column(
        children: [
          for (var i = 0; i < group.items.length; i++) ...[
            if (i > 0) const SizedBox(height: 1),
            AgentListRow(data: group.items[i]),
          ],
        ],
      ),
    );
  }
}
