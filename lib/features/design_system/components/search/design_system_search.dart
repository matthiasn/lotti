import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

enum DesignSystemSearchSize {
  small,
  medium,
}

class DesignSystemSearch extends StatefulWidget {
  const DesignSystemSearch({
    required this.hintText,
    this.size = DesignSystemSearchSize.medium,
    this.controller,
    this.focusNode,
    this.initialText,
    this.enabled = true,
    this.semanticsLabel,
    this.onChanged,
    this.onSubmitted,
    this.onSearchPressed,
    this.onClear,
    super.key,
  }) : assert(
         controller == null || initialText == null,
         'Provide either a controller or an initialText, not both.',
       );

  final String hintText;
  final DesignSystemSearchSize size;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? initialText;
  final bool enabled;
  final String? semanticsLabel;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onSearchPressed;
  final VoidCallback? onClear;

  @override
  State<DesignSystemSearch> createState() => _DesignSystemSearchState();
}

class _DesignSystemSearchState extends State<DesignSystemSearch> {
  static const _textAlignVertical = TextAlignVertical(y: -0.25);

  TextEditingController? _internalController;
  TextEditingController get _controller =>
      widget.controller ??
      (_internalController ??= TextEditingController(text: widget.initialText));

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant DesignSystemSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final oldInternalController = _internalController;
      oldWidget.controller?.removeListener(_handleControllerChanged);
      oldInternalController?.removeListener(_handleControllerChanged);
      if (widget.controller == null) {
        _internalController = TextEditingController(text: widget.initialText);
      } else {
        _internalController = null;
        oldInternalController?.dispose();
      }
      _controller.addListener(_handleControllerChanged);
    } else if (widget.controller == null &&
        oldWidget.initialText != widget.initialText) {
      _internalController?.text = widget.initialText ?? '';
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _SearchSpec.fromTokens(tokens, widget.size);
    final hasText = _controller.text.isNotEmpty;
    final textStyle = spec.textStyle.copyWith(
      height: 1,
      color: widget.enabled
          ? tokens.colors.text.highEmphasis
          : tokens.colors.text.lowEmphasis,
    );
    final hintStyle = spec.textStyle.copyWith(
      height: 1,
      color: tokens.colors.text.lowEmphasis,
    );

    return DecoratedBox(
      key: const Key('design-system-search-shell'),
      decoration: BoxDecoration(
        color: tokens.colors.background.level01,
        borderRadius: BorderRadius.circular(spec.borderRadius),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: SizedBox(
        height: spec.height,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spec.horizontalPadding,
            vertical: spec.verticalPadding,
          ),
          child: Row(
            children: [
              _SearchActionButton(
                size: spec,
                enabled: widget.enabled,
                semanticsLabel: widget.semanticsLabel ?? widget.hintText,
                onPressed: widget.enabled ? _handleSearchPressed : null,
              ),
              SizedBox(width: spec.gap),
              Expanded(
                child: SizedBox(
                  height: spec.contentHeight,
                  child: TextField(
                    controller: _controller,
                    focusNode: widget.focusNode,
                    enabled: widget.enabled,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    textInputAction: TextInputAction.search,
                    strutStyle: StrutStyle.fromTextStyle(
                      textStyle,
                      forceStrutHeight: true,
                    ),
                    style: textStyle,
                    textAlignVertical: _textAlignVertical,
                    cursorHeight: spec.contentHeight,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: hintStyle,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      isCollapsed: true,
                    ),
                  ),
                ),
              ),
              if (hasText) ...[
                SizedBox(width: spec.gap),
                _SearchClearButton(
                  size: spec,
                  enabled: widget.enabled,
                  color: tokens.colors.text.highEmphasis,
                  semanticsLabel: MaterialLocalizations.of(
                    context,
                  ).cancelButtonLabel,
                  onPressed: widget.enabled ? _handleClearPressed : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleSearchPressed() {
    widget.onSearchPressed?.call(_controller.text);
  }

  void _handleClearPressed() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }
}

class _SearchActionButton extends StatelessWidget {
  const _SearchActionButton({
    required this.size,
    required this.enabled,
    required this.semanticsLabel,
    this.onPressed,
  });

  final _SearchSpec size;
  final bool enabled;
  final String semanticsLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onPressed,
          radius: size.iconTapRadius,
          child: SizedBox(
            width: size.iconSize,
            height: size.iconSize,
            child: Icon(
              Icons.search_rounded,
              size: size.iconSize,
              color: enabled
                  ? tokens.colors.text.mediumEmphasis
                  : tokens.colors.text.lowEmphasis,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchClearButton extends StatelessWidget {
  const _SearchClearButton({
    required this.size,
    required this.enabled,
    required this.color,
    required this.semanticsLabel,
    this.onPressed,
  });

  final _SearchSpec size;
  final bool enabled;
  final Color color;
  final String semanticsLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onPressed,
          radius: size.clearButtonHeight / 2,
          child: SizedBox(
            width: size.clearButtonWidth,
            height: size.clearButtonHeight,
            child: Center(
              child: Icon(
                Icons.cancel_rounded,
                size: size.clearIconSize,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchSpec {
  const _SearchSpec({
    required this.height,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.gap,
    required this.contentHeight,
    required this.borderRadius,
    required this.iconSize,
    required this.iconTapRadius,
    required this.clearButtonWidth,
    required this.clearButtonHeight,
    required this.clearIconSize,
    required this.textStyle,
  });

  factory _SearchSpec.fromTokens(
    DsTokens tokens,
    DesignSystemSearchSize size,
  ) {
    return switch (size) {
      DesignSystemSearchSize.small => _SearchSpec(
        height: 48,
        horizontalPadding: 12,
        verticalPadding: 4,
        gap: tokens.spacing.step3,
        contentHeight: 20,
        borderRadius: tokens.radii.m,
        iconSize: 20,
        iconTapRadius: 18,
        clearButtonWidth: 32,
        clearButtonHeight: 36,
        clearIconSize: 20,
        textStyle: tokens.typography.styles.body.bodySmall,
      ),
      DesignSystemSearchSize.medium => _SearchSpec(
        height: 56,
        horizontalPadding: 12,
        verticalPadding: 8,
        gap: tokens.spacing.step3,
        contentHeight: 24,
        borderRadius: tokens.radii.m,
        iconSize: 24,
        iconTapRadius: 20,
        clearButtonWidth: 32,
        clearButtonHeight: 36,
        clearIconSize: 20,
        textStyle: tokens.typography.styles.body.bodyMedium,
      ),
    };
  }

  final double height;
  final double horizontalPadding;
  final double verticalPadding;
  final double gap;
  final double contentHeight;
  final double borderRadius;
  final double iconSize;
  final double iconTapRadius;
  final double clearButtonWidth;
  final double clearButtonHeight;
  final double clearIconSize;
  final TextStyle textStyle;
}
