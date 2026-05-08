import 'package:flutter/material.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/title_diff.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/nav_service.dart';

/// Stacked vs side-by-side breakpoint for the diff cards. Below this,
/// the picker collapses to a single column and the header pill drops
/// the "fields differ" half.
const double _kStackedBreakpoint = 768;

/// Width of the colored accent stripe pinned to the leading edge of
/// each diff card.
const double _kAccentStripeWidth = 3;

/// Diameter of the small status dot rendered inside the count pill and
/// each card header. No matching design-system token; consolidated here
/// so the two call sites stay in sync.
const double _kCountPillDotSize = 5;
const double _kCardHeaderDotSize = 6;

/// Icon sizes for the back chip and the summary banner glyph. The
/// design system has no icon-size token; named here so they're not
/// re-typed at the call sites.
const double _kBackChipIconSize = 20;
const double _kSummaryIconSize = 18;

/// Picker pill height. Matches the agents-listing toolbar pill height
/// — there's no tappable-row token in the design system yet.
const double _kPickerPillHeight = 36;

enum _Side { local, remote }

/// Conflict picker page with inline word-level diffs between the local
/// and remote versions of an entry. The user picks a side (or opens
/// Edit & merge) and confirms via Apply in the sticky footer.
class ConflictDetailRoute extends StatefulWidget {
  const ConflictDetailRoute({required this.conflictId, super.key});

  final String conflictId;

  @override
  State<ConflictDetailRoute> createState() => _ConflictDetailRouteState();
}

class _ConflictDetailRouteState extends State<ConflictDetailRoute> {
  _Side? _selected;
  Future<JournalEntity?>? _localEntryFuture;
  String? _futureKey;

  /// Cache the local-entry lookup keyed by conflict id so the
  /// `FutureBuilder` doesn't re-issue the DB read on every stream tick
  /// (which would also flash a transient null snapshot through the UI).
  Future<JournalEntity?> _localEntryFor(String conflictId) {
    if (_futureKey != conflictId || _localEntryFuture == null) {
      _futureKey = conflictId;
      _localEntryFuture = getIt<JournalDb>().journalEntityById(conflictId);
    }
    return _localEntryFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final db = getIt<JournalDb>();
    return StreamBuilder<List<Conflict>>(
      stream: db.watchConflictById(widget.conflictId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyScaffoldWithTitle(
            context.messages.conflictDetailLoadErrorTitle,
            body: _ErrorBody(error: snapshot.error),
          );
        }
        final data = snapshot.data ?? const <Conflict>[];
        if (data.isEmpty) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingScaffold();
          }
          return EmptyScaffoldWithTitle(
            context.messages.conflictDetailNotFoundTitle,
          );
        }
        final conflict = data.first;
        final remote = fromSerialized(conflict.serialized);
        return FutureBuilder<JournalEntity?>(
          future: _localEntryFor(conflict.id),
          builder: (context, entrySnapshot) {
            if (entrySnapshot.hasError) {
              return EmptyScaffoldWithTitle(
                context.messages.conflictDetailLoadErrorTitle,
                body: _ErrorBody(error: entrySnapshot.error),
              );
            }
            if (entrySnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScaffold();
            }
            final local = entrySnapshot.data;
            if (local == null) {
              return EmptyScaffoldWithTitle(
                context.messages.conflictDetailEntryNotFoundTitle,
              );
            }
            final mergedClock = VectorClock.merge(
              local.meta.vectorClock,
              remote.meta.vectorClock,
            );
            // Each side keeps its own metadata; only the vector clock is
            // merged so whichever side the user picks lands with the
            // unified clock. Building the remote side from `local.meta`
            // (the previous behavior) discarded any remote-only meta
            // changes such as a different category id.
            final localResolved = local.copyWith(
              meta: local.meta.copyWith(vectorClock: mergedClock),
            );
            final remoteResolved = remote.copyWith(
              meta: remote.meta.copyWith(vectorClock: mergedClock),
            );
            return _ConflictPickerScaffold(
              conflict: conflict,
              local: localResolved,
              remote: remoteResolved,
              selected: _selected,
              onSelect: (side) => setState(() => _selected = side),
              onApply: () => _apply(localResolved, remoteResolved),
            );
          },
        );
      },
    );
  }

  void _apply(JournalEntity local, JournalEntity remote) {
    final winner = switch (_selected) {
      _Side.local => local,
      _Side.remote => remote,
      null => null,
    };
    if (winner == null) return;
    getIt<PersistenceLogic>().updateJournalEntity(winner, winner.meta);
    settingsBeamerDelegate.beamBack();
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.designTokens.colors.background.level01,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step5),
      child: Text(
        '$error',
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
    );
  }
}

class _ConflictPickerScaffold extends StatelessWidget {
  const _ConflictPickerScaffold({
    required this.conflict,
    required this.local,
    required this.remote,
    required this.selected,
    required this.onSelect,
    required this.onApply,
  });

  final Conflict conflict;
  final JournalEntity local;
  final JournalEntity remote;
  final _Side? selected;
  final ValueChanged<_Side> onSelect;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final localTitle = _firstLine(local);
    final remoteTitle = _firstLine(remote);
    final titleDiff = computeTitleDiff(localTitle, remoteTitle);
    final differingFields = _differingFieldLabels(local, remote, messages);

    // The body and the sticky footer must agree on `isStacked` — the
    // body's `LayoutBuilder` sees the panel width while
    // `MediaQuery.sizeOf(context).width` sees the full screen, so on a
    // master/detail tablet they can disagree. Compute once here and
    // pass the result to both surfaces.
    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked = constraints.maxWidth < _kStackedBreakpoint;
        return Scaffold(
          backgroundColor: tokens.colors.background.level01,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _HeaderBar(
                  isStacked: isStacked,
                  fieldsCount: differingFields.length,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.step5,
                      vertical: tokens.spacing.step3,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LeadCopy(isStacked: isStacked),
                        SizedBox(height: tokens.spacing.step4),
                        _SummaryBanner(
                          entityType: _entityTypeLabel(local, messages),
                          createdAt: conflict.createdAt,
                          differingFields: differingFields,
                        ),
                        SizedBox(height: tokens.spacing.step5),
                        _CardsLayout(
                          isStacked: isStacked,
                          localCard: _DiffCard(
                            side: _Side.local,
                            entity: local,
                            titleSegments: titleDiff.local,
                            isSelected: selected == _Side.local,
                            isStacked: isStacked,
                            onTap: () => onSelect(_Side.local),
                          ),
                          remoteCard: _DiffCard(
                            side: _Side.remote,
                            entity: remote,
                            titleSegments: titleDiff.remote,
                            isSelected: selected == _Side.remote,
                            isStacked: isStacked,
                            onTap: () => onSelect(_Side.remote),
                          ),
                        ),
                        SizedBox(height: tokens.spacing.step4),
                        _PickerRow(
                          selected: selected,
                          isStacked: isStacked,
                          onSelect: onSelect,
                          onEditMerge: () => beamToNamed(
                            '/settings/advanced/conflicts/${conflict.id}/edit',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _ConflictFooter(
            selected: selected,
            isStacked: isStacked,
            applyEnabled: selected != null,
            onApply: onApply,
            onCancel: settingsBeamerDelegate.beamBack,
            onEditMerge: () => beamToNamed(
              '/settings/advanced/conflicts/${conflict.id}/edit',
            ),
          ),
        );
      },
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.isStacked, required this.fieldsCount});

  final bool isStacked;
  final int fieldsCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final messages = context.messages;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step4,
        tokens.spacing.step5,
        tokens.spacing.step3,
      ),
      child: Row(
        children: [
          const _BackChip(),
          SizedBox(width: tokens.spacing.step4),
          Expanded(
            child: Text(
              messages.conflictPageTitle,
              style:
                  (isStacked
                          ? tokens.typography.styles.subtitle.subtitle1
                          : tokens.typography.styles.heading.heading3)
                      .copyWith(color: colors.text.highEmphasis),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _CountPill(
            isStacked: isStacked,
            entries: 1,
            fieldsCount: fieldsCount,
          ),
        ],
      ),
    );
  }
}

class _BackChip extends StatelessWidget {
  const _BackChip();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    return Material(
      color: colors.surface.enabled,
      borderRadius: BorderRadius.circular(tokens.radii.s),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.s),
        onTap: settingsBeamerDelegate.beamBack,
        child: SizedBox(
          width: tokens.spacing.step7,
          height: tokens.spacing.step7,
          child: Icon(
            Icons.chevron_left_rounded,
            size: _kBackChipIconSize,
            color: colors.text.highEmphasis,
          ),
        ),
      ),
    );
  }
}

/// Amber pill in the header. Mobile shows just a count digit (with a
/// dot); desktop adds a "· N fields differ" suffix.
class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.isStacked,
    required this.entries,
    required this.fieldsCount,
  });

  final bool isStacked;
  final int entries;
  final int fieldsCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final amber = colors.conflict.diverged.color;
    final messages = context.messages;
    final label = isStacked
        ? '$entries'
        : (fieldsCount > 0
              ? '${messages.conflictHeaderPillEntries(entries)} · ${messages.conflictHeaderPillFieldsDiffer(fieldsCount)}'
              : messages.conflictHeaderPillEntries(entries));
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: colors.conflict.diverged.surface,
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        border: Border.all(color: amber.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _kCountPillDotSize,
            height: _kCountPillDotSize,
            decoration: BoxDecoration(color: amber, shape: BoxShape.circle),
          ),
          SizedBox(width: tokens.spacing.step3),
          Text(
            label,
            style: tokens.typography.styles.others.overline.copyWith(
              color: amber,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadCopy extends StatelessWidget {
  const _LeadCopy({required this.isStacked});

  final bool isStacked;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Text(
      isStacked
          ? messages.conflictPageLeadMobile
          : messages.conflictPageLeadDesktop,
      style: tokens.typography.styles.body.bodySmall.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({
    required this.entityType,
    required this.createdAt,
    required this.differingFields,
  });

  final String entityType;
  final DateTime createdAt;
  final List<String> differingFields;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final amber = colors.conflict.diverged.color;
    final messages = context.messages;
    final ago = _formatTimeAgo(DateTime.now().difference(createdAt), messages);
    final line1 = messages.conflictBannerDivergedAgo(entityType, ago);
    final subline = differingFields.isEmpty
        ? null
        : messages.conflictBannerFieldsDifferList(differingFields.join(' · '));
    return Container(
      padding: EdgeInsets.all(tokens.spacing.step4),
      decoration: BoxDecoration(
        color: colors.conflict.diverged.surface,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: amber.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: tokens.spacing.step7,
            height: tokens.spacing.step7,
            decoration: BoxDecoration(
              color: amber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(tokens.radii.s),
            ),
            child: Icon(
              Icons.swap_horiz_rounded,
              size: _kSummaryIconSize,
              color: amber,
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line1,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: colors.text.highEmphasis,
                  ),
                ),
                if (subline != null) ...[
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    subline,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: colors.text.mediumEmphasis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardsLayout extends StatelessWidget {
  const _CardsLayout({
    required this.isStacked,
    required this.localCard,
    required this.remoteCard,
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

class _DiffCard extends StatelessWidget {
  const _DiffCard({
    required this.side,
    required this.entity,
    required this.titleSegments,
    required this.isSelected,
    required this.isStacked,
    required this.onTap,
  });

  final _Side side;
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
    final accent = side == _Side.local
        ? colors.conflict.local.color
        : colors.conflict.remote.color;
    final selectedTint = side == _Side.local
        ? colors.conflict.local.surface
        : colors.conflict.remote.surface;
    final radius = BorderRadius.circular(tokens.radii.l);
    final eyebrow = side == _Side.local
        ? messages.conflictSideThisDevice
        : messages.conflictSideFromSync;
    final timestamp = _formatHmsa(entity.meta.dateFrom);
    final vec = _maxCounter(entity.meta.vectorClock);
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
    return Row(
      children: [
        Container(
          width: _kCardHeaderDotSize,
          height: _kCardHeaderDotSize,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Text(
            eyebrow,
            style: tokens.typography.styles.others.overline.copyWith(
              color: accent,
            ),
          ),
        ),
        Text(timestampLabel, style: monoMetaStyle(tokens, colors)),
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
  final _Side side;
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
    final words = _wordCount(entity);
    if (words > 0) {
      children.add(Text(messages.conflictWordCount(words), style: caption));
    }
    final duration = _audioDuration(entity);
    if (duration != null) {
      children.add(Text(_formatDuration(duration), style: caption));
    }
    if (isStacked && vec > 0) {
      children.add(
        Text('${messages.conflictMetaVecPrefix} $vec', style: mono),
      );
    }
    if (!isStacked) {
      children.add(
        Text(
          side == _Side.local
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

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.selected,
    required this.isStacked,
    required this.onSelect,
    required this.onEditMerge,
  });

  final _Side? selected;
  final bool isStacked;
  final ValueChanged<_Side> onSelect;
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
          isSelected: selected == _Side.local,
          onTap: () => onSelect(_Side.local),
        ),
      ),
      SizedBox(width: tokens.spacing.step3),
      Expanded(
        child: _PickerPill(
          label: messages.conflictPickerUseFromSync,
          accent: tokens.colors.conflict.remote.color,
          tint: tokens.colors.conflict.remote.surface,
          isSelected: selected == _Side.remote,
          onTap: () => onSelect(_Side.remote),
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

class _ConflictFooter extends StatelessWidget {
  const _ConflictFooter({
    required this.selected,
    required this.isStacked,
    required this.applyEnabled,
    required this.onApply,
    required this.onCancel,
    required this.onEditMerge,
  });

  final _Side? selected;
  final bool isStacked;
  final bool applyEnabled;
  final VoidCallback onApply;
  final VoidCallback onCancel;
  final VoidCallback onEditMerge;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final messages = context.messages;
    final helperColor = switch (selected) {
      _Side.local => colors.conflict.local.color,
      _Side.remote => colors.conflict.remote.color,
      null => colors.text.lowEmphasis,
    };
    final helperText = switch (selected) {
      _Side.local => messages.conflictFooterHelperLocalSelected,
      _Side.remote => messages.conflictFooterHelperRemoteSelected,
      null => messages.conflictFooterHelperPickASide,
    };
    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step5,
          vertical: tokens.spacing.step3,
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // Left slot is `Expanded` on both layouts so the buttons
              // own their intrinsic widths on the right and the helper
              // text / Edit-and-merge link absorbs the leftover width
              // (and ellipsizes on phone-width screens).
              Expanded(
                child: isStacked
                    ? _FooterEditMergeLink(onTap: onEditMerge)
                    : Text(
                        helperText,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: helperColor,
                        ),
                      ),
              ),
              SizedBox(width: tokens.spacing.step3),
              DesignSystemButton(
                label: messages.cancelButton,
                variant: DesignSystemButtonVariant.secondary,
                size: DesignSystemButtonSize.large,
                onPressed: onCancel,
              ),
              SizedBox(width: tokens.spacing.step3),
              DesignSystemButton(
                label: messages.conflictApplyButton,
                size: DesignSystemButtonSize.large,
                onPressed: applyEnabled ? onApply : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterEditMergeLink extends StatelessWidget {
  const _FooterEditMergeLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
        child: Text(
          context.messages.conflictPickerEditMerge,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
      ),
    );
  }
}

// --- Pure helpers (no Flutter context) -------------------------------------

String _firstLine(JournalEntity entity) {
  final text = entity.entryText?.plainText.trim();
  if (text != null && text.isNotEmpty) return text.split('\n').first;
  return entity.runtimeType.toString();
}

int _wordCount(JournalEntity entity) {
  final text = entity.entryText?.plainText.trim();
  if (text == null || text.isEmpty) return 0;
  return text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).length;
}

Duration? _audioDuration(JournalEntity entity) {
  return switch (entity) {
    JournalAudio(:final data) => data.duration,
    _ => null,
  };
}

int _maxCounter(VectorClock? clock) {
  if (clock == null || clock.vclock.isEmpty) return 0;
  return clock.vclock.values.reduce((a, b) => a > b ? a : b);
}

String _formatHmsa(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
}

String _formatDuration(Duration duration) {
  final total = duration.inSeconds.abs();
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:${two(minutes)}:${two(seconds)}';
  return '$minutes:${two(seconds)}';
}

String _formatTimeAgo(Duration delta, AppLocalizations messages) {
  if (delta.inSeconds < 60) return messages.conflictBannerAgoJustNow;
  if (delta.inMinutes < 60) {
    return messages.conflictBannerAgoMinutes(delta.inMinutes);
  }
  if (delta.inHours < 48) {
    return messages.conflictBannerAgoHours(delta.inHours);
  }
  return messages.conflictBannerAgoDays(delta.inDays);
}

/// Maps the freezed sealed-type to a localized human label. Mirrors
/// the mapping used by the conflicts list view-model; pattern-matches
/// on the entity itself so the analyzer's `switch_on_type` lint stays
/// happy and a new entity type triggers a missing-case warning.
String _entityTypeLabel(JournalEntity entity, AppLocalizations messages) {
  return switch (entity) {
    Task() => messages.entryTypeLabelTask,
    JournalEntry() => messages.entryTypeLabelJournalEntry,
    JournalEvent() => messages.entryTypeLabelJournalEvent,
    JournalAudio() => messages.entryTypeLabelJournalAudio,
    JournalImage() => messages.entryTypeLabelJournalImage,
    MeasurementEntry() => messages.entryTypeLabelMeasurementEntry,
    SurveyEntry() => messages.entryTypeLabelSurveyEntry,
    WorkoutEntry() => messages.entryTypeLabelWorkoutEntry,
    HabitCompletionEntry() => messages.entryTypeLabelHabitCompletionEntry,
    QuantitativeEntry() => messages.entryTypeLabelQuantitativeEntry,
    Checklist() => messages.entryTypeLabelChecklist,
    ChecklistItem() => messages.entryTypeLabelChecklistItem,
    _ => entity.runtimeType.toString(),
  };
}

/// Walks a fixed set of metadata fields and returns a list of
/// localized labels for the ones that differ between the two sides.
/// "Title" is always added when titles differ — it's what the inline
/// diff in the cards is showing — so the banner subline reinforces it.
List<String> _differingFieldLabels(
  JournalEntity local,
  JournalEntity remote,
  AppLocalizations messages,
) {
  final fields = <String>[];
  if (_firstLine(local) != _firstLine(remote)) {
    fields.add(messages.conflictFieldTitle);
  }
  if (_wordCount(local) != _wordCount(remote)) {
    fields.add(messages.conflictFieldWordCount);
  }
  if (_audioDuration(local) != _audioDuration(remote)) {
    fields.add(messages.conflictFieldDuration);
  }
  if (local.meta.categoryId != remote.meta.categoryId) {
    fields.add(messages.conflictFieldCategory);
  }
  return fields;
}
