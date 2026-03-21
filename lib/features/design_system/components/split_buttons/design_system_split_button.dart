import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/utils/disabled_overlay.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

enum DesignSystemSplitButtonSize {
  small,
  compact,
  defaultSize,
}

class DesignSystemSplitButton extends StatelessWidget {
  const DesignSystemSplitButton({
    required this.label,
    required this.onPressed,
    required this.onDropdownPressed,
    this.size = DesignSystemSplitButtonSize.small,
    this.isDropdownOpen = false,
    this.enabled = true,
    this.mainSemanticsLabel,
    this.dropdownSemanticsLabel,
    super.key,
  }) : assert(
         label != '' || mainSemanticsLabel != null,
         'Provide either a visible label or a mainSemanticsLabel.',
       );

  final String label;
  final VoidCallback onPressed;
  final VoidCallback onDropdownPressed;
  final DesignSystemSplitButtonSize size;
  final bool isDropdownOpen;
  final bool enabled;
  final String? mainSemanticsLabel;
  final String? dropdownSemanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final sizeSpec = _SplitButtonSizeSpec.fromTokens(tokens, size);
    final styleSpec = _SplitButtonStyleSpec.fromTokens(tokens);
    final resolvedMainSemanticsLabel = mainSemanticsLabel ?? label;
    final resolvedDropdownSemanticsLabel =
        dropdownSemanticsLabel ??
        context.messages.designSystemSplitButtonDropdownSemantics(
          resolvedMainSemanticsLabel,
        );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(sizeSpec.cornerRadius),
    );

    final splitButton = Material(
      color: Colors.transparent,
      child: Ink(
        decoration: ShapeDecoration(
          color: styleSpec.backgroundColor,
          shape: shape,
        ),
        child: DefaultTextStyle.merge(
          style: sizeSpec.labelStyle.copyWith(color: styleSpec.foregroundColor),
          child: IconTheme.merge(
            data: IconThemeData(
              color: styleSpec.foregroundColor,
              size: sizeSpec.iconSize,
            ),
            child: SizedBox(
              height: sizeSpec.height,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: Semantics(
                      button: true,
                      enabled: enabled,
                      label: resolvedMainSemanticsLabel,
                      child: InkWell(
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(sizeSpec.cornerRadius),
                        ),
                        onTap: enabled ? onPressed : null,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: sizeSpec.mainHorizontalPadding,
                          ),
                          child: Center(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: sizeSpec.dividerWidth),
                  Semantics(
                    button: true,
                    enabled: enabled,
                    label: resolvedDropdownSemanticsLabel,
                    child: InkWell(
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(sizeSpec.cornerRadius),
                      ),
                      onTap: enabled ? onDropdownPressed : null,
                      child: SizedBox(
                        width: sizeSpec.dropdownWidth,
                        child: Center(
                          child: Icon(
                            isDropdownOpen
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return splitButton.withDisabledOpacity(
      enabled: enabled,
      disabledOpacity: tokens.colors.text.lowEmphasis.a,
    );
  }
}

class _SplitButtonSizeSpec {
  const _SplitButtonSizeSpec({
    required this.labelStyle,
    required this.height,
    required this.mainHorizontalPadding,
    required this.dropdownWidth,
    required this.cornerRadius,
    required this.iconSize,
    required this.dividerWidth,
  });

  factory _SplitButtonSizeSpec.fromTokens(
    DsTokens tokens,
    DesignSystemSplitButtonSize size,
  ) {
    return switch (size) {
      DesignSystemSplitButtonSize.small => _SplitButtonSizeSpec(
        labelStyle: tokens.typography.styles.subtitle.subtitle2,
        height:
            tokens.typography.lineHeight.subtitle2 + tokens.spacing.step2 * 2,
        mainHorizontalPadding: tokens.spacing.step3,
        dropdownWidth:
            tokens.typography.lineHeight.subtitle2 + tokens.spacing.step2 * 2,
        cornerRadius:
            (tokens.typography.lineHeight.subtitle2 +
                tokens.spacing.step2 * 2) /
            2,
        iconSize: tokens.typography.lineHeight.caption,
        dividerWidth: tokens.spacing.step1 / 2,
      ),
      DesignSystemSplitButtonSize.compact => _SplitButtonSizeSpec(
        labelStyle: tokens.typography.styles.subtitle.subtitle2,
        height:
            tokens.typography.lineHeight.subtitle2 + tokens.spacing.step3 * 2,
        mainHorizontalPadding: tokens.spacing.step4,
        dropdownWidth:
            tokens.typography.lineHeight.subtitle2 + tokens.spacing.step3 * 2,
        cornerRadius:
            (tokens.typography.lineHeight.subtitle2 +
                tokens.spacing.step3 * 2) /
            2,
        iconSize: tokens.typography.lineHeight.caption,
        dividerWidth: tokens.spacing.step1 / 2,
      ),
      DesignSystemSplitButtonSize.defaultSize => _SplitButtonSizeSpec(
        labelStyle: tokens.typography.styles.subtitle.subtitle1,
        height:
            tokens.typography.lineHeight.subtitle1 + tokens.spacing.step4 * 2,
        mainHorizontalPadding: tokens.spacing.step4,
        dropdownWidth:
            tokens.typography.lineHeight.subtitle1 + tokens.spacing.step4 * 2,
        cornerRadius:
            (tokens.typography.lineHeight.subtitle1 +
                tokens.spacing.step4 * 2) /
            2,
        iconSize: tokens.typography.lineHeight.caption,
        dividerWidth: tokens.spacing.step1 / 2,
      ),
    };
  }

  final TextStyle labelStyle;
  final double height;
  final double mainHorizontalPadding;
  final double dropdownWidth;
  final double cornerRadius;
  final double iconSize;
  final double dividerWidth;
}

class _SplitButtonStyleSpec {
  const _SplitButtonStyleSpec({
    required this.backgroundColor,
    required this.foregroundColor,
  });

  factory _SplitButtonStyleSpec.fromTokens(DsTokens tokens) {
    return _SplitButtonStyleSpec(
      backgroundColor: tokens.colors.interactive.enabled,
      foregroundColor: tokens.colors.text.onInteractiveAlert,
    );
  }

  final Color backgroundColor;
  final Color foregroundColor;
}
