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

    return SizedBox(
      height: spec.height,
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
            child: Padding(
              padding: EdgeInsets.only(right: spec.trailingPadding),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: widget.focusNode,
                      enabled: widget.enabled,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                      textInputAction: TextInputAction.search,
                      style: spec.textStyle.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration.collapsed(
                        hintText: widget.hintText,
                        hintStyle: spec.textStyle.copyWith(
                          color: tokens.colors.text.lowEmphasis,
                        ),
                      ),
                    ),
                  ),
                  if (hasText)
                    _SearchClearButton(
                      enabled: widget.enabled,
                      color: tokens.colors.text.highEmphasis,
                      semanticsLabel: MaterialLocalizations.of(
                        context,
                      ).cancelButtonLabel,
                      onPressed: widget.enabled ? _handleClearPressed : null,
                    ),
                ],
              ),
            ),
          ),
        ],
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
          radius: size.height / 2,
          child: SizedBox(
            width: size.buttonWidth,
            height: size.height,
            child: Center(
              child: Icon(
                Icons.search_rounded,
                size: size.iconSize,
                color: enabled
                    ? tokens.colors.text.highEmphasis
                    : tokens.colors.text.lowEmphasis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchClearButton extends StatelessWidget {
  const _SearchClearButton({
    required this.enabled,
    required this.color,
    required this.semanticsLabel,
    this.onPressed,
  });

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
          radius: 12,
          child: SizedBox(
            width: 20,
            height: 20,
            child: Icon(
              Icons.cancel_rounded,
              size: 20,
              color: color,
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
    required this.buttonWidth,
    required this.gap,
    required this.trailingPadding,
    required this.iconSize,
    required this.textStyle,
  });

  factory _SearchSpec.fromTokens(
    DsTokens tokens,
    DesignSystemSearchSize size,
  ) {
    return switch (size) {
      DesignSystemSearchSize.small => _SearchSpec(
        height: 36,
        buttonWidth: 32,
        gap: tokens.spacing.step3,
        trailingPadding: 0,
        iconSize: 20,
        textStyle: tokens.typography.styles.body.bodySmall,
      ),
      DesignSystemSearchSize.medium => _SearchSpec(
        height: 44,
        buttonWidth: 40,
        gap: tokens.spacing.step3,
        trailingPadding: tokens.spacing.step3,
        iconSize: 20,
        textStyle: tokens.typography.styles.body.bodyMedium,
      ),
    };
  }

  final double height;
  final double buttonWidth;
  final double gap;
  final double trailingPadding;
  final double iconSize;
  final TextStyle textStyle;
}
