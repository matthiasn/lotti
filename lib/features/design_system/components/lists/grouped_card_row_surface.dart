import 'package:flutter/material.dart';

class GroupedCardRowSurface extends StatefulWidget {
  const GroupedCardRowSurface({
    required this.selected,
    required this.hoverColor,
    required this.selectedColor,
    required this.padding,
    required this.onTap,
    required this.child,
    this.rowKey,
    this.backgroundKey,
    this.onHoverChanged,
    this.topOverlap = 0,
    this.bottomOverlap = 0,
    this.backgroundTopInset = 0,
    this.backgroundBottomInset = 0,
    this.backgroundBorderRadius,
    super.key,
  });

  final Key? rowKey;
  final Key? backgroundKey;
  final bool selected;
  final Color hoverColor;
  final Color selectedColor;
  final EdgeInsetsGeometry padding;
  final VoidCallback onTap;
  final Widget child;
  final ValueChanged<bool>? onHoverChanged;
  final double topOverlap;
  final double bottomOverlap;
  final double backgroundTopInset;
  final double backgroundBottomInset;
  final BorderRadius? backgroundBorderRadius;

  @override
  State<GroupedCardRowSurface> createState() => _GroupedCardRowSurfaceState();
}

class _GroupedCardRowSurfaceState extends State<GroupedCardRowSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.selected
        ? widget.selectedColor
        : (_hovered ? widget.hoverColor : null);

    return Semantics(
      selected: widget.selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: widget.rowKey,
          onTap: widget.onTap,
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onHover: (value) {
            if (_hovered != value) {
              setState(() {
                _hovered = value;
              });
              widget.onHoverChanged?.call(value);
            }
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (backgroundColor != null)
                Positioned(
                  top: -(widget.backgroundTopInset + widget.topOverlap),
                  right: 0,
                  bottom:
                      -(widget.backgroundBottomInset + widget.bottomOverlap),
                  left: 0,
                  child: DecoratedBox(
                    key: widget.backgroundKey,
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: widget.backgroundBorderRadius,
                    ),
                  ),
                ),
              Padding(
                padding: widget.padding,
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
