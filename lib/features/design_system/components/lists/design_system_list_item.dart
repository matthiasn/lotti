import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/utils/disabled_overlay.dart';

enum DesignSystemListItemSize {
  small,
  medium,
}

enum DesignSystemListItemVisualState {
  idle,
  hover,
  pressed,
}

class DesignSystemListItem extends StatefulWidget {
  const DesignSystemListItem({
    this.title,
    this.subtitle,
    this.titleContent,
    this.subtitleSpans,
    this.size = DesignSystemListItemSize.medium,
    this.leading,
    this.leadingExtra,
    this.trailing,
    this.trailingExtra,
    this.showDivider = false,
    this.activated = false,
    this.selected = false,
    this.activatedBackgroundColor,
    this.hoverBackgroundColor,
    this.pressedBackgroundColor,
    this.onTap,
    this.semanticsLabel,
    this.forcedState,
    super.key,
  }) : assert(
         (title != null) ^ (titleContent != null),
         'Provide exactly one of title or titleContent, not both.',
       ),
       assert(
         subtitle == null || subtitleSpans == null,
         'Provide either subtitle or subtitleSpans, not both.',
       );

  final String? title;
  final String? subtitle;
  final Widget? titleContent;
  final List<InlineSpan>? subtitleSpans;
  final DesignSystemListItemSize size;
  final Widget? leading;
  final Widget? leadingExtra;
  final Widget? trailing;
  final Widget? trailingExtra;
  final bool showDivider;
  final bool activated;
  final bool selected;
  final Color? activatedBackgroundColor;
  final Color? hoverBackgroundColor;
  final Color? pressedBackgroundColor;
  final VoidCallback? onTap;
  final String? semanticsLabel;
  final DesignSystemListItemVisualState? forcedState;

  @override
  State<DesignSystemListItem> createState() => _DesignSystemListItemState();
}

class _DesignSystemListItemState extends State<DesignSystemListItem> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant DesignSystemListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forcedState != widget.forcedState ||
        (oldWidget.onTap == null) != (widget.onTap == null)) {
      _hovered = false;
      _pressed = false;
    }
  }

  DesignSystemListItemVisualState _resolveVisualState(bool enabled) {
    if (widget.forcedState != null) return widget.forcedState!;
    if (!enabled) return DesignSystemListItemVisualState.idle;
    if (_pressed) return DesignSystemListItemVisualState.pressed;
    if (_hovered) return DesignSystemListItemVisualState.hover;
    return DesignSystemListItemVisualState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _ListItemSpec.fromTokens(tokens, widget.size);
    final enabled = widget.onTap != null;
    final visualState = _resolveVisualState(enabled);

    final backgroundColor = widget.activated
        ? widget.activatedBackgroundColor ?? tokens.colors.surface.active
        : switch (visualState) {
            DesignSystemListItemVisualState.idle => Colors.transparent,
            DesignSystemListItemVisualState.hover =>
              widget.hoverBackgroundColor ?? tokens.colors.surface.hover,
            DesignSystemListItemVisualState.pressed =>
              widget.pressedBackgroundColor ??
                  tokens.colors.surface.focusPressed,
          };

    final item = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(color: backgroundColor),
            child: InkWell(
              onTap: widget.onTap,
              onHover: widget.forcedState == null && enabled
                  ? (value) => setState(() => _hovered = value)
                  : null,
              onHighlightChanged: widget.forcedState == null && enabled
                  ? (value) => setState(() => _pressed = value)
                  : null,
              child: Semantics(
                button: widget.onTap != null,
                label: widget.semanticsLabel,
                selected: widget.selected,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: spec.horizontalPadding,
                    vertical: spec.verticalPadding,
                  ),
                  child: Row(
                    children: [
                      if (widget.leadingExtra != null) widget.leadingExtra!,
                      if (widget.leadingExtra != null && widget.leading != null)
                        SizedBox(width: spec.itemGap),
                      if (widget.leading != null) widget.leading!,
                      if (widget.leadingExtra != null || widget.leading != null)
                        SizedBox(width: spec.itemGap),
                      Expanded(
                        child: _TitleContent(
                          title: widget.title,
                          subtitle: widget.subtitle,
                          titleContent: widget.titleContent,
                          subtitleSpans: widget.subtitleSpans,
                          spec: spec,
                        ),
                      ),
                      if (widget.trailing != null ||
                          widget.trailingExtra != null)
                        SizedBox(width: spec.itemGap),
                      if (widget.trailing != null) widget.trailing!,
                      if (widget.trailing != null &&
                          widget.trailingExtra != null)
                        SizedBox(width: spec.itemGap),
                      if (widget.trailingExtra != null) widget.trailingExtra!,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: tokens.colors.decorative.level01,
          ),
      ],
    );

    return item.withDisabledOpacity(
      enabled: enabled || widget.forcedState != null,
      disabledOpacity: tokens.colors.text.lowEmphasis.a,
    );
  }
}

class _TitleContent extends StatelessWidget {
  const _TitleContent({
    required this.spec,
    this.title,
    this.subtitle,
    this.titleContent,
    this.subtitleSpans,
  });

  final String? title;
  final String? subtitle;
  final Widget? titleContent;
  final List<InlineSpan>? subtitleSpans;
  final _ListItemSpec spec;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleContent ??
            Text(
              title!,
              style: spec.titleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        if (subtitle != null || subtitleSpans != null) ...[
          SizedBox(height: spec.textGap),
          if (subtitleSpans != null)
            RichText(
              text: TextSpan(
                style: spec.subtitleStyle,
                children: subtitleSpans,
              ),
            )
          else
            Text(
              subtitle!,
              style: spec.subtitleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ],
    );
  }
}

class _ListItemSpec {
  const _ListItemSpec({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.itemGap,
    required this.textGap,
    required this.titleStyle,
    required this.subtitleStyle,
  });

  factory _ListItemSpec.fromTokens(
    DsTokens tokens,
    DesignSystemListItemSize size,
  ) {
    return switch (size) {
      DesignSystemListItemSize.medium => _ListItemSpec(
        horizontalPadding: tokens.spacing.step5,
        verticalPadding: tokens.spacing.step4,
        itemGap: tokens.spacing.step3,
        textGap: tokens.spacing.step1,
        titleStyle: tokens.typography.styles.subtitle.subtitle2.copyWith(
          color: tokens.colors.text.highEmphasis,
        ),
        subtitleStyle: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
      DesignSystemListItemSize.small => _ListItemSpec(
        horizontalPadding: tokens.spacing.step5,
        verticalPadding: tokens.spacing.step3,
        itemGap: tokens.spacing.step3,
        textGap: tokens.spacing.step1,
        titleStyle: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.highEmphasis,
        ),
        subtitleStyle: tokens.typography.styles.others.caption.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
    };
  }

  final double horizontalPadding;
  final double verticalPadding;
  final double itemGap;
  final double textGap;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;
}
