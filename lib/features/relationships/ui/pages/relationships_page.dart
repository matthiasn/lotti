import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/state/relationships_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// The People tab: every tracked relationship, most recently interacted-with
/// first (people without a check-in sort by tracking start), with an
/// add-person FAB. Tapping a row beams to `/people/<id>`.
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
      floatingActionButton: DesignSystemBottomNavigationFabPadding(
        child: FloatingActionButton.extended(
          onPressed: () => showRelationshipCreateModal(context: context),
          label: Text(context.messages.relationshipCreateTitle),
          icon: const Icon(Icons.person_add_rounded),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text(context.messages.relationshipsPageTitle),
            ),
            SliverPadding(
              // The last row must clear the overlaid bottom navigation plus
              // the lifted FAB's footprint (the projects-list clearance
              // idiom).
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.step5,
                tokens.spacing.step5,
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
                // arm because the previous value is retained above. The
                // detail page and the projects list share this shape.
                null => SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.sectionGap),
                    child: const Center(
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  ),
                ),
                [] => const SliverToBoxAdapter(child: _EmptyState()),
                final list => SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(height: tokens.spacing.cardItemSpacing),
                  itemBuilder: (context, index) =>
                      _RelationshipRow(item: list[index]),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.sectionGap),
      child: Column(
        children: [
          Icon(
            Icons.people_outlined,
            size: tokens.spacing.step12,
            color: tokens.colors.text.lowEmphasis,
          ),
          SizedBox(height: tokens.spacing.step5),
          Text(
            context.messages.relationshipsEmptyState,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

class _RelationshipRow extends StatelessWidget {
  const _RelationshipRow({required this.item});

  final RelationshipListItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final relationship = item.relationship;
    final data = relationship.data;

    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: tokens.spacing.step4),
      leading: Icon(
        Icons.person_rounded,
        color: tokens.colors.text.mediumEmphasis,
      ),
      title: Text(
        data.title,
        style: tokens.typography.styles.body.bodyLarge.copyWith(
          color: tokens.colors.text.highEmphasis,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // Last-check-in recency (plan v2 phase 2); tracking start until the
      // first check-in exists. The two dates mean opposite things on a
      // recency screen — a person added today has NOT been contacted today —
      // so each branch names itself.
      subtitle: Text(
        item.lastCheckInAt != null
            ? context.messages.relationshipLastCheckInLabel(
                entryDateLabel(context, item.lastCheckInAt!),
              )
            : context.messages.relationshipTrackingSinceLabel(
                entryDateLabel(context, relationship.meta.dateFrom),
              ),
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.lowEmphasis,
        ),
      ),
      trailing: data.important
          ? Icon(
              Icons.star_rounded,
              color: tokens.colors.interactive.enabled,
            )
          : null,
      onTap: () => beamToNamed('/people/${relationship.id}'),
    );
  }
}
