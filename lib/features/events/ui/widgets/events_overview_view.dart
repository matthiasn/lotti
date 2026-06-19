import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_card.dart';
import 'package:lotti/features/events/ui/widgets/event_feature_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// The Events overview: a memory-forward, photo-led wall of event cards,
/// grouped into time sections and filterable by category.
///
/// Pure/presentational — it takes already-resolved [sections] and renders a
/// responsive layout: featured sections become full-width hero cards, ordinary
/// sections become a width-filling card grid (one column on phones, several on
/// desktop). A provider supplies the data; this widget owns only layout.
class EventsOverviewView extends StatelessWidget {
  const EventsOverviewView({
    required this.sections,
    this.subtitle,
    this.categories = const [],
    this.selectedCategoryId,
    this.onSelectCategory,
    this.onOpenEvent,
    this.onCreate,
    this.onSearch,
    super.key,
  });

  final List<EventSection> sections;
  final String? subtitle;
  final List<EventCategoryFilter> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?>? onSelectCategory;
  final ValueChanged<EventCardData>? onOpenEvent;
  final VoidCallback? onCreate;
  final VoidCallback? onSearch;

  /// Target card width; column count is derived from the available width.
  static const double _targetCardWidth = 340;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final gap = tokens.spacing.step4;
    final edge = tokens.spacing.step4;

    return Scaffold(
      backgroundColor: dsPageSurface(context),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  edge,
                  tokens.spacing.step4,
                  edge,
                  tokens.spacing.step2,
                ),
                child: _Header(
                  subtitle: subtitle,
                  categories: categories,
                  selectedCategoryId: selectedCategoryId,
                  onSelectCategory: onSelectCategory,
                  onSearch: onSearch,
                  onCreateInHeader: onCreate,
                ),
              ),
            ),
            for (final section in sections) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    edge,
                    tokens.spacing.step7,
                    edge,
                    tokens.spacing.step2,
                  ),
                  child: Text(
                    section.title,
                    style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                      color: context.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: edge),
                sliver: SliverToBoxAdapter(
                  child: section.featured
                      ? _FeaturedColumn(
                          section: section,
                          gap: gap,
                          onOpenEvent: onOpenEvent,
                        )
                      : _CardGrid(
                          section: section,
                          gap: gap,
                          targetCardWidth: _targetCardWidth,
                          onOpenEvent: onOpenEvent,
                        ),
                ),
              ),
            ],
            SliverToBoxAdapter(child: SizedBox(height: tokens.spacing.step12)),
          ],
        ),
      ),
    );
  }
}

class _FeaturedColumn extends StatelessWidget {
  const _FeaturedColumn({
    required this.section,
    required this.gap,
    required this.onOpenEvent,
  });

  final EventSection section;
  final double gap;
  final ValueChanged<EventCardData>? onOpenEvent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final event in section.events) ...[
          EventFeatureCard(
            data: event,
            onTap: onOpenEvent == null ? null : () => onOpenEvent!(event),
          ),
          SizedBox(height: gap),
        ],
      ],
    );
  }
}

class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.section,
    required this.gap,
    required this.targetCardWidth,
    required this.onOpenEvent,
  });

  final EventSection section;
  final double gap;
  final double targetCardWidth;
  final ValueChanged<EventCardData>? onOpenEvent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / targetCardWidth).floor().clamp(
          1,
          4,
        );
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final event in section.events)
              SizedBox(
                width: cardWidth,
                child: EventCard(
                  data: event,
                  onTap: onOpenEvent == null ? null : () => onOpenEvent!(event),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.subtitle,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelectCategory,
    required this.onSearch,
    required this.onCreateInHeader,
  });

  final String? subtitle;
  final List<EventCategoryFilter> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?>? onSelectCategory;
  final VoidCallback? onSearch;

  /// When non-null (wide layouts), shows a "New event" button in the header.
  final VoidCallback? onCreateInHeader;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    final styles = tokens.typography.styles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              context.messages.eventsPageTitle,
              style: styles.heading.heading1.copyWith(color: cs.onSurface),
            ),
            if (subtitle != null) ...[
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Text(
                  subtitle!,
                  style: styles.body.bodyMedium.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ] else
              const Spacer(),
            if (onCreateInHeader != null)
              FilledButton.icon(
                onPressed: onCreateInHeader,
                icon: const Icon(Icons.add),
                label: Text(context.messages.eventsNewEvent),
              ),
          ],
        ),
        SizedBox(height: tokens.spacing.step4),
        _SearchField(onTap: onSearch),
        if (categories.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.step3),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final category in categories) ...[
                  _FilterChip(
                    filter: category,
                    selected: category.id == selectedCategoryId,
                    onTap: onSelectCategory == null
                        ? null
                        : () => onSelectCategory!(category.id),
                  ),
                  SizedBox(width: tokens.spacing.step2),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A prominent, tappable search affordance — far more discoverable than a bare
/// icon for a surface that can hold dozens of events.
class _SearchField extends StatelessWidget {
  const _SearchField({this.onTap});

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
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step3,
            vertical: tokens.spacing.step3,
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: cs.onSurfaceVariant),
              SizedBox(width: tokens.spacing.step2),
              Text(
                context.messages.eventsSearchHint,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final EventCategoryFilter filter;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    final accent = filter.id == null ? cs.primary : filter.color;

    return Material(
      color: selected ? accent.withValues(alpha: 0.30) : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? accent : cs.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
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
              if (filter.id != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: filter.color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: tokens.spacing.step2),
              ],
              Text(
                filter.label,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: selected ? cs.onSurface : cs.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
