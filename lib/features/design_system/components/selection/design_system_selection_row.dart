import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The interaction role of a [DesignSystemSelectionRow].
enum DesignSystemSelectionRowType {
  /// A terminal choice that applies immediately.
  singleSelect,

  /// A staged choice that toggles a checked state.
  multiSelect,

  /// A branch that opens another page in the same selection flow.
  navigation,

  /// A non-selection command rendered with the same row anatomy.
  action,
}

/// The shared row used by every modal selection flow.
///
/// It keeps the leading rail, typography, spacing, interaction states, and
/// trailing affordances identical while allowing each feature to supply its
/// own semantic icon or metadata. The full-width selected band deliberately
/// remains selected while hovered; keyboard focus is added by the underlying
/// [DesignSystemListItem]. Homogeneous option lists do not render dividers, so
/// an active row is never bisected by a partial-width rule. Every row preserves
/// the design system's minimum interactive height, including iconless actions.
class DesignSystemSelectionRow extends StatelessWidget {
  const DesignSystemSelectionRow({
    required this.title,
    required this.type,
    required this.onTap,
    this.subtitle,
    this.subtitleMaxLines = 2,
    this.subtitleEmphasis,
    this.titleMaxLines = 1,
    this.size = DesignSystemListItemSize.medium,
    this.leading,
    this.trailing,
    this.selected = false,
    this.showSelectedBackground = true,
    this.secondaryLine,
    this.selectedLabel,
    this.semanticLabel,
    this.focusNode,
    this.onHoverChanged,
    this.onFocusChanged,
    super.key,
  });

  final String title;
  final String? subtitle;
  final int? subtitleMaxLines;

  /// Overrides the subtitle ink; see [DesignSystemListItem.subtitleEmphasis].
  final Color? subtitleEmphasis;

  /// Title line cap at normal text scale. Rows whose title is long-form
  /// content rather than a short entity name (task titles, say) should raise
  /// this so a real word is never reduced to an ellipsis mid-tap. Large
  /// accessibility text un-caps the title regardless.
  final int titleMaxLines;
  final DesignSystemListItemSize size;
  final Widget? leading;

  /// Optional feature metadata placed before the standard trailing affordance.
  final Widget? trailing;

  final DesignSystemSelectionRowType type;
  final bool selected;

  /// Whether a selected row also receives the selected surface fill.
  ///
  /// Keep this false for checkbox lists where the trailing checkbox is the
  /// intended state indicator and tinting every checked row would merge the
  /// list into one visual block. Selection semantics are unaffected.
  final bool showSelectedBackground;

  /// Optional content rendered on its own line directly below the row,
  /// left-aligned to the row's title inset — the slot for a control that a
  /// narrow row cannot host in its trailing position (a cadence stepper,
  /// say). The component owns the inset metric, so the line lands on the
  /// title glyph whether or not the row has a leading rail.
  ///
  /// The line sits outside the row's tap target and semantics container:
  /// tapping it never toggles the row, and interactive children keep their
  /// own semantics.
  final Widget? secondaryLine;

  /// Optional visible state label displayed before the selected check.
  final String? selectedLabel;

  /// The deterministic accessible name for the whole row.
  ///
  /// Defaults to `title, subtitle` when a subtitle exists. Selected/checked and
  /// enabled state are exposed as semantics flags and should not be repeated in
  /// this label.
  final String? semanticLabel;
  final FocusNode? focusNode;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onHoverChanged;
  final ValueChanged<bool>? onFocusChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isSingle = type == DesignSystemSelectionRowType.singleSelect;
    final isMulti = type == DesignSystemSelectionRowType.multiSelect;
    final standardTrailing = _standardTrailing(context);
    final resolvedSemanticLabel =
        semanticLabel ??
        (subtitle == null || subtitle!.isEmpty ? title : '$title, $subtitle');

    final row = Semantics(
      container: true,
      label: resolvedSemanticLabel,
      button: isMulti ? null : true,
      selected: isSingle ? selected : null,
      checked: isMulti ? selected : null,
      enabled: onTap != null,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: TapTargets.minimum),
        child: DesignSystemListItem(
          title: title,
          titleMaxLines: MediaQuery.textScalerOf(context).scale(1) > 1.3
              ? null
              : titleMaxLines,
          subtitle: subtitle,
          subtitleMaxLines: subtitleMaxLines,
          subtitleEmphasis: subtitleEmphasis,
          size: size,
          leading: leading == null
              ? null
              : SizedBox(
                  width: tokens.spacing.step8,
                  child: Center(child: leading),
                ),
          trailing: trailing,
          trailingExtra: standardTrailing,
          activated:
              (isSingle || isMulti) && selected && showSelectedBackground,
          activatedBackgroundColor: tokens.colors.surface.selected,
          onTap: onTap,
          focusNode: focusNode,
          onHoverChanged: onHoverChanged,
          onFocusChanged: onFocusChanged,
          excludeFromSemantics: true,
        ),
      ),
    );
    if (secondaryLine == null) return row;

    // The title inset is component-owned: the list item's horizontal padding
    // plus, when a leading rail exists, the rail width and its gap. The gap
    // above the line is the row's own bottom padding — tighter than the
    // padded distance to whatever follows, so the line binds upward to its
    // row rather than floating between two.
    final titleInset =
        tokens.spacing.step5 +
        (leading != null ? tokens.spacing.step8 + tokens.spacing.step3 : 0.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        Padding(
          padding: EdgeInsets.only(
            left: titleInset,
            right: tokens.spacing.step5,
            bottom: tokens.spacing.step4,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: secondaryLine,
          ),
        ),
      ],
    );
  }

  Widget? _standardTrailing(BuildContext context) {
    final tokens = context.designTokens;
    switch (type) {
      case DesignSystemSelectionRowType.singleSelect:
        if (!selected) return null;
        return _SelectionMarker(label: selectedLabel);
      case DesignSystemSelectionRowType.multiSelect:
        return ExcludeFocus(
          child: ExcludeSemantics(
            child: DesignSystemCheckbox(
              value: selected,
              semanticsLabel: title,
              onChanged: onTap == null ? null : (_) => onTap!(),
            ),
          ),
        );
      case DesignSystemSelectionRowType.navigation:
        return Icon(
          LottiIcons.chevronRight,
          color: tokens.colors.text.mediumEmphasis,
          size: tokens.spacing.step6,
        );
      case DesignSystemSelectionRowType.action:
        return null;
    }
  }
}

class _SelectionMarker extends StatelessWidget {
  const _SelectionMarker({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label case final label?) ...[
          Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: accent,
              fontWeight: tokens.typography.weight.semiBold,
            ),
          ),
          SizedBox(width: tokens.spacing.step2),
        ],
        Icon(
          LottiIcons.confirm,
          color: accent,
          size: tokens.spacing.step6,
        ),
      ],
    );
  }
}
