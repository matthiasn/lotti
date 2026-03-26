import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

enum DesignSystemBreadcrumbVisualState {
  idle,
  hover,
  pressed,
}

class DesignSystemBreadcrumbItem {
  const DesignSystemBreadcrumbItem({
    required this.label,
    this.selected = false,
    this.enabled = true,
    this.showChevron = true,
    this.onPressed,
    this.semanticsLabel,
    this.forcedState,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final bool showChevron;
  final VoidCallback? onPressed;
  final String? semanticsLabel;
  final DesignSystemBreadcrumbVisualState? forcedState;
}

class DesignSystemBreadcrumbs extends StatelessWidget {
  DesignSystemBreadcrumbs({
    required this.items,
    super.key,
  }) : assert(items.isNotEmpty, 'Provide at least one breadcrumb item.');

  final List<DesignSystemBreadcrumbItem> items;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            _BreadcrumbChip(
              item: item,
            ),
        ],
      ),
    );
  }
}

class _BreadcrumbChip extends StatefulWidget {
  const _BreadcrumbChip({
    required this.item,
  });

  final DesignSystemBreadcrumbItem item;

  @override
  State<_BreadcrumbChip> createState() => _BreadcrumbChipState();
}

class _BreadcrumbChipState extends State<_BreadcrumbChip> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant _BreadcrumbChip oldWidget) {
    super.didUpdateWidget(oldWidget);

    final interactionChanged =
        oldWidget.item.enabled != widget.item.enabled ||
        oldWidget.item.selected != widget.item.selected ||
        oldWidget.item.forcedState != widget.item.forcedState ||
        oldWidget.item.onPressed != widget.item.onPressed;

    if (interactionChanged) {
      _hovered = false;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _BreadcrumbSpec.fromTokens(tokens);
    final visualState = _resolveVisualState();
    final style = _BreadcrumbStyle.fromTokens(
      tokens: tokens,
      selected: widget.item.selected,
      enabled: widget.item.enabled,
      visualState: visualState,
    );

    final isInteractive = widget.item.enabled && widget.item.onPressed != null;

    final label = DecoratedBox(
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(spec.labelRadius),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spec.horizontalPadding,
          vertical: spec.verticalPadding,
        ),
        child: Text(
          widget.item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: spec.labelStyle.copyWith(color: style.contentColor),
        ),
      ),
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        label,
        if (widget.item.showChevron)
          SizedBox(
            width: spec.iconSlotWidth,
            height: spec.height,
            child: Center(
              child: Icon(
                Icons.chevron_right_rounded,
                size: spec.chevronSize,
                color: style.contentColor,
              ),
            ),
          ),
      ],
    );

    final breadcrumb = isInteractive
        ? Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(spec.labelRadius),
              onTap: widget.item.onPressed,
              onHover: widget.item.forcedState == null
                  ? (value) => setState(() => _hovered = value)
                  : null,
              onHighlightChanged: widget.item.forcedState == null
                  ? (value) => setState(() => _pressed = value)
                  : null,
              child: content,
            ),
          )
        : content;

    return Semantics(
      button: widget.item.onPressed != null,
      selected: widget.item.selected,
      enabled: widget.item.enabled,
      label: widget.item.semanticsLabel ?? widget.item.label,
      child: SizedBox(
        height: spec.height,
        child: breadcrumb,
      ),
    );
  }

  DesignSystemBreadcrumbVisualState _resolveVisualState() {
    if (!widget.item.enabled) {
      return DesignSystemBreadcrumbVisualState.idle;
    }
    if (widget.item.forcedState != null) {
      return widget.item.forcedState!;
    }
    if (_pressed) {
      return DesignSystemBreadcrumbVisualState.pressed;
    }
    if (_hovered) {
      return DesignSystemBreadcrumbVisualState.hover;
    }
    return DesignSystemBreadcrumbVisualState.idle;
  }
}

class _BreadcrumbSpec {
  const _BreadcrumbSpec({
    required this.height,
    required this.labelRadius,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.iconSlotWidth,
    required this.chevronSize,
    required this.labelStyle,
  });

  factory _BreadcrumbSpec.fromTokens(DsTokens tokens) {
    return _BreadcrumbSpec(
      height: 28,
      labelRadius: tokens.radii.s,
      horizontalPadding: tokens.spacing.step3,
      verticalPadding: tokens.spacing.step2,
      iconSlotWidth: 20,
      chevronSize: 16,
      labelStyle: tokens.typography.styles.body.bodySmall,
    );
  }

  final double height;
  final double labelRadius;
  final double horizontalPadding;
  final double verticalPadding;
  final double iconSlotWidth;
  final double chevronSize;
  final TextStyle labelStyle;
}

class _BreadcrumbStyle {
  const _BreadcrumbStyle({
    required this.contentColor,
    required this.backgroundColor,
  });

  factory _BreadcrumbStyle.fromTokens({
    required DsTokens tokens,
    required bool selected,
    required bool enabled,
    required DesignSystemBreadcrumbVisualState visualState,
  }) {
    final contentColor = !enabled
        ? tokens.colors.text.lowEmphasis
        : selected
        ? tokens.colors.interactive.enabled
        : tokens.colors.text.highEmphasis;

    final backgroundColor = switch (visualState) {
      DesignSystemBreadcrumbVisualState.idle => Colors.transparent,
      DesignSystemBreadcrumbVisualState.hover => tokens.colors.surface.enabled,
      DesignSystemBreadcrumbVisualState.pressed =>
        tokens.colors.surface.selected,
    };

    return _BreadcrumbStyle(
      contentColor: contentColor,
      backgroundColor: enabled ? backgroundColor : Colors.transparent,
    );
  }

  final Color contentColor;
  final Color backgroundColor;
}
