part of 'conflict_detail_route.dart';

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
    required this.onEditMerge,
  });

  final Conflict conflict;
  final JournalEntity local;
  final JournalEntity remote;
  final _Side? selected;
  final ValueChanged<_Side> onSelect;
  final VoidCallback onApply;
  final VoidCallback onEditMerge;

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
                          onEditMerge: onEditMerge,
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
