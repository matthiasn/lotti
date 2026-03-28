import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/utils/disabled_overlay.dart';

enum DesignSystemTextareaSize {
  small,
  medium,
}

class DesignSystemTextarea extends StatefulWidget {
  const DesignSystemTextarea({
    this.controller,
    this.size = DesignSystemTextareaSize.medium,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.maxLength,
    this.showCounter = false,
    this.enabled = true,
    this.minLines = 3,
    this.maxLines,
    this.onChanged,
    this.semanticsLabel,
    super.key,
  });

  final TextEditingController? controller;
  final DesignSystemTextareaSize size;
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final int? maxLength;
  final bool showCounter;
  final bool enabled;
  final int minLines;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final String? semanticsLabel;

  @override
  State<DesignSystemTextarea> createState() => _DesignSystemTextareaState();
}

class _DesignSystemTextareaState extends State<DesignSystemTextarea> {
  static const InputBorder _noBorder = InputBorder.none;

  late final TextEditingController _controller;
  bool _ownsController = false;
  bool _focused = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _ownsController = true;
    }
    if (widget.showCounter) {
      _controller.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _TextareaSpec.fromTokens(tokens, widget.size);
    final hasError = widget.errorText != null;
    final borderColor = _resolveBorderColor(tokens, hasError);

    final textarea = Semantics(
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
            child: Focus(
              onFocusChange: widget.enabled
                  ? (focused) => setState(() => _focused = focused)
                  : null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(spec.borderRadius),
                  border: Border.all(
                    color: borderColor,
                    width: _focused ? 2 : 1,
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  enabled: widget.enabled,
                  minLines: widget.minLines,
                  maxLines: widget.maxLines ?? widget.minLines + 2,
                  maxLength: widget.maxLength,
                  onChanged: widget.onChanged,
                  style: spec.textStyle,
                  cursorColor: tokens.colors.text.highEmphasis,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: spec.hintStyle,
                    contentPadding: spec.contentPadding,
                    border: _noBorder,
                    enabledBorder: _noBorder,
                    disabledBorder: _noBorder,
                    focusedBorder: _noBorder,
                    errorBorder: _noBorder,
                    focusedErrorBorder: _noBorder,
                    counterText: '',
                  ),
                ),
              ),
            ),
          ),
          if (_hasExtraInfo) ...[
            SizedBox(height: spec.extraInfoGap),
            Row(
              children: [
                if (widget.helperText != null || widget.errorText != null)
                  Expanded(
                    child: Text(
                      hasError ? widget.errorText! : widget.helperText!,
                      style: hasError ? spec.errorStyle : spec.helperStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (widget.showCounter && widget.maxLength != null)
                  Text(
                    '${_controller.text.length}/${widget.maxLength}',
                    style: spec.counterStyle,
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    return textarea.withDisabledOpacity(
      enabled: widget.enabled,
      disabledOpacity: tokens.colors.text.lowEmphasis.a,
    );
  }

  bool get _hasExtraInfo =>
      widget.helperText != null ||
      widget.errorText != null ||
      (widget.showCounter && widget.maxLength != null);

  Color _resolveBorderColor(DsTokens tokens, bool hasError) {
    if (hasError) return tokens.colors.alert.error.defaultColor;
    if (_focused) return tokens.colors.interactive.enabled;
    if (_hovered) return tokens.colors.text.mediumEmphasis;
    return tokens.colors.text.highEmphasis.withValues(alpha: 0.12);
  }
}

class _TextareaSpec {
  const _TextareaSpec({
    required this.borderRadius,
    required this.contentPadding,
    required this.labelGap,
    required this.extraInfoGap,
    required this.textStyle,
    required this.hintStyle,
    required this.labelStyle,
    required this.helperStyle,
    required this.errorStyle,
    required this.counterStyle,
  });

  factory _TextareaSpec.fromTokens(
    DsTokens tokens,
    DesignSystemTextareaSize size,
  ) {
    final isSmall = size == DesignSystemTextareaSize.small;

    return _TextareaSpec(
      borderRadius: tokens.spacing.step5,
      contentPadding: EdgeInsets.only(
        left: tokens.spacing.step4,
        right: tokens.spacing.step4,
        top: tokens.spacing.step4,
        bottom: tokens.spacing.step3,
      ),
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
      counterStyle: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
    );
  }

  final double borderRadius;
  final EdgeInsets contentPadding;
  final double labelGap;
  final double extraInfoGap;
  final TextStyle textStyle;
  final TextStyle hintStyle;
  final TextStyle labelStyle;
  final TextStyle helperStyle;
  final TextStyle errorStyle;
  final TextStyle counterStyle;
}
