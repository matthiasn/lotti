import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/utils/disabled_overlay.dart';

const _kDefaultBorderAlpha = 0.12;

enum DesignSystemTextInputSize {
  small,
  medium,
}

class DesignSystemTextInput extends StatefulWidget {
  const DesignSystemTextInput({
    this.controller,
    this.size = DesignSystemTextInputSize.medium,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.leadingIcon,
    this.trailingIcon,
    this.onTrailingIconTap,
    this.enabled = true,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.semanticsLabel,
    super.key,
  });

  final TextEditingController? controller;
  final DesignSystemTextInputSize size;
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingIconTap;
  final bool enabled;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? semanticsLabel;

  @override
  State<DesignSystemTextInput> createState() => _DesignSystemTextInputState();
}

class _DesignSystemTextInputState extends State<DesignSystemTextInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _ownsController = false;
  bool _focused = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (widget.enabled) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _TextInputSpec.fromTokens(tokens, widget.size);
    final hasError = widget.errorText != null;
    final borderColor = _resolveBorderColor(tokens, hasError);

    final input = Semantics(
      container: true,
      label: widget.semanticsLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null) ...[
            Text(
              widget.label!,
              style: spec.labelStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: spec.labelGap),
          ],
          MouseRegion(
            onEnter: widget.enabled
                ? (_) => setState(() => _hovered = true)
                : null,
            onExit: widget.enabled
                ? (_) => setState(() => _hovered = false)
                : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(spec.borderRadius),
                border: Border.all(
                  color: borderColor,
                  width: _focused ? 2 : 1,
                ),
              ),
              child: SizedBox(
                height: spec.fieldHeight,
                child: Center(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    obscureText: widget.obscureText,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    style: spec.textStyle,
                    cursorColor: tokens.colors.text.mediumEmphasis,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: spec.hintStyle,
                      contentPadding: spec.contentPadding,
                      isDense: true,
                      border: InputBorder.none,
                      prefixIcon: widget.leadingIcon != null
                          ? Icon(
                              widget.leadingIcon,
                              size: spec.iconSize,
                              color: tokens.colors.text.mediumEmphasis,
                            )
                          : null,
                      suffixIcon: widget.trailingIcon != null
                          ? IconButton(
                              icon: Icon(
                                widget.trailingIcon,
                                size: spec.iconSize,
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                              onPressed: widget.enabled
                                  ? widget.onTrailingIconTap
                                  : null,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_hasExtraInfo) ...[
            SizedBox(height: spec.extraInfoGap),
            Text(
              hasError ? widget.errorText! : widget.helperText!,
              style: hasError ? spec.errorStyle : spec.helperStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    return input.withDisabledOpacity(
      enabled: widget.enabled,
      disabledOpacity: tokens.colors.text.lowEmphasis.a,
    );
  }

  bool get _hasExtraInfo =>
      widget.helperText != null || widget.errorText != null;

  Color _resolveBorderColor(DsTokens tokens, bool hasError) {
    if (hasError) return tokens.colors.alert.error.defaultColor;
    if (_focused) return tokens.colors.interactive.enabled;
    if (_hovered) return tokens.colors.text.mediumEmphasis;
    return tokens.colors.text.highEmphasis.withValues(
      alpha: _kDefaultBorderAlpha,
    );
  }
}

class _TextInputSpec {
  const _TextInputSpec({
    required this.fieldHeight,
    required this.borderRadius,
    required this.contentPadding,
    required this.iconSize,
    required this.labelGap,
    required this.extraInfoGap,
    required this.textStyle,
    required this.hintStyle,
    required this.labelStyle,
    required this.helperStyle,
    required this.errorStyle,
  });

  factory _TextInputSpec.fromTokens(
    DsTokens tokens,
    DesignSystemTextInputSize size,
  ) {
    final isSmall = size == DesignSystemTextInputSize.small;

    return _TextInputSpec(
      fieldHeight: isSmall ? tokens.spacing.step8 : tokens.spacing.step9,
      borderRadius: tokens.spacing.step5,
      contentPadding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step2,
      ),
      iconSize: isSmall
          ? tokens.typography.lineHeight.subtitle2
          : tokens.spacing.step6,
      labelGap: tokens.spacing.step2,
      extraInfoGap: tokens.spacing.step2,
      textStyle:
          (isSmall
                  ? tokens.typography.styles.body.bodySmall
                  : tokens.typography.styles.body.bodyMedium)
              .copyWith(color: tokens.colors.text.highEmphasis),
      hintStyle:
          (isSmall
                  ? tokens.typography.styles.body.bodySmall
                  : tokens.typography.styles.body.bodyMedium)
              .copyWith(color: tokens.colors.text.lowEmphasis),
      labelStyle: tokens.typography.styles.subtitle.subtitle2.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
      helperStyle: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
      errorStyle: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.alert.error.defaultColor,
      ),
    );
  }

  final double fieldHeight;
  final double borderRadius;
  final EdgeInsets contentPadding;
  final double iconSize;
  final double labelGap;
  final double extraInfoGap;
  final TextStyle textStyle;
  final TextStyle hintStyle;
  final TextStyle labelStyle;
  final TextStyle helperStyle;
  final TextStyle errorStyle;
}
