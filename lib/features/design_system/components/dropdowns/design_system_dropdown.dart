import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/utils/disabled_overlay.dart';

part 'design_system_dropdown_panel.dart';

const _kMenuShadowAlpha = 0.25;

enum DesignSystemDropdownType {
  dropdownList,
  multiselect,
}

/// One selectable entry in a [DesignSystemDropdown].
///
/// Identified by [id] and shown with [label]; [selected] reflects its current
/// state. In multiselect mode the chosen item surfaces as a chip whose text is
/// [chipLabel] when set, otherwise the [label] (see [resolvedChipLabel]).
class DesignSystemDropdownItem {
  const DesignSystemDropdownItem({
    required this.id,
    required this.label,
    this.selected = false,
    this.chipLabel,
  });

  final String id;
  final String label;
  final bool selected;
  final String? chipLabel;

  String get resolvedChipLabel => chipLabel ?? label;
}

/// The design-system's dropdown — an expandable field that reveals a panel of
/// [DesignSystemDropdownItem]s.
///
/// [type] switches between a single-choice `dropdownList` and a `multiselect`
/// that surfaces removable chips. Expansion is reported via [onExpandedChanged]
/// (seeded by [initiallyExpanded]); item taps and chip removals fire
/// [onItemPressed]/[onChipRemoved]. [enabled] toggles interactivity and
/// requires a visible [label] or a [semanticsLabel].
class DesignSystemDropdown extends StatefulWidget {
  const DesignSystemDropdown({
    required this.label,
    required this.inputLabel,
    required this.items,
    this.type = DesignSystemDropdownType.dropdownList,
    this.initiallyExpanded = false,
    this.enabled = true,
    this.semanticsLabel,
    this.onExpandedChanged,
    this.onItemPressed,
    this.onChipRemoved,
    super.key,
  }) : assert(
         label != '' || semanticsLabel != null,
         'Provide either a visible label or a semanticsLabel.',
       );

  final String label;
  final String inputLabel;
  final List<DesignSystemDropdownItem> items;
  final DesignSystemDropdownType type;
  final bool initiallyExpanded;
  final bool enabled;
  final String? semanticsLabel;
  final ValueChanged<bool>? onExpandedChanged;
  final ValueChanged<DesignSystemDropdownItem>? onItemPressed;
  final ValueChanged<DesignSystemDropdownItem>? onChipRemoved;

  @override
  State<DesignSystemDropdown> createState() => _DesignSystemDropdownState();
}

class _DesignSystemDropdownState extends State<DesignSystemDropdown> {
  late bool _expanded = widget.initiallyExpanded;
  late final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant DesignSystemDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled && _expanded) {
      _expanded = false;
      widget.onExpandedChanged?.call(false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final sizeSpec = _DropdownSizeSpec.fromTokens(tokens);
    final styleSpec = _DropdownStyleSpec.fromTokens(
      tokens: tokens,
      expanded: _expanded,
    );
    final selectedItems = widget.items.where((item) => item.selected).toList();
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _DropdownTrigger(
          label: widget.label,
          inputLabel: widget.inputLabel,
          semanticsLabel: widget.semanticsLabel ?? widget.label,
          expanded: _expanded,
          enabled: widget.enabled,
          sizeSpec: sizeSpec,
          styleSpec: styleSpec,
          onTap: widget.enabled ? _toggleExpanded : null,
        ),
        if (widget.type == DesignSystemDropdownType.multiselect &&
            selectedItems.isNotEmpty) ...[
          SizedBox(height: sizeSpec.contentGap),
          Wrap(
            spacing: sizeSpec.selectionGap,
            runSpacing: sizeSpec.selectionGap,
            children: [
              for (final item in selectedItems)
                DesignSystemChip(
                  label: item.resolvedChipLabel,
                  showRemove: widget.enabled && widget.onChipRemoved != null,
                  onPressed: widget.enabled && widget.onChipRemoved != null
                      ? () => widget.onChipRemoved!(item)
                      : null,
                ),
            ],
          ),
        ],
        if (_expanded) ...[
          SizedBox(height: sizeSpec.contentGap),
          _DropdownMenuPanel(
            items: widget.items,
            type: widget.type,
            sizeSpec: sizeSpec,
            styleSpec: styleSpec,
            scrollController: _scrollController,
            onItemPressed: widget.enabled ? _handleItemPressed : null,
          ),
        ],
      ],
    );

    return content.withDisabledOpacity(
      enabled: widget.enabled,
      disabledOpacity: tokens.colors.text.lowEmphasis.a,
    );
  }

  void _toggleExpanded() {
    final nextValue = !_expanded;
    setState(() => _expanded = nextValue);
    widget.onExpandedChanged?.call(nextValue);
  }

  void _handleItemPressed(DesignSystemDropdownItem item) {
    widget.onItemPressed?.call(item);
    if (!mounted) {
      return;
    }

    if (widget.type == DesignSystemDropdownType.dropdownList && _expanded) {
      setState(() => _expanded = false);
      widget.onExpandedChanged?.call(false);
    }
  }
}

class _DropdownTrigger extends StatelessWidget {
  const _DropdownTrigger({
    required this.label,
    required this.inputLabel,
    required this.semanticsLabel,
    required this.expanded,
    required this.enabled,
    required this.sizeSpec,
    required this.styleSpec,
    this.onTap,
  });

  final String label;
  final String inputLabel;
  final String semanticsLabel;
  final bool expanded;
  final bool enabled;
  final _DropdownSizeSpec sizeSpec;
  final _DropdownStyleSpec styleSpec;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: ShapeDecoration(
          color: styleSpec.fieldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(sizeSpec.fieldRadius),
            side: BorderSide(
              color: styleSpec.fieldBorderColor,
              width: sizeSpec.fieldBorderWidth,
            ),
          ),
        ),
        child: Semantics(
          container: true,
          button: true,
          enabled: enabled,
          label: semanticsLabel,
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(sizeSpec.fieldRadius),
            onTap: onTap,
            child: SizedBox(
              key: const ValueKey('design-system-dropdown-trigger'),
              height: sizeSpec.fieldHeight,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  sizeSpec.fieldHorizontalPadding,
                  sizeSpec.fieldTopPadding,
                  sizeSpec.fieldRightPadding,
                  sizeSpec.fieldBottomPadding,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: sizeSpec.labelStyle.copyWith(
                              color: styleSpec.fieldLabelColor,
                            ),
                            textScaler: TextScaler.noScaling,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: sizeSpec.fieldTextGap),
                          Text(
                            inputLabel,
                            style: sizeSpec.inputStyle.copyWith(
                              color: styleSpec.fieldInputColor,
                            ),
                            textScaler: TextScaler.noScaling,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: sizeSpec.chevronGap),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: sizeSpec.chevronSize,
                      color: styleSpec.fieldChevronColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownSizeSpec {
  const _DropdownSizeSpec({
    required this.fieldHeight,
    required this.fieldRadius,
    required this.fieldBorderWidth,
    required this.fieldHorizontalPadding,
    required this.fieldRightPadding,
    required this.fieldTopPadding,
    required this.fieldBottomPadding,
    required this.fieldTextGap,
    required this.chevronGap,
    required this.chevronSize,
    required this.contentGap,
    required this.selectionGap,
    required this.panelRadius,
    required this.panelMaxHeight,
    required this.menuItemMinHeight,
    required this.menuItemHorizontalPadding,
    required this.menuItemVerticalPadding,
    required this.menuCheckboxGap,
    required this.scrollbarThickness,
    required this.scrollbarRadius,
    required this.menuShadowBlurRadius,
    required this.menuShadowOffset,
    required this.checkboxSize,
    required this.checkboxRadius,
    required this.checkboxBorderWidth,
    required this.checkboxGlyphSize,
    required this.labelStyle,
    required this.inputStyle,
    required this.menuItemStyle,
  });

  factory _DropdownSizeSpec.fromTokens(DsTokens tokens) {
    final fieldHeight =
        tokens.typography.lineHeight.bodyLarge + tokens.spacing.step5 * 2;
    final panelMaxHeight = tokens.spacing.step13 * 2;
    final menuItemMinHeight =
        tokens.typography.lineHeight.bodyLarge + tokens.spacing.step5 * 2;
    final checkboxSize =
        tokens.typography.lineHeight.bodySmall + tokens.spacing.step2;

    return _DropdownSizeSpec(
      fieldHeight: fieldHeight,
      fieldRadius: tokens.radii.xl,
      fieldBorderWidth: tokens.spacing.step1,
      fieldHorizontalPadding: tokens.spacing.step5,
      fieldRightPadding: tokens.spacing.step5,
      fieldTopPadding: tokens.spacing.step2,
      fieldBottomPadding: tokens.spacing.step2,
      fieldTextGap: tokens.spacing.step1,
      chevronGap: tokens.spacing.step4,
      chevronSize: tokens.typography.lineHeight.bodyLarge,
      contentGap: tokens.spacing.step3,
      selectionGap: tokens.spacing.step3,
      panelRadius: tokens.radii.sectionCards,
      panelMaxHeight: panelMaxHeight,
      menuItemMinHeight: menuItemMinHeight,
      menuItemHorizontalPadding: tokens.spacing.step5,
      menuItemVerticalPadding: tokens.spacing.step4,
      menuCheckboxGap: tokens.spacing.step4,
      scrollbarThickness: tokens.spacing.step3,
      scrollbarRadius: tokens.radii.xl,
      menuShadowBlurRadius: tokens.spacing.step4,
      menuShadowOffset: tokens.spacing.step1,
      checkboxSize: checkboxSize,
      checkboxRadius: tokens.radii.s,
      checkboxBorderWidth: tokens.spacing.step1 / 2,
      checkboxGlyphSize: checkboxSize - tokens.spacing.step3,
      labelStyle: tokens.typography.styles.others.caption,
      inputStyle: tokens.typography.styles.body.bodyLarge,
      menuItemStyle: tokens.typography.styles.body.bodyLarge,
    );
  }

  final double fieldHeight;
  final double fieldRadius;
  final double fieldBorderWidth;
  final double fieldHorizontalPadding;
  final double fieldRightPadding;
  final double fieldTopPadding;
  final double fieldBottomPadding;
  final double fieldTextGap;
  final double chevronGap;
  final double chevronSize;
  final double contentGap;
  final double selectionGap;
  final double panelRadius;
  final double panelMaxHeight;
  final double menuItemMinHeight;
  final double menuItemHorizontalPadding;
  final double menuItemVerticalPadding;
  final double menuCheckboxGap;
  final double scrollbarThickness;
  final double scrollbarRadius;
  final double menuShadowBlurRadius;
  final double menuShadowOffset;
  final double checkboxSize;
  final double checkboxRadius;
  final double checkboxBorderWidth;
  final double checkboxGlyphSize;
  final TextStyle labelStyle;
  final TextStyle inputStyle;
  final TextStyle menuItemStyle;
}

class _DropdownStyleSpec {
  const _DropdownStyleSpec({
    required this.fieldBackgroundColor,
    required this.fieldBorderColor,
    required this.fieldLabelColor,
    required this.fieldInputColor,
    required this.fieldChevronColor,
    required this.menuBackgroundColor,
    required this.menuItemColor,
    required this.menuShadowColor,
    required this.scrollbarColor,
    required this.checkboxBorderColor,
    required this.checkboxSelectedFillColor,
    required this.checkboxGlyphColor,
  });

  factory _DropdownStyleSpec.fromTokens({
    required DsTokens tokens,
    required bool expanded,
  }) {
    return _DropdownStyleSpec(
      fieldBackgroundColor: tokens.colors.background.level01,
      fieldBorderColor: expanded
          ? tokens.colors.interactive.enabled
          : tokens.colors.decorative.level02,
      fieldLabelColor: expanded
          ? tokens.colors.interactive.enabled
          : tokens.colors.text.mediumEmphasis,
      fieldInputColor: tokens.colors.text.highEmphasis,
      fieldChevronColor: tokens.colors.text.mediumEmphasis,
      menuBackgroundColor: tokens.colors.background.level01,
      menuItemColor: tokens.colors.text.highEmphasis,
      menuShadowColor: Colors.black.withValues(alpha: _kMenuShadowAlpha),
      scrollbarColor: tokens.colors.text.mediumEmphasis,
      checkboxBorderColor: tokens.colors.text.mediumEmphasis,
      checkboxSelectedFillColor: tokens.colors.interactive.enabled,
      checkboxGlyphColor: tokens.colors.text.onInteractiveAlert,
    );
  }

  final Color fieldBackgroundColor;
  final Color fieldBorderColor;
  final Color fieldLabelColor;
  final Color fieldInputColor;
  final Color fieldChevronColor;
  final Color menuBackgroundColor;
  final Color menuItemColor;
  final Color menuShadowColor;
  final Color scrollbarColor;
  final Color checkboxBorderColor;
  final Color checkboxSelectedFillColor;
  final Color checkboxGlyphColor;
}
