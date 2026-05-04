import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/instances/instance_filter_state.dart';
import 'package:lotti/features/agents/ui/instances/instance_view_model.dart';
import 'package:lotti/features/agents/ui/instances/widgets/instance_row.dart';
import 'package:lotti/features/agents/ui/instances/widgets/soul_avatar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Group section header. Click-to-toggle the [expanded] state.
///
/// Implementing this as a regular widget rather than a
/// [SliverPersistentHeader] sidesteps the sliver-geometry assertion that
/// fired when groups switched axes — the trade-off is no
/// position:sticky behaviour, which is fine for a settings page.
class InstancesGroupHeader extends StatelessWidget {
  const InstancesGroupHeader({
    required this.group,
    required this.groupKey,
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final InstancesGroup group;
  final InstancesGroupKey groupKey;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final messages = context.messages;
    final activeCount = group.activeCount;

    Widget identity;
    if (groupKey == InstancesGroupKey.soul) {
      identity = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SoulAvatar(
            label: group.label,
            hue: hueForSeed(group.soulId ?? group.label),
          ),
          SizedBox(width: tokens.spacing.step3),
          Flexible(
            child: Text(
              group.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.text.highEmphasis,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else {
      identity = Text(
        group.label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.text.highEmphasis,
        ),
      );
    }

    return Material(
      color: colors.background.level02,
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
                if (groupKey != InstancesGroupKey.status && activeCount > 0)
                  Padding(
                    padding: EdgeInsets.only(right: tokens.spacing.step3),
                    child: Text(
                      messages.agentInstancesGroupActiveCount(activeCount),
                      style: TextStyle(
                        fontFamily: 'Inconsolata',
                        fontSize: 11,
                        color: colors.interactive.enabled,
                      ),
                    ),
                  ),
                Text(
                  '· ${group.items.length}',
                  style: TextStyle(
                    fontFamily: 'Inconsolata',
                    fontSize: 11,
                    color: colors.text.lowEmphasis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Body of the group: list of [InstanceRow]s, separated by 1px gaps so
/// hover backgrounds visually merge.
class InstancesGroupBody extends StatelessWidget {
  const InstancesGroupBody({
    required this.group,
    required this.showSoul,
    required this.onTapInstance,
    super.key,
  });

  final InstancesGroup group;
  final bool showSoul;
  final void Function(String id) onTapInstance;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step2),
      child: Column(
        children: [
          for (var i = 0; i < group.items.length; i++) ...[
            if (i > 0) const SizedBox(height: 1),
            InstanceRow(
              vm: group.items[i],
              showSoul: showSoul,
              onTap: () => onTapInstance(group.items[i].id),
            ),
          ],
        ],
      ),
    );
  }
}
