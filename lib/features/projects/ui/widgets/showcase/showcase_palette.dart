import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Named, theme-aware color accessors for the projects showcase/detail UI.
///
/// Each method resolves a design-system token off `context.designTokens`,
/// giving these widgets a small semantic vocabulary (page, surface, border,
/// high/medium/low text, accent fills) instead of referencing raw token paths
/// at every call site.
class ShowcasePalette {
  static Color page(BuildContext context) =>
      context.designTokens.colors.background.level01;

  static Color surface(BuildContext context) =>
      context.designTokens.colors.background.level02;

  static Color expandedSurface(BuildContext context) =>
      context.designTokens.colors.background.level03;

  static Color groupedCardSurface(BuildContext context) =>
      context.designTokens.colors.background.level02;

  /// The grouped-card surface tinted with a category's [color] at a very low
  /// alpha, so each category section reads as its own coloured zone (not an
  /// identical grey slab) while staying calm on the dark theme.
  static Color categoryCardSurface(BuildContext context, Color color) =>
      Color.alphaBlend(
        color.withValues(alpha: 0.08),
        groupedCardSurface(context),
      );

  /// A much fainter category tint for surfaces where a whole page shares ONE
  /// category (the project detail pane). A 0.08 wash on every card there reads
  /// as a flat colour fill; this barely-there warmth keeps the project's
  /// identity without colouring the page.
  static Color categoryCardSurfaceFaint(BuildContext context, Color color) =>
      Color.alphaBlend(
        color.withValues(alpha: 0.03),
        groupedCardSurface(context),
      );

  /// A faint teal wash marking an AGENT-authored surface (the AI report card),
  /// so AI-generated content reads as visually distinct from the user's own
  /// project/task content (which carries the category tint).
  static Color agentCardSurface(BuildContext context) => Color.alphaBlend(
    teal(context).withValues(alpha: 0.06),
    groupedCardSurface(context),
  );

  /// A faint attention wash (alert error at low alpha) used as the resting
  /// background of rows that need attention, so the hotspot reads before any
  /// text does.
  static Color attentionRowWash(BuildContext context) =>
      context.designTokens.colors.alert.error.defaultColor.withValues(
        alpha: 0.1,
      );

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
