import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/state/relationships_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// One person's page: header (name, status, importance, cadence) and the
/// check-in log, newest first, with a log-check-in FAB. The app bar carries
/// edit and delete actions; tapping a check-in opens it for editing.
class RelationshipDetailsPage extends ConsumerWidget {
  const RelationshipDetailsPage({required this.relationshipId, super.key});

  final String relationshipId;

  Future<void> _handleDelete(
    BuildContext context,
    WidgetRef ref,
    RelationshipEntry relationship,
  ) async {
    final confirmed = await showConfirmationModal(
      context: context,
      title: context.messages.relationshipDeleteConfirmTitle(
        relationship.data.title,
      ),
      message: context.messages.relationshipDeleteConfirmMessage,
      confirmLabel: context.messages.deleteButton,
    );
    if (!confirmed || !context.mounted) return;

    try {
      final deleted = await ref
          .read(relationshipRepositoryProvider)
          .deleteRelationship(relationship.id);
      if (!context.mounted) return;
      if (deleted) {
        beamToNamed('/people');
      } else {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.relationshipErrorDeleteFailed,
        );
      }
    } catch (e, s) {
      developer.log(
        'Failed to delete relationship',
        name: 'RelationshipDetailsPage',
        error: e,
        stackTrace: s,
      );
      if (context.mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.relationshipErrorDeleteFailed,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final detailAsync = ref.watch(
      relationshipDetailControllerProvider(relationshipId),
    );
    // Keep the last rendered detail during background reloads.
    final detail = detailAsync.value;

    if (detail == null) {
      // Resolved-null means the person is gone (deleted here or on another
      // device) — that is not an error, so say so instead of alarming.
      final body = detailAsync.isLoading
          ? const CircularProgressIndicator.adaptive()
          : Text(
              detailAsync.hasError
                  ? context.messages.commonError
                  : context.messages.relationshipNotFound,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            );
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: body),
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
                  Icon(
                    Icons.star_rounded,
                    color: tokens.colors.interactive.enabled,
                  ),
                IconButton(
                  tooltip: context.messages.relationshipEditTitle,
                  onPressed: () => showRelationshipEditModal(
                    context: context,
                    relationship: relationship,
                  ),
                  icon: const Icon(Icons.edit_rounded),
                ),
                IconButton(
                  tooltip: context.messages.deleteButton,
                  onPressed: () => _handleDelete(context, ref, relationship),
                  icon: const Icon(Icons.delete_outline_rounded),
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cadenceDays = data.checkInCadenceDays;

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
        chip(
          relationshipStatusLabel(context, data.status),
          Icons.circle_outlined,
        ),
        if (cadenceDays != null)
          chip(
            relationshipCadenceLabel(context, cadenceDays),
            Icons.update_rounded,
          ),
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showCheckInEditSheet(context: context, checkIn: checkIn),
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
      ),
    );
  }
}
