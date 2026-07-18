import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/modal/sized_wolt_side_sheet_type.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class AiAttributionSummary extends ConsumerWidget {
  const AiAttributionSummary({
    required this.artifact,
    this.envelope,
    this.compact = false,
    this.includeTopSpacing = true,
    super.key,
  });

  final AiArtifactReference artifact;
  final AiTerminalAttributionEnvelope? envelope;
  final bool compact;
  final bool includeTopSpacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetails = envelope == null
        ? ref.watch(aiAttributionForArtifactProvider(artifact))
        : ref.watch(
            aiAttributionDetailsProvider(envelope!.attribution.id),
          );
    final details = asyncDetails.value;
    final attribution = details?.attribution ?? envelope?.attribution;
    if (attribution == null) return const SizedBox.shrink();
    final row = _AttributionRow(
      attribution: attribution,
      details: details,
      compact: compact,
      isLoading: asyncDetails.isLoading && details == null,
    );
    if (!includeTopSpacing) return row;
    return Padding(
      padding: EdgeInsets.only(top: context.designTokens.spacing.step3),
      child: row,
    );
  }
}

class _AttributionRow extends StatelessWidget {
  const _AttributionRow({
    required this.attribution,
    required this.details,
    required this.compact,
    required this.isLoading,
  });

  final AiWorkAttribution attribution;
  final AiAttributionDetails? details;
  final bool compact;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final actor = _actorDisplayName(context, attribution.initiator);
    final primary = context.messages.aiAttributionSummary(
      actor,
      _triggerLabel(context, attribution.trigger.type),
      _statusLabel(context, attribution.status),
    );
    final model = isLoading
        ? null
        : details?.interactions
              .map((event) => event.providerModelId ?? event.modelId)
              .whereType<String>()
              .firstOrNull;
    final secondary = isLoading
        ? '…'
        : context.messages.aiAttributionSecondary(
            model ?? context.messages.aiAttributionUnknownModel,
            DateFormat.yMMMd().add_jm().format(
              attribution.completedAt.toLocal(),
            ),
            details?.interactions.length ?? 0,
          );
    final cost = isLoading ? '…' : _formatCost(context, details);
    final radius = BorderRadius.circular(tokens.radii.m);

    return Semantics(
      button: true,
      label: '$primary. $secondary. $cost',
      child: Material(
        color: tokens.colors.background.level02,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () => _showDetails(context, attribution, details),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step3,
              vertical: compact ? tokens.spacing.step2 : tokens.spacing.step3,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= WoltModalConfig.pageBreakpoint;
                return Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: tokens.spacing.step5,
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                    SizedBox(width: tokens.spacing.step3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            primary,
                            style: tokens.typography.styles.body.bodySmall
                                .copyWith(
                                  color: tokens.colors.text.highEmphasis,
                                ),
                          ),
                          SizedBox(height: tokens.spacing.step1),
                          Text(
                            secondary,
                            style: tokens.typography.styles.others.caption
                                .copyWith(
                                  color: tokens.colors.text.mediumEmphasis,
                                ),
                          ),
                          if (!wide) ...[
                            SizedBox(height: tokens.spacing.step1),
                            Text(
                              cost,
                              style: tokens.typography.styles.others.caption
                                  .copyWith(
                                    color: tokens.colors.text.mediumEmphasis,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (wide) ...[
                      SizedBox(width: tokens.spacing.step3),
                      Text(
                        cost,
                        style: tokens.typography.styles.body.bodySmall,
                      ),
                    ],
                    SizedBox(width: tokens.spacing.step2),
                    Icon(
                      Icons.chevron_right,
                      size: tokens.spacing.step5,
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showDetails(
  BuildContext context,
  AiWorkAttribution attribution,
  AiAttributionDetails? details,
) => ModalUtils.showSinglePageModal<void>(
  context: context,
  title: context.messages.aiAttributionTitle,
  modalTypeBuilderOverride: (modalContext) {
    final width = MediaQuery.sizeOf(modalContext).width;
    return width < WoltModalConfig.pageBreakpoint
        ? WoltModalType.bottomSheet()
        : const SizedWoltSideSheetType();
  },
  builder: (modalContext) => _AttributionDetailsBody(
    attribution: attribution,
    details: details,
  ),
);

class _AttributionDetailsBody extends StatelessWidget {
  const _AttributionDetailsBody({required this.attribution, this.details});

  final AiWorkAttribution attribution;
  final AiAttributionDetails? details;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final interactions = details?.interactions ?? const <AiConsumptionEvent>[];
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Detail(
            label: context.messages.aiAttributionCreator,
            value: _actorDisplayName(context, attribution.initiator),
          ),
          _Detail(
            label: context.messages.aiAttributionStatus,
            value: _statusLabel(context, attribution.status),
          ),
          _Detail(
            label: context.messages.aiAttributionCost,
            value: _formatCost(context, details),
          ),
          _Detail(
            label: context.messages.aiAttributionPrivacy,
            value: _privacyLabel(
              context,
              attribution.privacyClassification,
            ),
          ),
          _Detail(
            label: context.messages.aiAttributionExecutor,
            value: attribution.executor.displayName.trim().isEmpty
                ? context.messages.aiAttributionUnknownExecutor
                : attribution.executor.displayName,
          ),
          SizedBox(height: tokens.spacing.step3),
          Text(
            context.messages.aiAttributionInteractions,
            style: tokens.typography.styles.subtitle.subtitle2,
          ),
          SizedBox(height: tokens.spacing.step2),
          if (interactions.isEmpty)
            Text(
              context.messages.aiAttributionNoInteractionDetails,
              style: tokens.typography.styles.body.bodySmall,
            )
          else
            for (final interaction in interactions)
              Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.step2),
                child: Text(
                  context.messages.aiAttributionInteractionLine(
                    interaction.sequenceIndex + 1,
                    interaction.providerModelId ??
                        interaction.modelId ??
                        context.messages.aiAttributionUnknownModel,
                    interaction.totalTokens ?? 0,
                  ),
                  style: tokens.typography.styles.body.bodySmall,
                ),
              ),
          if (attribution.privacyClassification !=
              AiPrivacyClassification.standard) ...[
            SizedBox(height: tokens.spacing.step3),
            Text(
              context.messages.aiAttributionSensitiveContentNotice,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: tokens.typography.styles.body.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCost(BuildContext context, AiAttributionDetails? details) {
  final totals = details?.costTotals;
  if (totals == null || totals.unknownInteractionCount > 0) {
    return context.messages.aiAttributionCostUnknown;
  }
  if (totals.reportingMicrosByCurrency.isEmpty) {
    return context.messages.aiAttributionCostZero;
  }
  return totals.reportingMicrosByCurrency.entries
      .map(
        (entry) => NumberFormat.simpleCurrency(name: entry.key).format(
          entry.value / 1000000,
        ),
      )
      .join(' + ');
}

String _actorDisplayName(BuildContext context, AiActorSnapshot actor) {
  final displayName = actor.displayName.trim();
  if (displayName.isNotEmpty) return displayName;
  return actor.type == AiActorType.human
      ? context.messages.aiAttributionYou
      : context.messages.aiAttributionUnknownCreator;
}

String _triggerLabel(BuildContext context, AiTriggerType type) =>
    switch (type) {
      AiTriggerType.manual => context.messages.aiAttributionTriggerManual,
      AiTriggerType.automatic => context.messages.aiAttributionTriggerAutomatic,
      AiTriggerType.scheduled => context.messages.aiAttributionTriggerScheduled,
      AiTriggerType.synced => context.messages.aiAttributionTriggerSynced,
      AiTriggerType.agentTool => context.messages.aiAttributionTriggerAgent,
      AiTriggerType.migration => context.messages.aiAttributionTriggerImported,
    };

String _statusLabel(BuildContext context, AiWorkStatus status) =>
    switch (status) {
      AiWorkStatus.succeeded => context.messages.aiAttributionStatusSucceeded,
      AiWorkStatus.failed => context.messages.aiAttributionStatusFailed,
      AiWorkStatus.cancelled => context.messages.aiAttributionStatusCancelled,
      AiWorkStatus.abandoned => context.messages.aiAttributionStatusAbandoned,
      AiWorkStatus.partial => context.messages.aiAttributionStatusPartial,
    };

String _privacyLabel(
  BuildContext context,
  AiPrivacyClassification privacy,
) => switch (privacy) {
  AiPrivacyClassification.standard =>
    context.messages.aiAttributionPrivacyStandard,
  AiPrivacyClassification.private =>
    context.messages.aiAttributionPrivacyPrivate,
  AiPrivacyClassification.mixed => context.messages.aiAttributionPrivacyMixed,
};
