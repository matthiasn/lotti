part of 'design_system_dropdown.dart';

// Overlay menu surface for [DesignSystemDropdown]: the elevated panel,
// its per-item rows, and the multi-select selection box.

class _DropdownMenuPanel extends StatelessWidget {
  const _DropdownMenuPanel({
    required this.items,
    required this.type,
    required this.sizeSpec,
    required this.styleSpec,
    required this.scrollController,
    this.onItemPressed,
  });

  final List<DesignSystemDropdownItem> items;
  final DesignSystemDropdownType type;
  final _DropdownSizeSpec sizeSpec;
  final _DropdownStyleSpec styleSpec;
  final ScrollController scrollController;
  final ValueChanged<DesignSystemDropdownItem>? onItemPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: styleSpec.menuBackgroundColor,
        borderRadius: BorderRadius.circular(sizeSpec.panelRadius),
        boxShadow: [
          BoxShadow(
            color: styleSpec.menuShadowColor,
            blurRadius: sizeSpec.menuShadowBlurRadius,
            offset: Offset(0, sizeSpec.menuShadowOffset),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(sizeSpec.panelRadius),
        child: ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(
            scrollbars: false,
          ),
          child: RawScrollbar(
            controller: scrollController,
            thumbVisibility: true,
            radius: Radius.circular(sizeSpec.scrollbarRadius),
            thickness: sizeSpec.scrollbarThickness,
            thumbColor: styleSpec.scrollbarColor,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: sizeSpec.panelMaxHeight),
              child: ListView.builder(
                controller: scrollController,
                padding: EdgeInsets.zero,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _DropdownMenuRow(
                    item: item,
                    type: type,
                    sizeSpec: sizeSpec,
                    styleSpec: styleSpec,
                    onTap: onItemPressed == null
                        ? null
                        : () => onItemPressed!(item),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownMenuRow extends StatelessWidget {
  const _DropdownMenuRow({
    required this.item,
    required this.type,
    required this.sizeSpec,
    required this.styleSpec,
    this.onTap,
  });

  final DesignSystemDropdownItem item;
  final DesignSystemDropdownType type;
  final _DropdownSizeSpec sizeSpec;
  final _DropdownStyleSpec styleSpec;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasCheckbox = type == DesignSystemDropdownType.multiselect;

    final row = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: sizeSpec.menuItemMinHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: sizeSpec.menuItemHorizontalPadding,
              vertical: sizeSpec.menuItemVerticalPadding,
            ),
            child: Row(
              children: [
                if (hasCheckbox) ...[
                  _DropdownSelectionBox(
                    selected: item.selected,
                    sizeSpec: sizeSpec,
                    styleSpec: styleSpec,
                  ),
                  SizedBox(width: sizeSpec.menuCheckboxGap),
                ],
                Expanded(
                  child: Text(
                    item.label,
                    style: sizeSpec.menuItemStyle.copyWith(
                      color: styleSpec.menuItemColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return hasCheckbox ? Semantics(selected: item.selected, child: row) : row;
  }
}

class _DropdownSelectionBox extends StatelessWidget {
  const _DropdownSelectionBox({
    required this.selected,
    required this.sizeSpec,
    required this.styleSpec,
  });

  final bool selected;
  final _DropdownSizeSpec sizeSpec;
  final _DropdownStyleSpec styleSpec;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: sizeSpec.checkboxSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? styleSpec.checkboxSelectedFillColor : null,
          borderRadius: BorderRadius.circular(sizeSpec.checkboxRadius),
          border: Border.all(
            color: selected
                ? styleSpec.checkboxSelectedFillColor
                : styleSpec.checkboxBorderColor,
            width: sizeSpec.checkboxBorderWidth,
          ),
        ),
        child: selected
            ? Center(
                child: Icon(
                  Icons.check_rounded,
                  size: sizeSpec.checkboxGlyphSize,
                  color: styleSpec.checkboxGlyphColor,
                ),
              )
            : null,
      ),
    );
  }
}
