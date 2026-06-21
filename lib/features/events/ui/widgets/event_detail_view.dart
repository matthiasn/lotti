import 'package:flutter/material.dart';
import 'package:flutter_rating/flutter_rating.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_cover_image.dart';
import 'package:lotti/features/events/ui/widgets/event_overlay_pill.dart';
import 'package:lotti/features/events/ui/widgets/event_photo_gallery.dart';
import 'package:lotti/features/events/ui/widgets/event_status_picker.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';

/// The redesigned event detail surface: a photographic hero header carrying the
/// event's identity (cover, title, when/where, status, rating), followed by an
/// AI summary, a vertical timeline of linked entries, and the associated
/// prep/follow-up tasks. On wide screens the body splits into a main column
/// (summary + timeline) and a tasks rail; on phones it stacks.
///
/// Editing happens inline: the title is tap-to-rename, the category/status pills
/// and the rating open pickers, and each section can add linked entries — so the
/// page never bounces to a separate editor. The empty event still shows its
/// section scaffolding with "add" affordances rather than a blank void. All
/// mutations are surfaced as callbacks; with none wired the view is read-only.
class EventDetailView extends StatelessWidget {
  const EventDetailView({
    required this.data,
    this.onBack,
    this.onRenameTitle,
    this.onTapCategory,
    this.onTapStatus,
    this.onTapDateTime,
    this.onSetRating,
    this.onAddCover,
    this.onChangeCover,
    this.onDelete,
    this.onRegenerateSummary,
    this.onAddToTimeline,
    this.onAddTask,
    this.onOpenTimelineEntry,
    this.onOpenTask,
    super.key,
  });

  final EventDetailData data;
  final VoidCallback? onBack;

  /// Inline rename — receives the new (trimmed-by-caller) title.
  final ValueChanged<String>? onRenameTitle;

  /// Opens the category / status / date-time pickers. The rating is set
  /// directly.
  final VoidCallback? onTapCategory;
  final VoidCallback? onTapStatus;
  final VoidCallback? onTapDateTime;
  final ValueChanged<double>? onSetRating;

  /// Adds a cover photo (shown only while the event has no cover).
  final VoidCallback? onAddCover;

  /// Changes the cover photo (offered in the overflow menu once the event has
  /// one), e.g. picking a different linked photo or adding a new one.
  final VoidCallback? onChangeCover;

  /// Deletes the event (offered in the overflow menu).
  final VoidCallback? onDelete;

  final VoidCallback? onRegenerateSummary;
  final VoidCallback? onAddToTimeline;
  final VoidCallback? onAddTask;

  /// Opens a timeline beat's source journal entry. When null, the rows render
  /// as static (and drop the trailing "open" chevron) so the affordance always
  /// matches the actual behavior.
  final ValueChanged<String>? onOpenTimelineEntry;

  /// Opens a linked task's detail page (receives the task id). When null (or a
  /// row has no id) the task rows render as static.
  final ValueChanged<String>? onOpenTask;

  /// Content cap so the body doesn't sprawl on very wide screens.
  static const double _contentMaxWidth = 1080;

  /// At/above this body width the layout splits into two columns.
  static const double _twoColumnBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Scaffold(
      backgroundColor: dsPageSurface(context),
      body: CustomScrollView(
        slivers: [
          _HeroSliver(
            card: data.card,
            whenLabel: data.whenLabel,
            onBack: onBack,
            onDelete: onDelete,
            onChangeCover: onChangeCover,
            onRenameTitle: onRenameTitle,
            onTapCategory: onTapCategory,
            onTapStatus: onTapStatus,
            onTapDateTime: onTapDateTime,
            onSetRating: onSetRating,
            onAddCover: onAddCover,
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacing.step4,
                    tokens.spacing.step4,
                    tokens.spacing.step4,
                    tokens.spacing.step10,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final twoColumn =
                          constraints.maxWidth >= _twoColumnBreakpoint;
                      return twoColumn
                          ? _twoColumnBody(context)
                          : _oneColumnBody(context);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _oneColumnBody(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._mainColumn(context),
        ..._tasksBlock(context),
        SizedBox(height: tokens.spacing.step2),
      ],
    );
  }

  Widget _twoColumnBody(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _mainColumn(context),
          ),
        ),
        SizedBox(width: tokens.spacing.step6),
        SizedBox(
          width: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _tasksBlock(context),
          ),
        ),
      ],
    );
  }

  List<Widget> _mainColumn(BuildContext context) {
    return [
      // The date/time lives in the hero now (single source); the body opens
      // straight into the summary + sections.
      if (data.summary != null)
        _SummaryCard(summary: data.summary!, onRegenerate: onRegenerateSummary),
      // A flat, scannable photo wall (distinct from the narrative timeline).
      if (data.photos.isNotEmpty) ...[
        _SectionHeader(
          title: context.messages.eventsPhotosSection,
          count: data.photos.length,
          onAdd: onAddToTimeline,
        ),
        EventPhotoGrid(photos: data.photos),
      ],
      _SectionHeader(
        title: context.messages.eventsTimelineSection,
        count: data.timeline.length,
        onAdd: onAddToTimeline,
      ),
      if (data.timeline.isEmpty)
        _EmptyHint(
          label: context.messages.eventsTimelineEmpty,
          onTap: onAddToTimeline,
        )
      else
        _Timeline(entries: data.timeline, onOpenEntry: onOpenTimelineEntry),
    ];
  }

  List<Widget> _tasksBlock(BuildContext context) {
    return [
      _SectionHeader(
        title: context.messages.eventsTasksSection,
        count: data.tasks.length,
        onAdd: onAddTask,
      ),
      if (data.tasks.isEmpty)
        _EmptyHint(
          label: context.messages.eventsTasksEmpty,
          onTap: onAddTask,
        )
      else
        for (final task in data.tasks) _TaskRow(task: task, onOpen: onOpenTask),
    ];
  }
}

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
      leading: _ScrimIconButton(icon: Icons.arrow_back, onPressed: onBack),
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
  });

  final EventCardData card;
  final String? whenLabel;
  final ValueChanged<String>? onRenameTitle;
  final VoidCallback? onTapCategory;
  final VoidCallback? onTapStatus;
  final VoidCallback? onTapDateTime;
  final ValueChanged<double>? onSetRating;
  final VoidCallback? onAddCover;

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
        if (card.coverImage == null && onAddCover != null) ...[
          _AddCoverButton(onTap: onAddCover),
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
              Icon(Icons.event_outlined, size: 15, color: fade),
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
                  Icons.edit_outlined,
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
/// event has none.
class _AddCoverButton extends StatelessWidget {
  const _AddCoverButton({this.onTap});

  final VoidCallback? onTap;

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
              const Icon(
                Icons.add_a_photo_outlined,
                size: 16,
                color: Colors.white,
              ),
              SizedBox(width: tokens.spacing.step2),
              Text(
                context.messages.eventsAddCoverPhoto,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: Colors.white,
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
                Icons.add,
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
          icon: const Icon(Icons.more_horiz, color: Colors.white),
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
                      Icons.image_outlined,
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
                    Icon(Icons.delete_outline, size: 18, color: cs.error),
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
              Icon(Icons.auto_awesome, size: 16, color: cs.primary),
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
                icon: const Icon(Icons.refresh),
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
  const _SectionHeader({required this.title, required this.count, this.onAdd});

  final String title;
  final int count;
  final VoidCallback? onAdd;

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
          const Spacer(),
          if (onAdd != null) _AddButton(onTap: onAdd),
        ],
      ),
    );
  }
}

/// Explicit, always-legible "Add" affordance (a generic [TextButton.icon]
/// rendered as a near-invisible pill against the dark card surface).
class _AddButton extends StatelessWidget {
  const _AddButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    return Material(
      color: Colors.transparent,
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
              Icon(Icons.add, size: 18, color: cs.primary),
              SizedBox(width: tokens.spacing.step1),
              Text(
                context.messages.eventsAddLabel,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: cs.primary,
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

/// Tappable placeholder shown when a section has no content yet, so a fresh
/// event always offers something to do instead of a blank gap.
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    return Material(
      color: dsCardSurface(context),
      borderRadius: BorderRadius.circular(tokens.radii.m),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step4),
          child: Row(
            children: [
              Icon(Icons.add, size: 18, color: cs.onSurfaceVariant),
              SizedBox(width: tokens.spacing.step2),
              Expanded(
                child: Text(
                  label,
                  style: tokens.typography.styles.body.bodyMedium.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries, this.onOpenEntry});

  final List<EventTimelineEntry> entries;
  final ValueChanged<String>? onOpenEntry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          _TimelineTile(
            entry: entries[i],
            isLast: i == entries.length - 1,
            onOpenEntry: onOpenEntry,
          ),
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.entry,
    required this.isLast,
    this.onOpenEntry,
  });

  final EventTimelineEntry entry;
  final bool isLast;
  final ValueChanged<String>? onOpenEntry;

  static const double _railWidth = 28;
  static const double _dotSize = 12;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    // Only interactive — and only carrying the "open" chevron — when there's a
    // navigable source entry and a handler to open it.
    final entryId = entry.entryId;
    final canOpen = onOpenEntry != null && entryId != null;

    final row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _railWidth,
            child: Column(
              children: [
                SizedBox(height: tokens.spacing.step1),
                Container(
                  width: _dotSize,
                  height: _dotSize,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(width: 2, color: cs.outline),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.step5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.timeLabel,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step2),
                  _TimelineContent(entry: entry),
                ],
              ),
            ),
          ),
          // Trailing chevron signals the row opens its source entry. Pinned to
          // the top (timestamp line) so it reads as a row-level "open"
          // affordance, not horizontal paging of the photo cluster below.
          if (canOpen)
            Padding(
              padding: EdgeInsets.only(left: tokens.spacing.step2),
              child: Align(
                alignment: Alignment.topCenter,
                child: Icon(Icons.chevron_right, size: 20, color: cs.outline),
              ),
            ),
        ],
      ),
    );

    if (!canOpen) return row;
    return InkWell(
      onTap: () => onOpenEntry!(entryId),
      borderRadius: BorderRadius.circular(tokens.radii.s),
      child: row,
    );
  }
}

class _TimelineContent extends StatelessWidget {
  const _TimelineContent({required this.entry});

  final EventTimelineEntry entry;

  static const double _leadHeight = 196;
  static const double _thumbSize = 72;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    final styles = tokens.typography.styles;

    switch (entry.kind) {
      case EventTimelineKind.photo:
        // A hero "lead" frame plus a small supporting cluster, with the caption
        // anchored beneath — a curated moment, not a flat contact strip.
        final photos = entry.photos;
        // Degrade to the caption (or nothing) rather than crashing on a photo
        // beat that arrived without any images.
        if (photos.isEmpty) {
          return Text(
            entry.text ?? '',
            style: styles.body.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          );
        }
        final lead = photos.first;
        final rest = photos.length > 1
            ? photos.sublist(1)
            : const <EventPhoto>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radii.m),
              child: SizedBox(
                height: _leadHeight,
                width: double.infinity,
                child: EventCoverImage(
                  image: lead.image,
                  fallbackColor: cs.surfaceContainerHighest,
                  cropX: lead.cropX,
                  scrim: EventCoverScrim.none,
                ),
              ),
            ),
            if (rest.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step2),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final photo in rest) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(tokens.radii.s),
                        child: SizedBox(
                          width: _thumbSize,
                          height: _thumbSize,
                          child: EventCoverImage(
                            image: photo.image,
                            fallbackColor: cs.surfaceContainerHighest,
                            cropX: photo.cropX,
                            scrim: EventCoverScrim.none,
                          ),
                        ),
                      ),
                      SizedBox(width: tokens.spacing.step2),
                    ],
                  ],
                ),
              ),
            ],
            if (entry.text != null) ...[
              SizedBox(height: tokens.spacing.step2),
              Text(
                entry.text!,
                style: styles.body.bodyMedium.copyWith(
                  color: cs.onSurface,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        );
      case EventTimelineKind.note:
        return Text(
          entry.text ?? '',
          style: styles.body.bodyLarge.copyWith(color: cs.onSurface),
        );
      case EventTimelineKind.audio:
        return Row(
          children: [
            Icon(Icons.play_circle_outline, size: 22, color: cs.primary),
            SizedBox(width: tokens.spacing.step2),
            Text(
              entry.durationLabel ?? context.messages.eventsVoiceNote,
              style: styles.body.bodyMedium.copyWith(color: cs.onSurface),
            ),
            if (entry.text != null) ...[
              SizedBox(width: tokens.spacing.step2),
              Flexible(
                child: Text(
                  entry.text!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: styles.body.bodyMedium.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        );
    }
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
            task.done ? Icons.check_circle : Icons.radio_button_unchecked,
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
            Icon(Icons.chevron_right, size: 20, color: cs.outline),
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
