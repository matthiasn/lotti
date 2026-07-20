import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/journal_card.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/journal_image_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;

/// Per-row dispatcher for the journal list: [ModernJournalImageCard] for
/// images, [ModernJournalCard] for everything else (including tasks, which
/// share the same card anatomy as the rest of the feed), wrapped in a
/// [RepaintBoundary] so scroll repaints stay isolated per row.
///
/// When `vectorDistance` is set (vector-search results), a color-coded distance
/// badge is overlaid in the corner (greener = closer; see
/// [colorForVectorDistance]).
///
/// On desktop the row tracks `NavService.desktopSelectedEntryId` and highlights
/// itself while its entry fills the detail pane. Below the desktop breakpoint
/// tapping a row navigates away, so nothing stays selected and the highlight is
/// skipped entirely.
class CardWrapperWidget extends ConsumerWidget {
  const CardWrapperWidget({
    required this.item,
    this.vectorDistance,
    super.key,
  });

  final JournalEntity item;

  /// Cosine distance from vector search, if applicable.
  final double? vectorDistance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;

    // RepaintBoundary isolates repaints to individual cards,
    // preventing cascading rebuilds during scroll. Tasks go through the same
    // ModernJournalCard as every other type so the mixed feed keeps one card
    // anatomy (title scale, date meta row, chip grammar) across entry types.
    Widget buildCard({required bool selected}) => item.maybeMap(
      journalImage: (JournalImage image) =>
          ModernJournalImageCard(item: image, selected: selected),
      orElse: () => ModernJournalCard(item: item, selected: selected),
    );

    // Tasks and events open in their own tabs' detail panes, so only plain
    // logbook entries can be the logbook's selected row.
    final tracksSelection =
        isDesktopLayout(context) && item is! Task && item is! JournalEvent;

    final card = tracksSelection
        ? ValueListenableBuilder<String?>(
            valueListenable: getIt<NavService>().desktopSelectedEntryId,
            builder: (context, selectedEntryId, _) =>
                buildCard(selected: selectedEntryId == item.meta.id),
          )
        : buildCard(selected: false);

    // No extra horizontal padding here: the card's own step5 margin is the
    // single left/right gutter, so card edges share one exact rail with the
    // header's title and search field.
    return RepaintBoundary(
      child: vectorDistance != null
          ? Stack(
              children: [
                card,
                Positioned(
                  top: tokens.spacing.step2,
                  right: tokens.spacing.step2,
                  child: IgnorePointer(
                    child: _DistanceBadge(distance: vectorDistance!),
                  ),
                ),
              ],
            )
          : card,
    );
  }
}

class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({required this.distance})
    : super(key: const Key('distanceBadge'));

  final double distance;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: _colorForDistance(distance),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Text(
        distance.toStringAsFixed(2),
        // The band colors are a data ramp (see [colorForVectorDistance]);
        // only the chrome is tokenized.
        style: tokens.typography.styles.others.overline.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontFeatures: numericBadgeFontFeatures,
        ),
      ),
    );
  }

  static Color _colorForDistance(double d) => colorForVectorDistance(d);
}

/// Maps a vector-search distance to the badge color: greener is closer,
/// warming through orange and deep orange to red as relevance drops.
@visibleForTesting
Color colorForVectorDistance(double d) {
  if (d < 0.3) return Colors.green;
  if (d < 0.6) return Colors.orange.shade700;
  if (d < 0.8) return Colors.deepOrange;
  return Colors.red;
}
