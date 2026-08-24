import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/contacts_service.dart';
import 'package:lotti/features/relationships/state/relationships_providers.dart';
import 'package:lotti/features/relationships/ui/pages/contact_import_page.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/nav_bar/bottom_nav_safe_navigator.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// The People tab (design plan §1): a left-aligned display header with one
/// add affordance (a 34px teal circle `＋`), and one row per person — persona
/// avatar, name with an inline star when favorited, a status line (the last
/// meaningful event or a quiet-streak) with a cadence-state dot, and a
/// trailing cadence pill. Rows sort due-first then by recency; favorites
/// are a marker, not a section.
class RelationshipsPage extends ConsumerWidget {
  const RelationshipsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final itemsAsync = ref.watch(relationshipsListControllerProvider);
    // Never flash the established list during a background reload — keep the
    // previous value while the refetch runs.
    final items = itemsAsync.value;
    final failedFirstLoad = items == null && itemsAsync.hasError;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _PeopleHeader(itemCount: items?.length)),
            SliverPadding(
              // The last row must clear the overlaid bottom navigation.
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.step5,
                tokens.spacing.step3,
                tokens.spacing.step5,
                tokens.spacing.step5 +
                    DesignSystemBottomNavigationBar.occupiedHeight(context) +
                    tokens.spacing.step12,
              ),
              sliver: switch (items) {
                null when failedFirstLoad => SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.sectionGap),
                    child: Text(
                      context.messages.commonError,
                      textAlign: TextAlign.center,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ),
                ),
                // First load only — a background reload never reaches this
                // arm because the previous value is retained above.
                null => SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.sectionGap),
                    child: const Center(
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  ),
                ),
                [] => SliverToBoxAdapter(child: _EmptyState()),
                final list => () {
                  final sorted = sortPeopleForList(list);
                  return SliverList.separated(
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      thickness: 1,
                      color: tokens.colors.decorative.level01,
                    ),
                    itemBuilder: (context, index) =>
                        _RelationshipRow(item: sorted[index]),
                  );
                }(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The left-aligned `People` title with a count caption and the single add
/// affordance (design plan §0.3 / §1). Not a Material `AppBar` — the title is
/// left-aligned display type, and the import-from-contacts door sits beside
/// the add circle (a distinct action, not a second add affordance).
class _PeopleHeader extends ConsumerWidget {
  const _PeopleHeader({required this.itemCount});

  final int? itemCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step3,
      ),
      child: Row(
        children: [
          Text(
            messages.relationshipsPageTitle,
            style: tokens.typography.styles.heading.heading2.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          if (itemCount != null) ...[
            SizedBox(width: tokens.spacing.step2),
            Text(
              '· $itemCount',
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ],
          const Spacer(),
          // Import is a distinct door, not a second add affordance; hidden on
          // desktop where there is no address book (ADR 0041 §2).
          if (ref.read(contactsServiceProvider).isSupported)
            _IconButton(
              icon: LottiIcons.contactImport,
              tooltip: messages.relationshipImportAction,
              onTap: () => bottomNavSafeNavigatorOf(context).push(
                MaterialPageRoute<int>(
                  builder: (_) => const ContactImportPage(),
                ),
              ),
            ),
          SizedBox(width: tokens.spacing.step2),
          _AddPersonButton(
            onTap: () => showRelationshipCreateModal(context: context),
          ),
        ],
      ),
    );
  }
}

class _AddPersonButton extends StatelessWidget {
  const _AddPersonButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Material(
      color: tokens.colors.interactive.enabled,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            LottiIcons.add,
            size: 20,
            color: tokens.colors.background.level01,
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step2),
          child: Icon(
            icon,
            size: 22,
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.sectionGap),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            messages.relationshipsEmptyState,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step5),
          _AddPersonButton(
            onTap: () => showRelationshipCreateModal(context: context),
          ),
        ],
      ),
    );
  }
}

/// One person row (design plan §1): 40px persona avatar, name + inline star,
/// a cadence-state dot + status line, and a trailing cadence pill.
class _RelationshipRow extends StatelessWidget {
  const _RelationshipRow({required this.item});

  final RelationshipListItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final relationship = item.relationship;
    final data = relationship.data;
    final cadenceDays = data.checkInCadenceDays;

    return InkWell(
      onTap: () => beamToNamed('/people/${relationship.id}'),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step4,
          vertical: tokens.spacing.step3,
        ),
        child: Row(
          children: [
            PersonaAvatar(
              initial: personaInitial(data.title),
              id: relationship.id,
            ),
            SizedBox(width: tokens.spacing.step4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          data.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.body.bodyLarge
                              .copyWith(
                                fontWeight: tokens.typography.weight.semiBold,
                                color: tokens.colors.text.highEmphasis,
                              ),
                        ),
                      ),
                      if (data.important) ...[
                        SizedBox(width: tokens.spacing.step2),
                        Icon(
                          LottiIconsFilled.star,
                          size: 11,
                          color: tokens.colors.interactive.enabled,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: tokens.spacing.step1),
                  Row(
                    children: [
                      _CadenceStateDot(
                        cadenceDays: cadenceDays,
                        lastCheckInAt: item.lastCheckInAt,
                        trackingStartedAt: relationship.meta.dateFrom,
                      ),
                      SizedBox(width: tokens.spacing.step2),
                      Flexible(
                        child: Text(
                          _statusLine(
                            context,
                            item,
                            cadenceDays,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            _CadencePill(
              cadenceDays: cadenceDays,
              lastCheckInAt: item.lastCheckInAt,
              trackingStartedAt: relationship.meta.dateFrom,
            ),
          ],
        ),
      ),
    );
  }

  /// The status line: the last meaningful event (with its mono timestamp),
  /// or the quiet-streak caption. "Tracking since …" is dropped entirely
  /// (design plan §0.8) — a person added today has not been contacted today.
  String _statusLine(
    BuildContext context,
    RelationshipListItem item,
    int? cadenceDays,
  ) {
    final messages = context.messages;
    final last = item.lastCheckInAt;
    if (last != null) {
      return messages.relationshipCheckedInLabel(
        relationshipTimestampLabel(last),
      );
    }
    final streak = quietStreakDays(
      lastCheckInAt: null,
      trackingStartedAt: item.relationship.meta.dateFrom,
    );
    if (streak == 0) return messages.relationshipJustAdded;
    return messages.relationshipQuietForDays(streak);
  }
}

/// The 7px cadence-state dot: teal when on track, warning when due, neutral
/// when there is no cadence (design plan §0.6 / §1).
class _CadenceStateDot extends StatelessWidget {
  const _CadenceStateDot({
    required this.cadenceDays,
    required this.lastCheckInAt,
    required this.trackingStartedAt,
  });

  final int? cadenceDays;
  final DateTime? lastCheckInAt;
  final DateTime trackingStartedAt;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final overdue = cadenceOverdueDays(
      lastCheckInAt: lastCheckInAt,
      trackingStartedAt: trackingStartedAt,
      cadenceDays: cadenceDays,
    );
    final color = switch (overdue) {
      null => tokens.colors.text.highEmphasis.withValues(alpha: 0.38),
      <= 0 => tokens.colors.interactive.enabled,
      _ => tokens.colors.alert.warning.defaultColor,
    };
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// The trailing cadence pill: quiet/on-track when not due, warning-tinted
/// `Due {day}` when overdue (design plan §1).
class _CadencePill extends StatelessWidget {
  const _CadencePill({
    required this.cadenceDays,
    required this.lastCheckInAt,
    required this.trackingStartedAt,
  });

  final int? cadenceDays;
  final DateTime? lastCheckInAt;
  final DateTime trackingStartedAt;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    if (cadenceDays == null) return const SizedBox.shrink();

    final due = cadenceDueDate(
      lastCheckInAt: lastCheckInAt,
      trackingStartedAt: trackingStartedAt,
      cadenceDays: cadenceDays,
    );
    final overdue = cadenceOverdueDays(
      lastCheckInAt: lastCheckInAt,
      trackingStartedAt: trackingStartedAt,
      cadenceDays: cadenceDays,
    );

    final dueOverdue = (overdue ?? 0) > 0;
    final label = dueOverdue
        ? messages.relationshipDueDay(relationshipWeekdayLabel(due!))
        : messages.relationshipCadenceOnTrack;
    final fg = dueOverdue
        ? tokens.colors.alert.warning.defaultColor
        : tokens.colors.text.mediumEmphasis;
    final bg = dueOverdue
        ? tokens.colors.alert.warning.defaultColor.withValues(alpha: 0.16)
        : tokens.colors.surface.enabled;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tokens.typography.styles.others.caption.copyWith(
          color: fg,
          fontWeight: tokens.typography.weight.semiBold,
          height: 1,
        ),
      ),
    );
  }
}

/// Sort the list due-first, then by last-contact recency (design plan §1).
/// Favorites do NOT get a separate section; the star is a marker.
List<RelationshipListItem> sortPeopleForList(List<RelationshipListItem> items) {
  final due = <RelationshipListItem>[];
  final rest = <RelationshipListItem>[];
  for (final item in items) {
    final overdue = cadenceOverdueDays(
      lastCheckInAt: item.lastCheckInAt,
      trackingStartedAt: item.relationship.meta.dateFrom,
      cadenceDays: item.relationship.data.checkInCadenceDays,
    );
    if ((overdue ?? 0) > 0) {
      due.add(item);
    } else {
      rest.add(item);
    }
  }
  DateTime recency(RelationshipListItem i) =>
      i.lastCheckInAt ?? i.relationship.meta.dateFrom;
  due.sort((a, b) => recency(b).compareTo(recency(a)));
  rest.sort((a, b) => recency(b).compareTo(recency(a)));
  return [...due, ...rest];
}
