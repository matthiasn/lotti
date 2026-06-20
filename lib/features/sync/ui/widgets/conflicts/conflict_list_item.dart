import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/sync/ui/view_models/conflict_list_item_view_model.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

const _compactBreakpoint = 600.0;

class ConflictListItem extends StatelessWidget {
  const ConflictListItem({
    required this.conflict,
    this.onTap,
    super.key,
  });

  final Conflict conflict;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final viewModel = ConflictListItemViewModel.fromConflict(
      context: context,
      conflict: conflict,
    );
    final tokens = context.designTokens;
    final colors = tokens.colors;

    final radius = BorderRadius.circular(tokens.radii.m);
    return Semantics(
      button: onTap != null,
      label: viewModel.semanticsLabel,
      // A `level02` fill with a `decorative.level01` hairline (the shared
      // design-system card treatment, e.g. the dashboard chart cards) lifts
      // each conflict off the near-black `level01` scaffold. Without the
      // border the row's fill is almost indistinguishable from the background
      // in dark mode, so the list read as one flat, almost-black sheet. The
      // border rides on the Material's shape so the ink splash clips to it.
      child: Material(
        color: colors.background.level02,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colors.decorative.level01),
        ),
        child: InkWell(
          hoverColor: colors.surface.hover,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step4,
              vertical: tokens.spacing.step3,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < _compactBreakpoint;
                return isCompact
                    ? _CompactLayout(
                        viewModel: viewModel,
                        hasTap: onTap != null,
                      )
                    : _WideLayout(viewModel: viewModel, hasTap: onTap != null);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.viewModel, required this.hasTap});

  final ConflictListItemViewModel viewModel;
  final bool hasTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    return Row(
      children: [
        _StatusBadge(tone: viewModel.statusTone, label: viewModel.statusLabel),
        SizedBox(width: tokens.spacing.step3),
        DesignSystemBadge.filled(
          label: viewModel.entityLabel,
          tone: DesignSystemBadgeTone.secondary,
        ),
        SizedBox(width: tokens.spacing.step4),
        Expanded(
          child: Text(
            viewModel.timestampLabel,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: colors.text.highEmphasis,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        _ConflictIdMeta(viewModel: viewModel),
        if (hasTap) ...[
          SizedBox(width: tokens.spacing.step3),
          Icon(Icons.chevron_right, size: 16, color: colors.text.lowEmphasis),
        ],
      ],
    );
  }
}

class _CompactLayout extends StatelessWidget {
  const _CompactLayout({required this.viewModel, required this.hasTap});

  final ConflictListItemViewModel viewModel;
  final bool hasTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                viewModel.timestampLabel,
                style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                  color: colors.text.highEmphasis,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _ConflictIdMeta(viewModel: viewModel),
          ],
        ),
        SizedBox(height: tokens.spacing.step3),
        Row(
          children: [
            _StatusBadge(
              tone: viewModel.statusTone,
              label: viewModel.statusLabel,
            ),
            SizedBox(width: tokens.spacing.step3),
            DesignSystemBadge.filled(
              label: viewModel.entityLabel,
              tone: DesignSystemBadgeTone.secondary,
            ),
            const Spacer(),
            if (hasTap)
              Icon(
                Icons.chevron_right,
                size: 16,
                color: colors.text.lowEmphasis,
              ),
          ],
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.tone, required this.label});

  final ConflictStatusTone tone;
  final String label;

  @override
  Widget build(BuildContext context) {
    final badgeTone = switch (tone) {
      ConflictStatusTone.resolved => DesignSystemBadgeTone.success,
      ConflictStatusTone.unresolved => DesignSystemBadgeTone.danger,
    };
    return DesignSystemBadge.filled(label: label, tone: badgeTone);
  }
}

class _ConflictIdMeta extends StatelessWidget {
  const _ConflictIdMeta({required this.viewModel});

  final ConflictListItemViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    return Tooltip(
      message: context.messages.conflictListItemTooltipFullId(
        viewModel.conflictIdFull,
      ),
      child: Text(
        viewModel.conflictIdShort,
        style: monoMetaStyle(tokens, colors),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
