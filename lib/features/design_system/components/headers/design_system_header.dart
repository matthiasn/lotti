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
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (leading != null) ...[
                        leading!,
                        SizedBox(width: tokens.spacing.step5),
                      ],
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tokens.typography.styles.heading.heading2
                                    .copyWith(
                                      color: tokens.colors.text.highEmphasis,
                                    ),
                              ),
                            ),
                            if (breadcrumbs case final breadcrumbs?) ...[
                              SizedBox(width: tokens.spacing.step5),
                              Flexible(
                                child: ClipRect(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: breadcrumbs,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
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
