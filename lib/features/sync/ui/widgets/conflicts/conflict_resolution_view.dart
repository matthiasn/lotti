import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_shared.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/entry_diff_view.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/entry_field_diff.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Callback that resolves a conflict by keeping one whole side.
typedef KeepSideCallback = Future<void> Function(ConflictSide side);

/// Callback that resolves a conflict by combining the two sides: [baseSide]
/// supplies the structural payload, [choices] overrides individual fields.
typedef CombineCallback =
    Future<void> Function({
      required ConflictSide baseSide,
      required Map<EntryField, ConflictSide> choices,
    });

/// Fields the merge assembler (`buildMergedEntity`) can pull independently.
/// Other differing fields (audio duration, the `other` catch-all) follow the
/// chosen base side, so they get no per-field toggle.
const Set<EntryField> _mergeableFields = {
  EntryField.title,
  EntryField.body,
  EntryField.category,
  EntryField.dateFrom,
  EntryField.dateTo,
  EntryField.starred,
  EntryField.private,
  EntryField.flag,
};

/// The redesigned, stress-free resolution surface: a full field-level diff plus
/// three clear paths — Keep this device, Keep from sync, or Combine (per-field
/// merge). A soft-delete-vs-edit collision is shown as a safe binary instead.
class ConflictResolutionView extends StatefulWidget {
  const ConflictResolutionView({
    required this.diff,
    required this.onKeepSide,
    required this.onCombine,
    super.key,
  });

  final EntryDiff diff;
  final KeepSideCallback onKeepSide;
  final CombineCallback onCombine;

  @override
  State<ConflictResolutionView> createState() => _ConflictResolutionViewState();
}

enum _Mode { choosing, combining }

class _ConflictResolutionViewState extends State<ConflictResolutionView> {
  _Mode _mode = _Mode.choosing;
  bool _busy = false;
  ConflictSide _baseSide = ConflictSide.local;
  final Map<EntryField, ConflictSide> _choices = {};

  List<EntryField> get _mergeableDiffering => widget.diff.fields
      .map((f) => f.field)
      .where(_mergeableFields.contains)
      .toList();

  /// Combine is the no-data-loss option, so it's recommended whenever more than
  /// one mergeable field diverged.
  bool get _recommendCombine =>
      widget.diff.shape == ConflictShape.edited &&
      _mergeableDiffering.length > 1;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _enterCombine() {
    setState(() {
      _mode = _Mode.combining;
      _baseSide = ConflictSide.local;
      _choices
        ..clear()
        ..addEntries(
          _mergeableDiffering.map((f) => MapEntry(f, ConflictSide.local)),
        );
    });
  }

  void _setBase(ConflictSide side) {
    setState(() {
      _baseSide = side;
      for (final key in _choices.keys.toList()) {
        _choices[key] = side;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final shape = widget.diff.shape;
    if (shape == ConflictShape.deletedOnLocal ||
        shape == ConflictShape.deletedOnRemote) {
      return _buildDeleteVsEdit(context, shape);
    }
    return _mode == _Mode.choosing
        ? _buildChoosing(context)
        : _buildCombining(context);
  }

  Widget _buildChoosing(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EntryDiffView(diff: widget.diff),
        SizedBox(height: tokens.spacing.step4),
        if (_recommendCombine) ...[
          const _RecommendedLabel(),
          SizedBox(height: tokens.spacing.step2),
        ],
        DesignSystemButton(
          label: messages.conflictPickerCombine,
          leadingIcon: Icons.merge_rounded,
          fullWidth: true,
          onPressed: _busy ? null : _enterCombine,
        ),
        SizedBox(height: tokens.spacing.step2),
        Row(
          children: [
            Expanded(
              child: DesignSystemButton(
                label: messages.conflictPickerUseThisDevice,
                variant: DesignSystemButtonVariant.secondary,
                fullWidth: true,
                onPressed: _busy
                    ? null
                    : () => _run(() => widget.onKeepSide(ConflictSide.local)),
              ),
            ),
            SizedBox(width: tokens.spacing.step2),
            Expanded(
              child: DesignSystemButton(
                label: messages.conflictPickerUseFromSync,
                variant: DesignSystemButtonVariant.secondary,
                fullWidth: true,
                onPressed: _busy
                    ? null
                    : () => _run(() => widget.onKeepSide(ConflictSide.remote)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCombining(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          messages.conflictCombineStartFrom,
          style: tokens.typography.styles.others.overline.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        _SideToggle(
          selected: _baseSide,
          onChanged: _busy ? null : _setBase,
        ),
        SizedBox(height: tokens.spacing.step4),
        for (final field in _mergeableDiffering) ...[
          Text(
            conflictFieldLabel(field, messages),
            style: tokens.typography.styles.others.overline.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step2),
          _SideToggle(
            selected: _choices[field] ?? _baseSide,
            onChanged: _busy
                ? null
                : (side) => setState(() => _choices[field] = side),
          ),
          SizedBox(height: tokens.spacing.step3),
        ],
        SizedBox(height: tokens.spacing.step2),
        DesignSystemButton(
          label: messages.conflictCombineApply,
          fullWidth: true,
          onPressed: _busy
              ? null
              : () => _run(
                  () => widget.onCombine(
                    baseSide: _baseSide,
                    choices: Map.of(_choices),
                  ),
                ),
        ),
        SizedBox(height: tokens.spacing.step2),
        DesignSystemButton(
          label: MaterialLocalizations.of(context).backButtonTooltip,
          variant: DesignSystemButtonVariant.tertiary,
          fullWidth: true,
          onPressed: _busy
              ? null
              : () => setState(() => _mode = _Mode.choosing),
        ),
      ],
    );
  }

  Widget _buildDeleteVsEdit(BuildContext context, ConflictShape shape) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // The edited side is the one that was NOT soft-deleted.
    final editedSide = shape == ConflictShape.deletedOnLocal
        ? ConflictSide.remote
        : ConflictSide.local;
    final deletedSide = shape == ConflictShape.deletedOnLocal
        ? ConflictSide.local
        : ConflictSide.remote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          messages.conflictDeleteVsEditTitle,
          style: tokens.typography.styles.heading.heading3.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        Text(
          messages.conflictDeleteVsEditDescription,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
        const _RecommendedLabel(),
        SizedBox(height: tokens.spacing.step2),
        DesignSystemButton(
          label: messages.conflictKeepEdited,
          fullWidth: true,
          onPressed: _busy
              ? null
              : () => _run(() => widget.onKeepSide(editedSide)),
        ),
        SizedBox(height: tokens.spacing.step2),
        DesignSystemButton(
          label: messages.conflictConfirmDeletion,
          variant: DesignSystemButtonVariant.dangerSecondary,
          fullWidth: true,
          onPressed: _busy
              ? null
              : () => _run(() => widget.onKeepSide(deletedSide)),
        ),
      ],
    );
  }
}

/// A two-option toggle (this device / from sync) with non-color selected state
/// (a check icon + filled variant), so it reads without relying on hue alone.
class _SideToggle extends StatelessWidget {
  const _SideToggle({required this.selected, required this.onChanged});

  final ConflictSide selected;
  final ValueChanged<ConflictSide>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    Widget option(ConflictSide side, String label) {
      final isSelected = side == selected;
      return Expanded(
        child: DesignSystemButton(
          label: label,
          leadingIcon: isSelected ? Icons.check_rounded : null,
          variant: isSelected
              ? DesignSystemButtonVariant.primary
              : DesignSystemButtonVariant.secondary,
          fullWidth: true,
          onPressed: onChanged == null ? null : () => onChanged!(side),
        ),
      );
    }

    return Row(
      children: [
        option(ConflictSide.local, messages.conflictPickerUseThisDevice),
        SizedBox(width: tokens.spacing.step2),
        option(ConflictSide.remote, messages.conflictPickerUseFromSync),
      ],
    );
  }
}

class _RecommendedLabel extends StatelessWidget {
  const _RecommendedLabel();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.alert.success.defaultColor;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.recommend_rounded,
          size: tokens.spacing.step4,
          color: accent,
        ),
        SizedBox(width: tokens.spacing.step1),
        Text(
          context.messages.conflictDiffRecommended,
          style: tokens.typography.styles.others.caption.copyWith(
            color: accent,
          ),
        ),
      ],
    );
  }
}
