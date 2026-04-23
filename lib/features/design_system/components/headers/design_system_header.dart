import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

class DesignSystemHeader extends StatelessWidget {
  const DesignSystemHeader({
    required this.title,
    this.leading,
    this.breadcrumbs,
    this.primaryAction,
    this.trailingActions = const <Widget>[],
    this.trailingAvatar,
    super.key,
  });

  static const double desktopHeight = 68;

  final String title;
  final Widget? leading;
  final Widget? breadcrumbs;
  final Widget? primaryAction;
  final List<Widget> trailingActions;
  final Widget? trailingAvatar;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final hasTrailingCluster =
        trailingActions.isNotEmpty || trailingAvatar != null;
    final trailingGap = primaryAction == null
        ? null
        : SizedBox(width: tokens.spacing.step3);

    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.background.level01,
        ),
        child: SizedBox(
          height: desktopHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step6,
              vertical: tokens.spacing.step5,
            ),
            // Flex layout per the Figma reference: leading + title are
            // intrinsic (no flex) so the logo and heading are rendered
            // at their natural width; the breadcrumb segment is the
            // sole flex child, so it expands to fill the entire
            // remaining row (not a 50/50 split with the title), and
            // the trailing cluster is intrinsic so it snaps to the
            // right edge. When no breadcrumbs are supplied the title
            // itself becomes the flex child so trailing still snaps
            // right without needing a separate Spacer.
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  SizedBox(width: tokens.spacing.step5),
                ],
                if (breadcrumbs case final breadcrumbs?) ...[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.heading.heading2.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step5),
                  Expanded(
                    child: ClipRect(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: breadcrumbs,
                        ),
                      ),
                    ),
                  ),
                ] else
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.typography.styles.heading.heading2.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                  ),
                if (primaryAction != null || hasTrailingCluster)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ?primaryAction,
                      if (hasTrailingCluster)
                        _TrailingCluster(
                          leadingGap: trailingGap,
                          actions: trailingActions,
                          avatar: trailingAvatar,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrailingCluster extends StatelessWidget {
  const _TrailingCluster({
    required this.actions,
    this.leadingGap,
    this.avatar,
  });

  final List<Widget> actions;
  final Widget? leadingGap;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing.step3;
    final items = <Widget>[...actions, ?avatar];
    final children = <Widget>[?leadingGap];

    for (var index = 0; index < items.length; index++) {
      children.add(items[index]);
      if (index < items.length - 1) {
        children.add(SizedBox(width: spacing));
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
