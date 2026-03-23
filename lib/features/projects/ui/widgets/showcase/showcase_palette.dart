import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

class ShowcasePalette {
  static Color page(BuildContext context) =>
      context.designTokens.colors.background.level01;

  static Color surface(BuildContext context) =>
      context.designTokens.colors.background.level02;

  static Color expandedSurface(BuildContext context) =>
      context.designTokens.colors.background.level03;

  static Color healthSurface(BuildContext context) =>
      context.designTokens.colors.background.alternative01;

  static Color selectedRow(BuildContext context) =>
      context.designTokens.colors.surface.selected;

  static Color border(BuildContext context) =>
      context.designTokens.colors.decorative.level01;

  static Color highText(BuildContext context) =>
      context.designTokens.colors.text.highEmphasis;

  static Color mediumText(BuildContext context) =>
      context.designTokens.colors.text.mediumEmphasis;

  static Color lowText(BuildContext context) =>
      context.designTokens.colors.text.lowEmphasis;

  static Color tagText(BuildContext context) =>
      context.designTokens.colors.text.onInteractiveAlert;

  static Color subtleFill(BuildContext context) =>
      context.designTokens.colors.surface.enabled;

  static Color teal(BuildContext context) =>
      context.designTokens.colors.interactive.enabled;

  static Color activeNav(BuildContext context) =>
      context.designTokens.colors.surface.active;

  static Color hoverFill(BuildContext context) =>
      context.designTokens.colors.surface.hover;

  static Color amber(BuildContext context) =>
      context.designTokens.colors.alert.warning.defaultColor;

  static Color infoBlue(BuildContext context) =>
      context.designTokens.colors.alert.info.defaultColor;

  static Color timeGreen(BuildContext context) =>
      context.designTokens.colors.alert.success.defaultColor;

  static Color error(BuildContext context) =>
      context.designTokens.colors.alert.error.defaultColor;
}
