import 'package:flutter/material.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_cards.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_footer.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_shared.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/title_diff.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Diameter of the small status dot rendered inside the count pill.
const double _kCountPillDotSize = 5;

/// Icon sizes for the back chip and the summary banner glyph. The
/// design system has no icon-size token; named here so they're not
/// re-typed at the call sites.
const double _kBackChipIconSize = 20;
const double _kSummaryIconSize = 18;

class LoadingScaffold extends StatelessWidget {
  const LoadingScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.designTokens.colors.background.level01,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class ErrorBody extends StatelessWidget {
  const ErrorBody({required this.error, super.key});

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

class ConflictPickerScaffold extends StatelessWidget {
  const ConflictPickerScaffold({
    required this.conflict,
    required this.local,
    required this.remote,
    required this.selected,
    required this.onSelect,
    required this.onApply,
    required this.onEditMerge,
    super.key,
  });

  final Conflict conflict;
  final JournalEntity local;
  final JournalEntity remote;
  final ConflictSide? selected;
  final ValueChanged<ConflictSide> onSelect;
  final VoidCallback onApply;
  final VoidCallback onEditMerge;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final localTitle = firstLine(local);
    final remoteTitle = firstLine(remote);
    final titleDiff = computeTitleDiff(localTitle, remoteTitle);
    final differingFields = differingFieldLabels(local, remote, messages);

    // The body and the sticky footer must agree on `isStacked` — the
    // body's `LayoutBuilder` sees the panel width while
    // `MediaQuery.sizeOf(context).width` sees the full screen, so on a
    // master/detail tablet they can disagree. Compute once here and
    // pass the result to both surfaces.
    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked = constraints.maxWidth < kConflictStackedBreakpoint;
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
                          entityType: entityTypeLabel(local, messages),
                          createdAt: conflict.createdAt,
                          differingFields: differingFields,
                        ),
                        SizedBox(height: tokens.spacing.step5),
                        CardsLayout(
                          isStacked: isStacked,
                          localCard: DiffCard(
                            side: ConflictSide.local,
                            entity: local,
                            titleSegments: titleDiff.local,
                            isSelected: selected == ConflictSide.local,
                            isStacked: isStacked,
                            onTap: () => onSelect(ConflictSide.local),
                          ),
                          remoteCard: DiffCard(
                            side: ConflictSide.remote,
                            entity: remote,
                            titleSegments: titleDiff.remote,
                            isSelected: selected == ConflictSide.remote,
                            isStacked: isStacked,
                            onTap: () => onSelect(ConflictSide.remote),
                          ),
                        ),
                        SizedBox(height: tokens.spacing.step4),
                        PickerRow(
                          selected: selected,
                          isStacked: isStacked,
                          onSelect: onSelect,
                          onEditMerge: onEditMerge,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: ConflictFooter(
            selected: selected,
            isStacked: isStacked,
            applyEnabled: selected != null,
            onApply: onApply,
            onCancel: settingsBeamerDelegate.beamBack,
            onEditMerge: onEditMerge,
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
    final ago = formatTimeAgo(DateTime.now().difference(createdAt), messages);
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
