import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

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
    this.size = DesignSystemListItemSize.medium,
    this.leading,
    this.trailing,
    this.selected = false,
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
  final DesignSystemListItemSize size;
  final Widget? leading;

  /// Optional feature metadata placed before the standard trailing affordance.
  final Widget? trailing;

  final DesignSystemSelectionRowType type;
  final bool selected;

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

    return Semantics(
      container: true,
      label: resolvedSemanticLabel,
      button: isMulti ? null : true,
      selected: isSingle ? selected : null,
      checked: isMulti ? selected : null,
      enabled: onTap != null,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: tokens.spacing.step9),
        child: DesignSystemListItem(
          title: title,
          subtitle: subtitle,
          subtitleMaxLines: subtitleMaxLines,
          size: size,
          leading: leading == null
              ? null
              : SizedBox(
                  width: tokens.spacing.step8,
                  child: Center(child: leading),
                ),
          trailing: trailing,
          trailingExtra: standardTrailing,
          activated: (isSingle || isMulti) && selected,
          activatedBackgroundColor: tokens.colors.surface.selected,
          onTap: onTap,
          focusNode: focusNode,
          onHoverChanged: onHoverChanged,
          onFocusChanged: onFocusChanged,
          excludeFromSemantics: true,
        ),
      ),
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
          Icons.chevron_right_rounded,
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
          Icons.check_rounded,
          color: accent,
          size: tokens.spacing.step6,
        ),
      ],
    );
  }
}
