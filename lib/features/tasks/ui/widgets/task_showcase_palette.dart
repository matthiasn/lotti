import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

class TaskShowcasePalette {
  static Color page(BuildContext context) =>
      context.designTokens.colors.background.level01;

  static Color surface(BuildContext context) =>
      context.designTokens.colors.background.level02;

  static Color elevatedSurface(BuildContext context) =>
      context.designTokens.colors.background.level03;

  static Color border(BuildContext context) =>
      context.designTokens.colors.decorative.level01;

  static Color highText(BuildContext context) =>
      context.designTokens.colors.text.highEmphasis;

  static Color mediumText(BuildContext context) =>
      context.designTokens.colors.text.mediumEmphasis;

  static Color lowText(BuildContext context) =>
      context.designTokens.colors.text.lowEmphasis;

  static Color selectedRow(BuildContext context) =>
      context.designTokens.colors.interactive.enabled.withValues(alpha: 0.12);

  static Color hoverFill(BuildContext context) =>
      context.designTokens.colors.surface.hover;

  static Color subtleFill(BuildContext context) =>
      context.designTokens.colors.surface.enabled;

  static Color accent(BuildContext context) =>
      context.designTokens.colors.interactive.enabled;

  static Color success(BuildContext context) =>
      context.designTokens.colors.alert.success.defaultColor;

  static Color warning(BuildContext context) =>
      context.designTokens.colors.alert.warning.defaultColor;

  static Color error(BuildContext context) =>
      context.designTokens.colors.alert.error.defaultColor;

  static Color info(BuildContext context) =>
      context.designTokens.colors.alert.info.defaultColor;
}
