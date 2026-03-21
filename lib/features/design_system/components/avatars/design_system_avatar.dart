import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

enum DesignSystemAvatarStatus {
  enabled,
  connected,
  away,
  busy,
}

enum DesignSystemAvatarSize {
  xs20,
  s24,
  m32,
  l40,
  xl48,
  xxl64,
  xxxl80,
  jumbo96,
}

class DesignSystemAvatar extends StatelessWidget {
  const DesignSystemAvatar({
    required this.image,
    this.size = DesignSystemAvatarSize.l40,
    this.status = DesignSystemAvatarStatus.enabled,
    this.semanticsLabel,
    super.key,
  });

  final ImageProvider image;
  final DesignSystemAvatarSize size;
  final DesignSystemAvatarStatus status;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _AvatarSpec.fromTokens(tokens, size, status);

    return Semantics(
      container: true,
      label: semanticsLabel,
      image: true,
      child: SizedBox.square(
        dimension: spec.dimension,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: spec.borderColor,
              width: spec.borderWidth,
            ),
            image: DecorationImage(
              image: image,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarSpec {
  const _AvatarSpec({
    required this.dimension,
    required this.borderWidth,
    required this.borderColor,
  });

  factory _AvatarSpec.fromTokens(
    DsTokens tokens,
    DesignSystemAvatarSize size,
    DesignSystemAvatarStatus status,
  ) {
    return _AvatarSpec(
      dimension: _dimension(tokens, size),
      borderWidth: _borderWidth(size),
      borderColor: _borderColor(tokens, status),
    );
  }

  final double dimension;
  final double borderWidth;
  final Color borderColor;

  static double _dimension(DsTokens tokens, DesignSystemAvatarSize size) {
    return switch (size) {
      DesignSystemAvatarSize.xs20 => tokens.typography.lineHeight.subtitle2,
      DesignSystemAvatarSize.s24 => tokens.spacing.step6,
      DesignSystemAvatarSize.m32 => tokens.spacing.step7,
      DesignSystemAvatarSize.l40 => tokens.spacing.step8,
      DesignSystemAvatarSize.xl48 => tokens.spacing.step9,
      DesignSystemAvatarSize.xxl64 => tokens.spacing.step10,
      DesignSystemAvatarSize.xxxl80 => tokens.spacing.step11,
      DesignSystemAvatarSize.jumbo96 => tokens.spacing.step12,
    };
  }

  static double _borderWidth(DesignSystemAvatarSize size) {
    return switch (size) {
      DesignSystemAvatarSize.xs20 ||
      DesignSystemAvatarSize.s24 ||
      DesignSystemAvatarSize.m32 => 1,
      DesignSystemAvatarSize.l40 ||
      DesignSystemAvatarSize.xl48 ||
      DesignSystemAvatarSize.xxl64 => 2,
      DesignSystemAvatarSize.xxxl80 => 3,
      DesignSystemAvatarSize.jumbo96 => 4,
    };
  }

  static Color _borderColor(DsTokens tokens, DesignSystemAvatarStatus status) {
    return switch (status) {
      DesignSystemAvatarStatus.enabled => tokens.colors.decorative.level02,
      DesignSystemAvatarStatus.connected =>
        tokens.colors.alert.success.defaultColor,
      DesignSystemAvatarStatus.away => tokens.colors.alert.warning.defaultColor,
      DesignSystemAvatarStatus.busy => tokens.colors.alert.error.defaultColor,
    };
  }
}
