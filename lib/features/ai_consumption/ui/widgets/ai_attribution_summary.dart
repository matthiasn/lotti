import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/ai_consumption/logic/attribution_cost.dart';
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
    if (attribution == null) {
      if (asyncDetails.isLoading) {
        return _AttributionAvailability(
          label: context.messages.aiAttributionLoading,
          showProgress: true,
        );
      }
      if (asyncDetails.hasError) {
        return _AttributionAvailability(
          label: context.messages.aiAttributionUnavailable,
        );
      }
      return const SizedBox.shrink();
    }
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

class _AttributionAvailability extends StatelessWidget {
  const _AttributionAvailability({
    required this.label,
    this.showProgress = false,
  });

  final String label;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Semantics(
      liveRegion: true,
      label: label,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step3),
        child: Row(
          children: [
            if (showProgress) ...[
              SizedBox.square(
                dimension: tokens.spacing.step4,
                child: const CircularProgressIndicator(),
              ),
              SizedBox(width: tokens.spacing.step2),
            ],
            Expanded(
              child: Text(
                label,
                style: tokens.typography.styles.body.bodySmall,
              ),
            ),
          ],
        ),
      ),
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
            DateFormat.yMMMd(
              Localizations.localeOf(context).toString(),
            ).add_jm().format(
              attribution.completedAt.toLocal(),
            ),
            details?.interactions.length ?? 0,
          );
    final cost = isLoading ? '…' : _formatCost(context, details);
    final radius = BorderRadius.circular(tokens.radii.m);

    return Semantics(
      button: !isLoading,
      label: '$primary. $secondary. $cost',
      child: Material(
        color: tokens.colors.background.level02,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: isLoading
              ? null
              : () => _showDetails(context, attribution, details),
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
  builder: (modalContext) => Consumer(
    builder: (context, ref, child) {
      final live = ref.watch(aiAttributionDetailsProvider(attribution.id));
      final liveDetails = live.value ?? details;
      if (liveDetails != null) {
        return _AttributionDetailsBody(
          attribution: liveDetails.attribution,
          details: liveDetails,
        );
      }
      return _AttributionAvailability(
        label: live.hasError
            ? context.messages.aiAttributionUnavailable
            : context.messages.aiAttributionLoading,
        showProgress: !live.hasError,
      );
    },
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
    final duration = attribution.completedAt.difference(attribution.startedAt);
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
            label: context.messages.aiAttributionTrigger,
            value: _triggerLabel(context, attribution.trigger.type),
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
          _Detail(
            label: context.messages.aiAttributionDuration,
            value: _formatDuration(duration),
          ),
          _Detail(
            label: context.messages.aiAttributionStartedAt,
            value: _formatTimestamp(context, attribution.startedAt),
          ),
          _Detail(
            label: context.messages.aiAttributionCompletedAt,
            value: _formatTimestamp(context, attribution.completedAt),
          ),
          SizedBox(height: tokens.spacing.step3),
          _SectionHeading(context.messages.aiAttributionArtifacts),
          SizedBox(height: tokens.spacing.step2),
          if (attribution.links.isEmpty)
            Text(
              context.messages.aiAttributionNoInteractionDetails,
              style: tokens.typography.styles.body.bodySmall,
            )
          else
            for (final link in attribution.links)
              _Detail(
                label: _artifactRoleLabel(context, link.role),
                value:
                    '${link.artifact.type.name}: ${link.artifact.id}'
                    '${link.artifact.subId == null ? '' : ' / ${link.artifact.subId}'}',
                selectable: true,
              ),
          SizedBox(height: tokens.spacing.step3),
          _SectionHeading(context.messages.aiAttributionInteractions),
          SizedBox(height: tokens.spacing.step2),
          if (interactions.isEmpty)
            Text(
              context.messages.aiAttributionNoInteractionDetails,
              style: tokens.typography.styles.body.bodySmall,
            )
          else
            for (final interaction in interactions)
              _InteractionDetails(
                interaction: interaction,
                cost: _effectiveCost(details, interaction.id),
              ),
          if (attribution.privacyClassification ==
                  AiPrivacyClassification.private ||
              attribution.privacyClassification ==
                  AiPrivacyClassification.mixed) ...[
            SizedBox(height: tokens.spacing.step3),
            Text(
              context.messages.aiAttributionSensitiveContentNotice,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ],
          SizedBox(height: tokens.spacing.step3),
          _SectionHeading(context.messages.aiAttributionDiagnostics),
          SizedBox(height: tokens.spacing.step2),
          SelectableText(
            attribution.id,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.designTokens.typography.styles.subtitle.subtitle2,
  );
}

class _InteractionDetails extends StatelessWidget {
  const _InteractionDetails({required this.interaction, required this.cost});

  final AiConsumptionEvent interaction;
  final AiInteractionCost? cost;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final model =
        interaction.providerModelId ??
        interaction.modelId ??
        context.messages.aiAttributionUnknownModel;
    final tokenText = interaction.totalTokens == null
        ? context.messages.aiAttributionTokenUsageUnknown
        : NumberFormat.decimalPattern(
            Localizations.localeOf(context).toString(),
          ).format(interaction.totalTokens);
    final payload = interaction.payload;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step2),
      child: Material(
        color: tokens.colors.background.level03,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          title: Text(
            '${interaction.sequenceIndex + 1}. $model',
            style: tokens.typography.styles.body.bodySmall,
          ),
          subtitle: Text(
            '${interaction.providerType.name} · '
            '${_interactionStatusLabel(context, interaction.interactionStatus)}',
            style: tokens.typography.styles.others.caption,
          ),
          childrenPadding: EdgeInsets.all(tokens.spacing.step3),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Detail(
              label: context.messages.aiAttributionStatus,
              value: _interactionStatusLabel(
                context,
                interaction.interactionStatus,
              ),
            ),
            _Detail(
              label: context.messages.aiAttributionDuration,
              value: interaction.durationMs == null
                  ? context.messages.aiAttributionUnavailable
                  : _formatDuration(
                      Duration(milliseconds: interaction.durationMs!),
                    ),
            ),
            _Detail(
              label: context.messages.aiAttributionStartedAt,
              value: _formatTimestamp(context, interaction.createdAt),
            ),
            if (interaction.completedAt != null)
              _Detail(
                label: context.messages.aiAttributionCompletedAt,
                value: _formatTimestamp(context, interaction.completedAt!),
              ),
            _Detail(
              label: context.messages.aiAttributionTokens,
              value: tokenText,
            ),
            _Detail(
              label: context.messages.aiAttributionCost,
              value: _formatAssessmentCost(context, cost),
            ),
            _Detail(
              label: context.messages.aiAttributionCostSource,
              value: _costSourceLabel(context, cost?.source),
            ),
            if (payload != null) ...[
              _Detail(
                label: context.messages.aiAttributionRequestEvidence,
                value: payload.requestDigest,
                selectable: true,
              ),
              _Detail(
                label: context.messages.aiAttributionResponseEvidence,
                value: payload.responseDigest,
                selectable: true,
              ),
            ],
            if (interaction.providerRequestId != null)
              SelectableText(
                interaction.providerRequestId!,
                style: tokens.typography.styles.others.caption,
              ),
            SelectableText(
              interaction.id,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

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
            child: selectable
                ? SelectableText(
                    value,
                    textAlign: TextAlign.end,
                    style: tokens.typography.styles.body.bodySmall,
                  )
                : Text(
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
  if (totals == null ||
      (totals.knownInteractionCount == 0 &&
          totals.reportingMicrosByCurrency.isEmpty)) {
    return context.messages.aiAttributionCostUnknown;
  }
  final known = totals.reportingMicrosByCurrency.entries
      .map(
        (entry) => NumberFormat.simpleCurrency(
          name: entry.key,
          locale: Localizations.localeOf(context).toString(),
        ).format(entry.value / 1000000),
      )
      .join(' + ');
  if (known.isEmpty) return context.messages.aiAttributionCostUnknown;
  return totals.unknownInteractionCount == 0
      ? known
      : '$known · ${context.messages.aiAttributionSomeCallsUnknown}';
}

AiInteractionCost? _effectiveCost(
  AiAttributionDetails? details,
  String interactionId,
) {
  if (details == null) return null;
  try {
    return effectiveInteractionCost(
      details.costAssessments.where(
        (assessment) => assessment.interactionId == interactionId,
      ),
    );
  } on InvalidAiCostEvidence {
    return null;
  }
}

String _formatAssessmentCost(
  BuildContext context,
  AiInteractionCost? cost,
) {
  final micros = cost?.reportingAmountMicros;
  final currency = cost?.reportingCurrency;
  if (micros == null || currency == null) {
    return context.messages.aiAttributionCostUnknown;
  }
  return NumberFormat.simpleCurrency(
    name: currency,
    locale: Localizations.localeOf(context).toString(),
  ).format(micros / 1000000);
}

String _costSourceLabel(
  BuildContext context,
  AiCostSource? source,
) => switch (source) {
  AiCostSource.localCompute => context.messages.aiAttributionCostSourceLocal,
  AiCostSource.locallyEstimated =>
    context.messages.aiAttributionCostSourceEstimated,
  AiCostSource.legacyReported => context.messages.aiAttributionCostSourceLegacy,
  AiCostSource.providerReported =>
    context.messages.aiAttributionCostSourceProvider,
  AiCostSource.externallyReconciled =>
    context.messages.aiAttributionCostSourceReconciled,
  AiCostSource.unknown || null => context.messages.aiAttributionCostUnknown,
};

String _artifactRoleLabel(
  BuildContext context,
  AiAttributionLinkRole role,
) => switch (role) {
  AiAttributionLinkRole.output => context.messages.aiAttributionArtifactOutput,
  AiAttributionLinkRole.source => context.messages.aiAttributionArtifactSource,
  AiAttributionLinkRole.context =>
    context.messages.aiAttributionArtifactContext,
};

String _interactionStatusLabel(
  BuildContext context,
  AiInteractionStatus status,
) => switch (status) {
  AiInteractionStatus.succeeded =>
    context.messages.aiAttributionStatusSucceeded,
  AiInteractionStatus.failed => context.messages.aiAttributionStatusFailed,
  AiInteractionStatus.cancelled =>
    context.messages.aiAttributionStatusCancelled,
  AiInteractionStatus.partial => context.messages.aiAttributionStatusPartial,
};

String _formatDuration(Duration duration) => duration.inSeconds == 0
    ? duration.toString()
    : duration.toString().split('.').first;

String _formatTimestamp(BuildContext context, DateTime timestamp) =>
    DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).add_jm().format(timestamp.toLocal());

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
  AiPrivacyClassification.unknown =>
    context.messages.aiAttributionPrivacyUnknown,
};
