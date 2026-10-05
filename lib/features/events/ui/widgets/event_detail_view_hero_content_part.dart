part of 'event_detail_view.dart';

class _HeroSliver extends StatelessWidget {
  const _HeroSliver({
    required this.card,
    this.whenLabel,
    this.onBack,
    this.onDelete,
    this.onChangeCover,
    this.onRenameTitle,
    this.onTapCategory,
    this.onTapStatus,
    this.onTapDateTime,
    this.onSetRating,
    this.onAddCover,
  });

  final EventCardData card;
  final String? whenLabel;
  final VoidCallback? onBack;
  final VoidCallback? onDelete;
  final VoidCallback? onChangeCover;
  final ValueChanged<String>? onRenameTitle;
  final VoidCallback? onTapCategory;
  final VoidCallback? onTapStatus;
  final VoidCallback? onTapDateTime;
  final ValueChanged<double>? onSetRating;
  final VoidCallback? onAddCover;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final size = MediaQuery.sizeOf(context);
    // Cap the hero on wide screens so the summary + first timeline beat stay
    // above the fold; phones get a taller, more immersive hero.
    final heroHeight = size.width >= 900
        ? 320.0
        : (size.height * 0.46).clamp(280.0, 420.0);

    return SliverAppBar(
      expandedHeight: heroHeight,
      pinned: true,
      backgroundColor: dsPageSurface(context),
      leading: _ScrimIconButton(icon: LottiIcons.back, onPressed: onBack),
      actions: [
        if (onDelete != null || onChangeCover != null)
          _HeroMenuButton(onDelete: onDelete, onChangeCover: onChangeCover),
        SizedBox(width: tokens.spacing.step2),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: EventCoverImage(
          image: card.coverImage,
          fallbackColor: card.categoryColor,
          cropX: card.coverCropX,
          scrim: EventCoverScrim.hero,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.step5),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: _HeroContent(
                  card: card,
                  whenLabel: whenLabel,
                  onRenameTitle: onRenameTitle,
                  onTapCategory: onTapCategory,
                  onTapStatus: onTapStatus,
                  onTapDateTime: onTapDateTime,
                  onSetRating: onSetRating,
                  onAddCover: onAddCover,
                  onChangeCover: onChangeCover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent({
    required this.card,
    this.whenLabel,
    this.onRenameTitle,
    this.onTapCategory,
    this.onTapStatus,
    this.onTapDateTime,
    this.onSetRating,
    this.onAddCover,
    this.onChangeCover,
  });

  final EventCardData card;
  final String? whenLabel;
  final ValueChanged<String>? onRenameTitle;
  final VoidCallback? onTapCategory;
  final VoidCallback? onTapStatus;
  final VoidCallback? onTapDateTime;
  final ValueChanged<double>? onSetRating;
  final VoidCallback? onAddCover;
  final VoidCallback? onChangeCover;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final styles = tokens.typography.styles;
    // display2 is too large for a phone width and truncates long titles; step
    // down to heading1 on narrow screens so the full title always fits.
    final titleStyle = MediaQuery.sizeOf(context).width < 600
        ? styles.heading.heading1
        : styles.display.display2;
    final fade = Colors.white.withValues(alpha: 0.85);
    // The hero carries the single, authoritative date/time (the body no longer
    // repeats it). A rating only makes sense once an event has happened, so a
    // fresh/tentative one isn't pushed gold stars.
    final dateText = whenLabel ?? card.dateLabel;
    final showRating = card.status == EventStatus.completed || card.stars > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // One slot for the cover affordance: add a photo while there is none,
        // or pick one while the photo behind this hero is only the newest —
        // the default that would move with the next photo added.
        if (card.coverImage == null && onAddCover != null) ...[
          _CoverActionButton(
            icon: LottiIcons.addPhoto,
            label: context.messages.eventsAddCoverPhoto,
            onTap: onAddCover!,
          ),
          SizedBox(height: tokens.spacing.step3),
        ] else if (card.coverImage != null &&
            !card.coverChosen &&
            onChangeCover != null) ...[
          _CoverActionButton(
            icon: LottiIcons.image,
            label: context.messages.coverArtChipSet,
            onTap: onChangeCover!,
          ),
          SizedBox(height: tokens.spacing.step3),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (card.categoryName != null) ...[
              _TappablePill(
                onTap: onTapCategory,
                child: EventOverlayPill(
                  dotColor: card.categoryColor,
                  label: card.categoryName!,
                ),
              ),
              SizedBox(width: tokens.spacing.step2),
            ] else if (onTapCategory != null) ...[
              // No category yet, but editable: a clearly-additive placeholder.
              _SetChip(
                label: context.messages.habitCategoryLabel,
                onTap: onTapCategory,
              ),
              SizedBox(width: tokens.spacing.step2),
            ],
            // Status is always shown (and tappable) since it's the core
            // editable state of an event.
            _TappablePill(
              onTap: onTapStatus,
              child: EventOverlayPill(
                dotColor: card.status.color,
                label: eventStatusLabel(context, card.status),
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.step3),
        _EditableTitle(
          title: card.title,
          style: titleStyle,
          onRename: onRenameTitle,
        ),
        SizedBox(height: tokens.spacing.step3),
        _TappablePill(
          onTap: onTapDateTime,
          child: Row(
            children: [
              Icon(LottiIcons.calendar, size: 15, color: fade),
              SizedBox(width: tokens.spacing.step1),
              Flexible(
                child: Text(
                  dateText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: styles.body.bodyMedium.copyWith(color: fade),
                ),
              ),
              if (onTapDateTime != null) ...[
                SizedBox(width: tokens.spacing.step2),
                Icon(
                  LottiIcons.edit,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ],
            ],
          ),
        ),
        if (showRating) ...[
          SizedBox(height: tokens.spacing.step3),
          StarRating(
            rating: card.stars,
            size: 22,
            allowHalfRating: true,
            color: starredGold,
            borderColor: starredGold,
            onRatingChanged: onSetRating == null
                ? null
                : (rating) => onSetRating!(rating),
          ),
        ],
      ],
    );
  }
}

/// A labelled ghost button over the hero inviting a cover photo, shown while the
/// The hero's one cover affordance, in the "Add cover photo" pill's shape:
/// a glyph and a word on a dark pill, over the photo or the tinted gradient.
/// Which action it carries follows the cover's state (none / default).
class _CoverActionButton extends StatelessWidget {
  const _CoverActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step3,
            vertical: tokens.spacing.step2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              SizedBox(width: tokens.spacing.step2),
              Text(
                label,
                style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An additive "set X" placeholder chip for the hero (e.g. set a category),
/// visually distinct from a populated [EventOverlayPill] via its `+` glyph.
class _SetChip extends StatelessWidget {
  const _SetChip({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Material(
      color: Colors.black.withValues(alpha: 0.30),
      borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step2,
            vertical: tokens.spacing.step1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LottiIcons.add,
                size: 13,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              SizedBox(width: tokens.spacing.step1),
              Text(
                label,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps a hero pill so it taps through to a picker when [onTap] is wired,
/// staying inert (read-only) otherwise.
class _TappablePill extends StatelessWidget {
  const _TappablePill({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}

/// Tap-to-rename title rendered over the hero. Read-only when [onRename] is
/// null; otherwise a tap swaps in a borderless field that commits on submit or
/// when focus leaves.
class _EditableTitle extends StatefulWidget {
  const _EditableTitle({
    required this.title,
    required this.style,
    this.onRename,
  });

  final String title;
  final TextStyle style;
  final ValueChanged<String>? onRename;

  @override
  State<_EditableTitle> createState() => _EditableTitleState();
}

class _EditableTitleState extends State<_EditableTitle> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.title,
  );
  final FocusNode _focusNode = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _EditableTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.title != widget.title) {
      _controller.text = widget.title;
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _editing) _commit();
  }

  void _startEditing() {
    if (widget.onRename == null) return;
    _controller
      ..text = widget.title
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.title.length,
      );
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  void _commit() {
    final text = _controller.text.trim();
    setState(() => _editing = false);
    if (text.isNotEmpty && text != widget.title) widget.onRename?.call(text);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
    );

    if (_editing) {
      return TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLines: 2,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _commit(),
        style: style,
        cursorColor: Colors.white,
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      );
    }

    return GestureDetector(
      onTap: _startEditing,
      behavior: HitTestBehavior.opaque,
      child: Text(
        widget.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

class _ScrimIconButton extends StatelessWidget {
  const _ScrimIconButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.designTokens.spacing.step2),
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          icon: Icon(icon, color: Colors.white),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// Overflow menu over the hero. Currently a single destructive action; more
/// (share, change cover) slot in here as they land.
class _HeroMenuButton extends StatelessWidget {
  const _HeroMenuButton({this.onDelete, this.onChangeCover});

  final VoidCallback? onDelete;
  final VoidCallback? onChangeCover;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final spacing = context.designTokens.spacing.step2;
    return Padding(
      padding: EdgeInsets.all(spacing),
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: PopupMenuButton<String>(
          icon: const Icon(LottiIcons.more, color: Colors.white),
          onSelected: (value) {
            if (value == 'change_cover') onChangeCover?.call();
            if (value == 'delete') onDelete?.call();
          },
          itemBuilder: (context) => [
            if (onChangeCover != null)
              PopupMenuItem<String>(
                value: 'change_cover',
                child: Row(
                  children: [
                    Icon(
                      LottiIcons.image,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    SizedBox(width: spacing),
                    Text(context.messages.eventsChangeCover),
                  ],
                ),
              ),
            if (onDelete != null)
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(LottiIcons.delete, size: 18, color: cs.error),
                    SizedBox(width: spacing),
                    Text(context.messages.eventsDeleteEvent),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, this.onRegenerate});

  final String summary;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    final styles = tokens.typography.styles;

    return ModernBaseCard(
      isEnhanced: true,
      padding: EdgeInsets.all(tokens.spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LottiIcons.aiSpark, size: 16, color: cs.primary),
              SizedBox(width: tokens.spacing.step2),
              Text(
                context.messages.eventsSummaryTitle,
                style: styles.subtitle.subtitle2.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onRegenerate,
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                color: cs.onSurfaceVariant,
                tooltip: context.messages.eventsRegenerateSummary,
                icon: const Icon(LottiIcons.refresh),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step2),
          Text(
            summary,
            style: styles.body.bodyLarge.copyWith(color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        top: tokens.spacing.step6,
        bottom: tokens.spacing.step3,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: tokens.typography.styles.heading.heading3.copyWith(
              color: cs.onSurface,
            ),
          ),
          SizedBox(width: tokens.spacing.step2),
          Text(
            '$count',
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: cs.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quiet placeholder under the Timeline header while nothing is linked yet.
/// It names what the action bar along the bottom edge adds — photos, notes,
/// a voice memo — so a fresh event reads as an invitation rather than a blank
/// gap, without being a second add button competing with that bar.
class _EmptyTimelineHint extends StatelessWidget {
  const _EmptyTimelineHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    // Full width, like the summary card above it, rather than a pill hugging
    // its sentence.
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: dsCardSurface(context),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step4),
          child: Text(
            label,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, this.onOpen});

  final EventTaskRef task;

  /// Opens the task's detail page (receives the task id).
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    final styles = tokens.typography.styles;

    // Only interactive — and only carrying the "open" chevron — when there's a
    // task id and a handler to open it.
    final taskId = task.id;
    final canOpen = onOpen != null && taskId != null;

    final row = Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
      child: Row(
        children: [
          Icon(
            task.done ? LottiIcons.confirmCircled : LottiIcons.radioUnselected,
            size: 20,
            color: task.done ? cs.primary : cs.outline,
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Text(
              task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: styles.body.bodyLarge.copyWith(
                color: task.done ? cs.onSurfaceVariant : cs.onSurface,
              ),
            ),
          ),
          if (task.dueLabel != null) ...[
            SizedBox(width: tokens.spacing.step2),
            Text(
              task.dueLabel!,
              style: styles.body.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
          if (task.statusLabel != null) ...[
            SizedBox(width: tokens.spacing.step2),
            Text(
              task.statusLabel!,
              style: styles.others.caption.copyWith(
                color: task.statusColor ?? cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (canOpen) ...[
            SizedBox(width: tokens.spacing.step2),
            Icon(LottiIcons.chevronRight, size: 20, color: cs.outline),
          ],
        ],
      ),
    );

    if (!canOpen) return row;
    return InkWell(
      onTap: () => onOpen!(taskId),
      borderRadius: BorderRadius.circular(tokens.radii.s),
      child: row,
    );
  }
}
