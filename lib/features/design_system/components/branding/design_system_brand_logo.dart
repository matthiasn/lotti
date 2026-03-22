import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum DesignSystemBrandLogoVariant { automatic, light, dark }

class DesignSystemBrandLogo extends StatelessWidget {
  const DesignSystemBrandLogo({
    this.height = 32,
    this.variant = DesignSystemBrandLogoVariant.automatic,
    super.key,
  });

  final double height;
  final DesignSystemBrandLogoVariant variant;

  @override
  Widget build(BuildContext context) {
    final resolvedVariant = variant == DesignSystemBrandLogoVariant.automatic
        ? (Theme.of(context).brightness == Brightness.dark
              ? DesignSystemBrandLogoVariant.dark
              : DesignSystemBrandLogoVariant.light)
        : variant;

    return SvgPicture.asset(
      resolvedVariant == DesignSystemBrandLogoVariant.dark
          ? _darkBrandLogoAsset
          : _lightBrandLogoAsset,
      key: ValueKey('designSystemBrandLogo.${resolvedVariant.name}'),
      width: height * _brandLogoAspectRatio,
      height: height,
    );
  }
}

const double _brandLogoAspectRatio = 205 / 74;
const _lightBrandLogoAsset = 'assets/design_system/brand_logo_light.svg';
const _darkBrandLogoAsset = 'assets/design_system/brand_logo_dark.svg';
