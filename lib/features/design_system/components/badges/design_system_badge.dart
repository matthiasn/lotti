import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

enum DesignSystemBadgeTone {
  primary,
  secondary,
  danger,
  warning,
  success,
}

enum _DesignSystemBadgeType {
  dot,
  number,
  filled,
  outlined,
  icon,
}

class DesignSystemBadge extends StatelessWidget {
  const DesignSystemBadge.dot({
    this.tone = DesignSystemBadgeTone.primary,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    super.key,
  }) : _type = _DesignSystemBadgeType.dot,
       _label = null,
       _icon = null;

  const DesignSystemBadge.number({
    required String value,
    this.tone = DesignSystemBadgeTone.primary,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    super.key,
  }) : _type = _DesignSystemBadgeType.number,
       _label = value,
       _icon = null;

  const DesignSystemBadge.filled({
    required String label,
    this.tone = DesignSystemBadgeTone.primary,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    super.key,
  }) : _type = _DesignSystemBadgeType.filled,
       _label = label,
       _icon = null;

  const DesignSystemBadge.outlined({
    required String label,
    this.tone = DesignSystemBadgeTone.primary,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    super.key,
  }) : _type = _DesignSystemBadgeType.outlined,
       _label = label,
       _icon = null;

  const DesignSystemBadge.icon({
    required IconData icon,
    this.tone = DesignSystemBadgeTone.primary,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    super.key,
  }) : _type = _DesignSystemBadgeType.icon,
       _label = null,
       _icon = icon;

  final DesignSystemBadgeTone tone;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final _DesignSystemBadgeType _type;
  final String? _label;
  final IconData? _icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final sizeSpec = _BadgeSizeSpec.fromTokens(
      tokens: tokens,
      type: _type,
      label: _label,
    );
    final styleSpec = _BadgeStyleSpec.fromTokens(
      tokens: tokens,
      type: _type,
      tone: tone,
    );

    final badge = DefaultTextStyle.merge(
      style: sizeSpec.textStyle.copyWith(color: styleSpec.foregroundColor),
      child: IconTheme.merge(
        data: IconThemeData(
          color: styleSpec.foregroundColor,
          size: sizeSpec.iconSize,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: styleSpec.backgroundColor,
            borderRadius: BorderRadius.circular(sizeSpec.cornerRadius),
            border: styleSpec.borderColor == null
                ? null
                : Border.all(
                    color: styleSpec.borderColor!,
                    width: sizeSpec.borderWidth,
                  ),
          ),
          child: sizeSpec.buildContainer(_buildContent()),
        ),
      ),
    );

    if (excludeFromSemantics) {
      return ExcludeSemantics(child: badge);
    }

    if (semanticLabel == null) {
      return badge;
    }

    return Semantics(
      container: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: badge),
    );
  }

  Widget _buildContent() {
    return switch (_type) {
      _DesignSystemBadgeType.dot => const SizedBox.shrink(),
      _DesignSystemBadgeType.number => Text(
        _label!,
        maxLines: 1,
        softWrap: false,
        textScaler: TextScaler.noScaling,
      ),
      _DesignSystemBadgeType.filled || _DesignSystemBadgeType.outlined => Text(
        _label!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textScaler: TextScaler.noScaling,
      ),
      _DesignSystemBadgeType.icon => Icon(_icon),
    };
  }
}

class _BadgeSizeSpec {
  const _BadgeSizeSpec({
    required this.squareSize,
    required this.minWidth,
    required this.height,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.cornerRadius,
    required this.iconSize,
    required this.textStyle,
    required this.borderWidth,
  });

  factory _BadgeSizeSpec.fromTokens({
    required DsTokens tokens,
    required _DesignSystemBadgeType type,
    required String? label,
  }) {
    final caption = tokens.typography.styles.others.caption;
    final badgeHeight =
        tokens.typography.lineHeight.caption + (tokens.spacing.step1 * 2);
    final compactNumber =
        type == _DesignSystemBadgeType.number && (label?.length ?? 0) <= 2;
    return switch (type) {
      _DesignSystemBadgeType.dot => _BadgeSizeSpec(
        squareSize: tokens.spacing.step3,
        minWidth: null,
        height: tokens.spacing.step3,
        horizontalPadding: 0,
        verticalPadding: 0,
        cornerRadius: tokens.spacing.step3 / 2,
        iconSize: 0,
        textStyle: caption,
        borderWidth: tokens.spacing.step1 / 2,
      ),
      _DesignSystemBadgeType.number => _BadgeSizeSpec(
        squareSize: compactNumber ? badgeHeight : null,
        minWidth: compactNumber ? null : badgeHeight,
        height: badgeHeight,
        horizontalPadding: 0,
        verticalPadding: 0,
        cornerRadius: badgeHeight / 2,
        iconSize: 0,
        textStyle: caption,
        borderWidth: tokens.spacing.step1 / 2,
      ),
      _DesignSystemBadgeType.icon => _BadgeSizeSpec(
        squareSize: badgeHeight,
        minWidth: null,
        height: badgeHeight,
        horizontalPadding: tokens.spacing.step1,
        verticalPadding: tokens.spacing.step1,
        cornerRadius: tokens.radii.xs,
        iconSize: tokens.typography.lineHeight.caption,
        textStyle: caption,
        borderWidth: tokens.spacing.step1 / 2,
      ),
      _DesignSystemBadgeType.filled ||
      _DesignSystemBadgeType.outlined => _BadgeSizeSpec(
        squareSize: null,
        minWidth: null,
        height: badgeHeight,
        horizontalPadding: tokens.spacing.step2,
        verticalPadding: tokens.spacing.step1,
        cornerRadius: tokens.radii.xs,
        iconSize: 0,
        textStyle: caption,
        borderWidth: tokens.spacing.step1 / 2,
      ),
    };
  }

  final double? squareSize;
  final double? minWidth;
  final double height;
  final double horizontalPadding;
  final double verticalPadding;
  final double cornerRadius;
  final double iconSize;
  final TextStyle textStyle;
  final double borderWidth;

  Widget buildContainer(Widget child) {
    final paddedChild = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Center(child: child),
    );

    if (squareSize != null) {
      return SizedBox.square(
        dimension: squareSize,
        child: paddedChild,
      );
    }

    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minWidth ?? 0,
          minHeight: height,
        ),
        child: SizedBox(
          height: height,
          child: paddedChild,
        ),
      ),
    );
  }
}

class _BadgeStyleSpec {
  const _BadgeStyleSpec({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
  });

  factory _BadgeStyleSpec.fromTokens({
    required DsTokens tokens,
    required _DesignSystemBadgeType type,
    required DesignSystemBadgeTone tone,
  }) {
    if (tone == DesignSystemBadgeTone.secondary) {
      final color = tokens.colors.alert.info.defaultColor;
      final background = tokens.colors.surface.enabled;

      return switch (type) {
        _DesignSystemBadgeType.dot => _BadgeStyleSpec(
          backgroundColor: background,
          foregroundColor: Colors.transparent,
          borderColor: null,
        ),
        _DesignSystemBadgeType.number ||
        _DesignSystemBadgeType.filled ||
        _DesignSystemBadgeType.icon => _BadgeStyleSpec(
          backgroundColor: background,
          foregroundColor: color,
          borderColor: null,
        ),
        _DesignSystemBadgeType.outlined => _BadgeStyleSpec(
          backgroundColor: background,
          foregroundColor: color,
          borderColor: color,
        ),
      };
    }

    final accentColor = switch (tone) {
      DesignSystemBadgeTone.primary => tokens.colors.alert.info.defaultColor,
      DesignSystemBadgeTone.danger => tokens.colors.alert.error.defaultColor,
      DesignSystemBadgeTone.warning => tokens.colors.alert.warning.defaultColor,
      DesignSystemBadgeTone.success => tokens.colors.alert.success.defaultColor,
      DesignSystemBadgeTone.secondary => throw StateError(
        'Secondary tone must be handled separately.',
      ),
    };

    return switch (type) {
      _DesignSystemBadgeType.dot => _BadgeStyleSpec(
        backgroundColor: accentColor,
        foregroundColor: Colors.transparent,
        borderColor: null,
      ),
      _DesignSystemBadgeType.number ||
      _DesignSystemBadgeType.filled ||
      _DesignSystemBadgeType.icon => _BadgeStyleSpec(
        backgroundColor: accentColor,
        foregroundColor: tokens.colors.text.onInteractiveAlert,
        borderColor: null,
      ),
      _DesignSystemBadgeType.outlined => _BadgeStyleSpec(
        backgroundColor: null,
        foregroundColor: accentColor,
        borderColor: accentColor,
      ),
    };
  }

  final Color? backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
}
