import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/relationships/state/relationships_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// One person's page: header (name, status, importance, cadence) and the
/// check-in log, newest first, with a log-check-in FAB.
class RelationshipDetailsPage extends ConsumerWidget {
  const RelationshipDetailsPage({required this.relationshipId, super.key});

  final String relationshipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final detailAsync = ref.watch(
      relationshipDetailControllerProvider(relationshipId),
    );
    // Keep the last rendered detail during background reloads.
    final detail = detailAsync.value;

    if (detail == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: detailAsync.isLoading
              ? const CircularProgressIndicator.adaptive()
              : Text(context.messages.commonError),
        ),
      );
    }

    final relationship = detail.relationship;
    final checkIns = detail.checkIns;
    final data = relationship.data;

    return Scaffold(
      floatingActionButton: DesignSystemBottomNavigationFabPadding(
        child: FloatingActionButton.extended(
          onPressed: () => showCheckInCaptureSheet(
            context: context,
            relationshipId: relationshipId,
          ),
          label: Text(context.messages.relationshipLogCheckIn),
          icon: const Icon(Icons.waving_hand_rounded),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text(data.title),
              actions: [
                if (data.important)
                  Padding(
                    padding: EdgeInsets.only(right: tokens.spacing.step4),
                    child: Icon(
                      Icons.star_rounded,
                      color: tokens.colors.interactive.enabled,
                    ),
                  ),
              ],
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.step5,
                tokens.spacing.step5,
                tokens.spacing.step5,
                tokens.spacing.step5 +
                    DesignSystemBottomNavigationBar.occupiedHeight(context) +
                    tokens.spacing.step12,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _RelationshipHeader(data: data),
                  SizedBox(height: tokens.spacing.sectionGap),
                  if (checkIns.isEmpty)
                    Text(
                      context.messages.relationshipNoCheckIns,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    )
                  else
                    for (final checkIn in checkIns) ...[
                      _CheckInRow(checkIn: checkIn),
                      SizedBox(height: tokens.spacing.cardItemSpacing),
                    ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RelationshipHeader extends StatelessWidget {
  const _RelationshipHeader({required this.data});

  final RelationshipData data;

  String _statusLabel(BuildContext context) => switch (data.status) {
    RelationshipActive() => context.messages.relationshipStatusActive,
    RelationshipDormant() => context.messages.relationshipStatusDormant,
    RelationshipArchived() => context.messages.relationshipStatusArchived,
  };

  String? _cadenceLabel(BuildContext context) =>
      switch (data.checkInCadenceDays) {
        null => null,
        7 => context.messages.relationshipCadenceWeekly,
        14 => context.messages.relationshipCadenceFortnightly,
        30 => context.messages.relationshipCadenceMonthly,
        _ => context.messages.relationshipCadenceQuarterly,
      };

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cadence = _cadenceLabel(context);

    Widget chip(String label, IconData icon) => Chip(
      avatar: Icon(icon, size: tokens.spacing.step4),
      label: Text(label),
      labelStyle: tokens.typography.styles.body.bodySmall.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
    );

    return Wrap(
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step3,
      children: [
        chip(_statusLabel(context), Icons.circle_outlined),
        if (cadence != null) chip(cadence, Icons.update_rounded),
        if (data.nickname != null)
          chip(data.nickname!, Icons.tag_faces_rounded),
      ],
    );
  }
}

class _CheckInRow extends StatelessWidget {
  const _CheckInRow({required this.checkIn});

  final CheckInEntry checkIn;

  IconData get _icon => switch (checkIn.data.interactionType) {
    CheckInInteractionType.inPerson => Icons.people_rounded,
    CheckInInteractionType.call => Icons.call_rounded,
    CheckInInteractionType.videoCall => Icons.videocam_rounded,
    CheckInInteractionType.message => Icons.chat_rounded,
    CheckInInteractionType.other => Icons.forum_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final data = checkIn.data;
    final narrative = checkIn.entryText?.plainText.trim();
    final sentiment = data.sentiment;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon, color: tokens.colors.text.mediumEmphasis),
                SizedBox(width: tokens.spacing.step3),
                Expanded(
                  child: Text(
                    checkInInteractionLabel(context, data.interactionType),
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
                Text(
                  entryDateLabel(context, checkIn.meta.dateFrom),
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ],
            ),
            if (sentiment != null) ...[
              SizedBox(height: tokens.spacing.step3),
              Text(
                checkInSentimentLabel(context, sentiment),
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ],
            if (narrative != null && narrative.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step3),
              Text(
                narrative,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ],
            if (data.topics.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step3),
              Wrap(
                spacing: tokens.spacing.step2,
                runSpacing: tokens.spacing.step2,
                children: [
                  for (final topic in data.topics)
                    Chip(
                      label: Text(topic),
                      labelStyle: tokens.typography.styles.body.bodySmall
                          .copyWith(
                            color: tokens.colors.text.mediumEmphasis,
                          ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
