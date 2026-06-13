import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_shared.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/title_diff.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Width of the colored accent stripe pinned to the leading edge of
/// each diff card.
const double _kAccentStripeWidth = 3;

/// Diameter of the small status dot rendered inside each card header.
const double _kCardHeaderDotSize = 6;

/// Picker pill height. Matches the agents-listing toolbar pill height
/// — there's no tappable-row token in the design system yet.
const double _kPickerPillHeight = 36;

class CardsLayout extends StatelessWidget {
  const CardsLayout({
    required this.isStacked,
    required this.localCard,
    required this.remoteCard,
    super.key,
  });

  final bool isStacked;
  final Widget localCard;
  final Widget remoteCard;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    if (isStacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          localCard,
          SizedBox(height: tokens.spacing.step3),
          remoteCard,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: localCard),
        SizedBox(width: tokens.spacing.step5),
        Expanded(child: remoteCard),
      ],
    );
  }
}

class DiffCard extends StatelessWidget {
  const DiffCard({
    required this.side,
    required this.entity,
    required this.titleSegments,
    required this.isSelected,
    required this.isStacked,
    required this.onTap,
    super.key,
  });

  final ConflictSide side;
  final JournalEntity entity;
  final List<TitleDiffSegment> titleSegments;
  final bool isSelected;
  final bool isStacked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final messages = context.messages;
    final accent = side == ConflictSide.local
        ? colors.conflict.local.color
        : colors.conflict.remote.color;
    final selectedTint = side == ConflictSide.local
        ? colors.conflict.local.surface
        : colors.conflict.remote.surface;
    final radius = BorderRadius.circular(tokens.radii.l);
    final eyebrow = side == ConflictSide.local
        ? messages.conflictSideThisDevice
        : messages.conflictSideFromSync;
    final timestamp = formatHmsa(
      entity.meta.dateFrom,
      Localizations.localeOf(context).toString(),
    );
    final vec = maxCounter(entity.meta.vectorClock);
    // Desktop: header timestamp carries `vec N` inline. Mobile: header
    // shows the bare timestamp and the meta row picks up the `vec N`
    // chip — the per-side `local edit / via sync` provenance is desktop
    // only because phone-width rows have no horizontal room for it.
    final timestampLabel = !isStacked && vec > 0
        ? '$timestamp · ${messages.conflictMetaVecPrefix} $vec'
        : timestamp;

    return Semantics(
      key: ValueKey('conflict-card-${side.name}'),
      selected: isSelected,
      label: eyebrow,
      child: Material(
        color: isSelected ? selectedTint : colors.background.level02,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(tokens.spacing.step4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CardHeader(
                      eyebrow: eyebrow,
                      accent: accent,
                      timestampLabel: timestampLabel,
                    ),
                    SizedBox(height: tokens.spacing.step3),
                    _DiffTitle(segments: titleSegments),
                    SizedBox(height: tokens.spacing.step3),
                    _CardMeta(
                      entity: entity,
                      side: side,
                      isStacked: isStacked,
                      vec: vec,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: radius.topLeft,
                    bottomLeft: radius.bottomLeft,
                  ),
                  child: Container(width: _kAccentStripeWidth, color: accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.eyebrow,
    required this.accent,
    required this.timestampLabel,
  });

  final String eyebrow;
  final Color accent;
  final String timestampLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    // spaceBetween + two loose halves: the timestamp stays flush right
    // when there is room and ellipsizes instead of overflowing when the
    // two-up desktop layout sits right at the 768 dp breakpoint (where
    // each column is only ~336 dp wide).
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _kCardHeaderDotSize,
                height: _kCardHeaderDotSize,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              Flexible(
                child: Text(
                  eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.others.overline.copyWith(
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        Flexible(
          child: Text(
            timestampLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: monoMetaStyle(tokens, colors),
          ),
        ),
      ],
    );
  }
}

/// Renders a list of `TitleDiffSegment`s as one inline run. Common
/// segments are plain; added/removed/replaced get tinted backgrounds
/// from the new diff token group, plus line-through on `removed`.
class _DiffTitle extends StatelessWidget {
  const _DiffTitle({required this.segments});

  final List<TitleDiffSegment> segments;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final base = tokens.typography.styles.heading.heading3.copyWith(
      color: colors.text.highEmphasis,
      fontWeight: tokens.typography.weight.semiBold,
    );
    final spans = <InlineSpan>[];
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (i > 0) spans.add(const TextSpan(text: ' '));
      spans.add(_segmentSpan(seg, tokens, base));
    }
    return Text.rich(
      TextSpan(children: spans),
      style: base,
    );
  }

  InlineSpan _segmentSpan(
    TitleDiffSegment seg,
    DsTokens tokens,
    TextStyle base,
  ) {
    final colors = tokens.colors;
    switch (seg.kind) {
      case TitleDiffKind.common:
        return TextSpan(text: seg.text);
      case TitleDiffKind.added:
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _DiffPill(
            text: seg.text,
            background: colors.diff.added.surface,
            foreground: colors.diff.added.color,
            base: base,
          ),
        );
      case TitleDiffKind.removed:
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _DiffPill(
            text: seg.text,
            background: colors.diff.removed.surface,
            foreground: colors.diff.removed.color,
            base: base,
            strikethrough: true,
          ),
        );
      case TitleDiffKind.replaced:
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _DiffPill(
            text: seg.text,
            background: colors.diff.replaced.surface,
            foreground: colors.diff.replaced.color,
            base: base,
          ),
        );
    }
  }
}

class _DiffPill extends StatelessWidget {
  const _DiffPill({
    required this.text,
    required this.background,
    required this.foreground,
    required this.base,
    this.strikethrough = false,
  });

  final String text;
  final Color background;
  final Color foreground;
  final TextStyle base;
  final bool strikethrough;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1 / 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(tokens.radii.xs),
      ),
      child: Text(
        text,
        style: base.copyWith(
          color: foreground,
          decoration: strikethrough ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}

class _CardMeta extends StatelessWidget {
  const _CardMeta({
    required this.entity,
    required this.side,
    required this.isStacked,
    required this.vec,
  });

  final JournalEntity entity;
  final ConflictSide side;
  final bool isStacked;
  final int vec;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final messages = context.messages;
    final caption = tokens.typography.styles.others.caption.copyWith(
      color: colors.text.mediumEmphasis,
    );
    final mono = monoMetaStyle(tokens, colors);
    final children = <Widget>[];
    final categoryId = entity.meta.categoryId;
    if (categoryId != null && categoryId.isNotEmpty) {
      children.add(CategoryIconCompact(categoryId, size: 18));
    }
    final words = wordCount(entity);
    if (words > 0) {
      children.add(Text(messages.conflictWordCount(words), style: caption));
    }
    final duration = audioDuration(entity);
    if (duration != null) {
      children.add(Text(formatDuration(duration), style: caption));
    }
    if (isStacked && vec > 0) {
      children.add(
        Text('${messages.conflictMetaVecPrefix} $vec', style: mono),
      );
    }
    if (!isStacked) {
      children.add(
        Text(
          side == ConflictSide.local
              ? messages.conflictMetaLocalEdit
              : messages.conflictMetaViaSync,
          style: caption,
        ),
      );
    }
    if (children.isEmpty) return const SizedBox.shrink();

    final separated = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        separated.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
            child: Text('·', style: caption),
          ),
        );
      }
      separated.add(children[i]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: separated);
  }
}

class PickerRow extends StatelessWidget {
  const PickerRow({
    required this.selected,
    required this.isStacked,
    required this.onSelect,
    required this.onEditMerge,
    super.key,
  });

  final ConflictSide? selected;
  final bool isStacked;
  final ValueChanged<ConflictSide> onSelect;
  final VoidCallback onEditMerge;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final pills = <Widget>[
      Expanded(
        child: _PickerPill(
          label: messages.conflictPickerUseThisDevice,
          accent: tokens.colors.conflict.local.color,
          tint: tokens.colors.conflict.local.surface,
          isSelected: selected == ConflictSide.local,
          onTap: () => onSelect(ConflictSide.local),
        ),
      ),
      SizedBox(width: tokens.spacing.step3),
      Expanded(
        child: _PickerPill(
          label: messages.conflictPickerUseFromSync,
          accent: tokens.colors.conflict.remote.color,
          tint: tokens.colors.conflict.remote.surface,
          isSelected: selected == ConflictSide.remote,
          onTap: () => onSelect(ConflictSide.remote),
        ),
      ),
      if (!isStacked) ...[
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: _PickerPill(
            label: messages.conflictPickerEditMerge,
            accent: tokens.colors.text.mediumEmphasis,
            tint: tokens.colors.surface.enabled,
            isSelected: false,
            onTap: onEditMerge,
          ),
        ),
      ],
    ];
    return Row(children: pills);
  }
}

class _PickerPill extends StatelessWidget {
  const _PickerPill({
    required this.label,
    required this.accent,
    required this.tint,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final Color tint;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final radius = BorderRadius.circular(tokens.radii.s);
    return Material(
      color: isSelected ? tint : colors.background.level02,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          height: _kPickerPillHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: isSelected ? accent : Colors.transparent,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: isSelected ? accent : colors.text.highEmphasis,
            ),
          ),
        ),
      ),
    );
  }
}
