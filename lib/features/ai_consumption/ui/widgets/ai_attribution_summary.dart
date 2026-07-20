import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/ai_consumption/logic/consumption_formatting.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/modal/sized_wolt_side_sheet_type.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class AiAttributionSummary extends ConsumerWidget {
  const AiAttributionSummary({
    required this.artifact,
    this.attribution,
    this.compact = false,
    this.asPill = false,
    this.includeTopSpacing = true,
    super.key,
  });

  final AiArtifactReference artifact;
  final AiWorkAttribution? attribution;
  final bool compact;
  final bool asPill;
  final bool includeTopSpacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetails = attribution == null
        ? ref.watch(aiAttributionForArtifactProvider(artifact))
        : ref.watch(aiAttributionDetailsProvider(attribution!.id));
    final details = asyncDetails.value;
    final resolvedAttribution = details?.attribution ?? attribution;
    if (resolvedAttribution == null) {
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
      attribution: resolvedAttribution,
      details: details,
      compact: compact,
      asPill: asPill,
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
    required this.asPill,
    required this.isLoading,
  });

  final AiWorkAttribution attribution;
  final AiAttributionDetails? details;
  final bool compact;
  final bool asPill;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final primary = context.messages.aiAttributionSummary(
      _actorDisplayName(context, attribution.initiator),
      _triggerLabel(context, attribution.trigger.type),
      _statusLabel(context, attribution.status),
    );
    final secondary = isLoading
        ? '…'
        : context.messages.aiAttributionSecondary(
            _firstModel(details) ?? context.messages.aiAttributionUnknownModel,
            _formatTimestamp(context, attribution.completedAt),
            details?.interactions.length ?? 0,
          );
    final cost = isLoading ? '…' : _formatTotalCost(context, details);
    if (asPill) {
      final model = isLoading
          ? '…'
          : _firstModel(details) ?? context.messages.aiAttributionUnknownModel;
      return Semantics(
        button: !isLoading,
        label: '$primary. $model. $cost',
        child: DsPill(
          variant: DsPillVariant.filled,
          bordered: true,
          label: '$model · $cost',
          leading: Icon(
            Icons.auto_awesome_outlined,
            size: 12,
            color: tokens.colors.text.mediumEmphasis,
          ),
          onTap: isLoading
              ? null
              : () => _showDetails(context, attribution, details),
        ),
      );
    }
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
            child: Row(
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
                        style: tokens.typography.styles.body.bodySmall,
                      ),
                      SizedBox(height: tokens.spacing.step1),
                      Text(
                        '$secondary · $cost',
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: tokens.spacing.step2),
                Icon(
                  Icons.chevron_right,
                  size: tokens.spacing.step5,
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ],
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
        return _AttributionDetailsBody(details: liveDetails);
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
  const _AttributionDetailsBody({required this.details});

  final AiAttributionDetails details;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final attribution = details.attribution;
    final output = attribution.primaryOutput;
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
            value: _formatTotalCost(context, details),
          ),
          _Detail(
            label: context.messages.aiAttributionDuration,
            value: _formatDuration(
              attribution.completedAt.difference(attribution.startedAt),
            ),
          ),
          _Detail(
            label: context.messages.aiAttributionStartedAt,
            value: _formatTimestamp(context, attribution.startedAt),
          ),
          _Detail(
            label: context.messages.aiAttributionCompletedAt,
            value: _formatTimestamp(context, attribution.completedAt),
          ),
          if (output != null)
            _Detail(
              label: context.messages.aiAttributionArtifactOutput,
              value:
                  '${output.type.name}: ${output.id}'
                  '${output.subId == null ? '' : ' / ${output.subId}'}',
              selectable: true,
            ),
          SizedBox(height: tokens.spacing.step3),
          _SectionHeading(context.messages.aiAttributionInteractions),
          SizedBox(height: tokens.spacing.step2),
          if (details.interactions.isEmpty)
            Text(
              context.messages.aiAttributionNoInteractionDetails,
              style: tokens.typography.styles.body.bodySmall,
            )
          else
            for (final interaction in details.interactions)
              _InteractionDetails(interaction: interaction),
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
  const _InteractionDetails({required this.interaction});

  final AiConsumptionEvent interaction;

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
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step2),
      child: Material(
        color: tokens.colors.background.level03,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          title: Text(
            model,
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
              label: context.messages.aiAttributionTokens,
              value: tokenText,
            ),
            _Detail(
              label: context.messages.aiAttributionCost,
              value: _formatInteractionCost(context, interaction),
            ),
            if (interaction.requestDigest != null)
              _Detail(
                label: context.messages.aiAttributionRequestEvidence,
                value: interaction.requestDigest!,
                selectable: true,
              ),
            if (interaction.responseDigest != null)
              _Detail(
                label: context.messages.aiAttributionResponseEvidence,
                value: interaction.responseDigest!,
                selectable: true,
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

String? _firstModel(AiAttributionDetails? details) {
  for (final event in details?.interactions ?? const <AiConsumptionEvent>[]) {
    final model = event.providerModelId ?? event.modelId;
    if (model != null) return model;
  }
  return null;
}

String _formatTotalCost(
  BuildContext context,
  AiAttributionDetails? details,
) {
  final values = details?.interactions
      .map((event) => event.credits)
      .whereType<double>();
  if (values == null || values.isEmpty) {
    return context.messages.aiAttributionCostUnknown;
  }
  final total = values.fold<double>(0, (sum, value) => sum + value);
  return formatCredits(total);
}

String _formatInteractionCost(
  BuildContext context,
  AiConsumptionEvent interaction,
) {
  final credits = interaction.credits;
  return credits == null
      ? context.messages.aiAttributionCostUnknown
      : formatCredits(credits);
}

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
      AiWorkStatus.partial => context.messages.aiAttributionStatusPartial,
    };
