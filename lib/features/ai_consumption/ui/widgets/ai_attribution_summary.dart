import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/ai_attribution.dart';
import 'package:lotti/classes/ai_consumption/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/logic/consumption_formatting.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/device_datetime.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/modal/side_sheet.dart';
import 'package:material_ui/material_ui.dart';

/// Says who produced an AI output, and opens the full attribution on tap.
///
/// As a pill it is provenance first: the model that ran, then the cost and
/// impact when the provider reported them. It shows for every attributed
/// output, priced or not — a local model or a speech-to-text engine that
/// bills nothing still did the work, and the pill is the way to find out who.
class AiAttributionSummary extends ConsumerWidget {
  const AiAttributionSummary({
    required this.artifact,
    this.attribution,
    this.compact = false,
    this.asPill = false,
    this.includeTopSpacing = true,
    this.unrecordedModel,
    super.key,
  });

  final AiArtifactReference artifact;
  final AiWorkAttribution? attribution;
  final bool compact;
  final bool asPill;
  final bool includeTopSpacing;

  /// The model the output itself names, for an output made before
  /// attribution was recorded. When no attribution resolves, the pill shows
  /// this model and says that nothing more was recorded, instead of
  /// disappearing; null renders nothing, as before.
  final String? unrecordedModel;

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
      final model = unrecordedModel;
      if (model == null) return const SizedBox.shrink();
      return _withTopSpacing(context, _UnrecordedPill(model: model));
    }
    final row = _AttributionRow(
      attribution: resolvedAttribution,
      details: details,
      compact: compact,
      asPill: asPill,
      isLoading: asyncDetails.isLoading && details == null,
    );
    return _withTopSpacing(context, row);
  }

  Widget _withTopSpacing(BuildContext context, Widget child) {
    if (!includeTopSpacing) return child;
    return Padding(
      padding: EdgeInsets.only(top: context.designTokens.spacing.step3),
      child: child,
    );
  }
}

/// The pill of an output that predates attribution: the model it names, and
/// that nothing more is known. Not tappable — there is no record to open.
class _UnrecordedPill extends StatelessWidget {
  const _UnrecordedPill({required this.model});

  final String model;

  @override
  Widget build(BuildContext context) {
    final label = '$model · ${context.messages.aiAttributionNotRecorded}';
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: DsPill(
          variant: DsPillVariant.filled,
          bordered: true,
          label: label,
          leading: Icon(
            LottiIcons.aiSpark,
            size: 12,
            color: context.designTokens.colors.text.mediumEmphasis,
          ),
        ),
      ),
    );
  }
}

/// A single entry-level pill for several AI outputs of the same kind.
///
/// Audio entries can contain more than one transcript, each with its own
/// attribution. This keeps the card surface concise while retaining every
/// individual attribution in the details sheet. Like a single pill it shows
/// whenever there is an attribution, with the cost only when one was
/// reported. It renders nothing without attributions — [topSpacing]
/// included, so a caller hands the gap above it here rather than leaving it
/// behind an empty pill.
class AiAttributionSummaryGroup extends ConsumerWidget {
  const AiAttributionSummaryGroup({
    required this.label,
    required this.attributions,
    this.topSpacing,
    super.key,
  });

  final String label;
  final List<AiWorkAttribution> attributions;

  /// Gap above the pill, rendered only with it.
  final double? topSpacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (attributions.isEmpty) return const SizedBox.shrink();

    final asyncDetails = [
      for (final attribution in attributions)
        ref.watch(aiAttributionDetailsProvider(attribution.id)),
    ];
    final details = asyncDetails
        .map((asyncDetail) => asyncDetail.value)
        .whereType<AiAttributionDetails>()
        .toList();
    final isLoading = asyncDetails.any(
      (asyncDetail) => asyncDetail.isLoading && asyncDetail.value == null,
    );
    final interactions = details.expand((detail) => detail.interactions);
    final cost = isLoading
        ? '…'
        : _formatInteractionCosts(context, interactions);
    final tokens = context.designTokens;
    final pill = Semantics(
      button: !isLoading,
      label: '$label. $cost',
      child: DsPill(
        variant: DsPillVariant.filled,
        bordered: true,
        label: isLoading
            ? '$label · $cost'
            : _formatPillLabel(
                context,
                prefix: label,
                interactions: interactions,
              ),
        leading: Icon(
          LottiIcons.aiSpark,
          size: 12,
          color: tokens.colors.text.mediumEmphasis,
        ),
        onTap: isLoading
            ? null
            : () => _showGroupDetails(context, label, details),
      ),
    );
    final gap = topSpacing;
    if (gap == null) return pill;
    return Padding(
      padding: EdgeInsets.only(top: gap),
      child: pill,
    );
  }
}

/// Whether any of [interactions] reported what it cost.
bool _hasKnownCost(Iterable<AiConsumptionEvent> interactions) =>
    interactions.any((event) => event.credits != null);

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
          label: isLoading
              ? '$model · $cost'
              : _formatPillLabel(
                  context,
                  prefix: model,
                  interactions: details?.interactions ?? const [],
                ),
          leading: Icon(
            LottiIcons.aiSpark,
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
                  LottiIcons.aiSpark,
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
                  LottiIcons.chevronRight,
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
  modalTypeBuilderOverride: sideSheetModalType,
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

Future<void> _showGroupDetails(
  BuildContext context,
  String label,
  List<AiAttributionDetails> details,
) => ModalUtils.showSinglePageModal<void>(
  context: context,
  title: context.messages.aiAttributionTitle,
  modalTypeBuilderOverride: sideSheetModalType,
  builder: (modalContext) => _AttributionGroupDetailsBody(
    label: label,
    details: details,
  ),
);

class _AttributionGroupDetailsBody extends StatelessWidget {
  const _AttributionGroupDetailsBody({
    required this.label,
    required this.details,
  });

  final String label;
  final List<AiAttributionDetails> details;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Detail(
            label: label,
            value: _formatInteractionCosts(
              context,
              details.expand((detail) => detail.interactions),
            ),
          ),
          for (final detail in details)
            _AttributionDetailsBody(details: detail),
        ],
      ),
    );
  }
}

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
          _AttributionSources(attribution: attribution),
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

/// Who stood behind the work — the agent, profile and skill that ran it and
/// the task it belongs to — each opening its own page where it has one.
///
/// Names come from the attribution's own snapshot, so they read as they did
/// when the work ran; ids are what the links navigate by. A row is left out
/// when the attribution does not name it, and the section with them.
class _AttributionSources extends ConsumerWidget {
  const _AttributionSources({required this.attribution});

  final AiWorkAttribution attribution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    final trigger = attribution.trigger;
    final taskId = attribution.taskId;
    final agentId = trigger.agentId;
    final profileId = trigger.profileId;
    final skillName = trigger.skillName;
    final rows = <Widget>[
      if (agentId != null)
        _LinkDetail(
          key: const ValueKey('ai-attribution-source-agent'),
          label: messages.aiAttributionAgent,
          value: trigger.agentName ?? agentId,
          route: '/settings/agents/instances/$agentId',
        ),
      if (profileId != null)
        _LinkDetail(
          key: const ValueKey('ai-attribution-source-profile'),
          label: messages.aiAttributionProfile,
          value: trigger.profileName ?? profileId,
          route: '/settings/ai/profile/$profileId',
        ),
      if (skillName != null)
        _Detail(label: messages.aiAttributionSkill, value: skillName),
      if (taskId != null)
        _LinkDetail(
          key: const ValueKey('ai-attribution-source-task'),
          label: messages.aiAttributionTask,
          value:
              ref.watch(aiAttributionTaskTitleProvider(taskId)).value ??
              messages.aiAttributionOpenTask,
          route: '/tasks/$taskId',
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SectionHeading(messages.aiAttributionSource),
          SizedBox(height: tokens.spacing.step2),
          ...rows,
        ],
      ),
    );
  }
}

/// A [_Detail] whose value opens [route], closing the sheet on the way so
/// the page it opens is not left behind it.
class _LinkDetail extends StatelessWidget {
  const _LinkDetail({
    required this.label,
    required this.value,
    required this.route,
    super.key,
  });

  final String label;
  final String value;
  final String route;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = tokens.colors.interactive.enabled;
    void open() {
      Navigator.of(context).maybePop();
      beamToNamed(route);
    }

    // The semantics node carries the tap itself: ExcludeSemantics drops the
    // InkWell's action, and a link a screen reader cannot follow is no link.
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step2),
      child: Semantics(
        link: true,
        label: '$label: $value',
        onTap: open,
        child: ExcludeSemantics(
          child: InkWell(
            borderRadius: BorderRadius.circular(tokens.radii.s),
            onTap: open,
            // Centred, unlike a plain detail row: the trailing chevron is
            // shorter than a line of text and reads as superscript at the top.
            child: Row(
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
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: color,
                    ),
                  ),
                ),
                Icon(
                  LottiIcons.chevronRight,
                  size: tokens.spacing.step4,
                  color: color,
                ),
              ],
            ),
          ),
        ),
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
            if (_hasTokenBreakdown(interaction))
              _FullWidthDetail(
                text: context.messages.aiAttributionTokenBreakdown(
                  _formatTokenMetric(interaction.inputTokens),
                  _formatTokenMetric(interaction.outputTokens),
                  _formatTokenMetric(interaction.cachedInputTokens),
                  _formatTokenMetric(interaction.thoughtsTokens),
                ),
              ),
            _Detail(
              label: context.messages.aiAttributionCost,
              value: _formatInteractionCost(context, interaction),
            ),
            if (_hasImpact(interaction))
              _FullWidthDetail(
                text: context.messages.aiConsumptionImpactLine(
                  _formatImpactMetric(
                    interaction.energyKwh,
                    formatEnergyKwh,
                  ),
                  _formatImpactMetric(
                    interaction.carbonGCo2,
                    formatCarbonGrams,
                  ),
                  _formatImpactMetric(
                    interaction.waterLiters,
                    formatWaterLiters,
                  ),
                ),
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

class _FullWidthDetail extends StatelessWidget {
  const _FullWidthDetail({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: context.designTokens.spacing.step2),
    child: Text(
      text,
      style: context.designTokens.typography.styles.body.bodySmall,
    ),
  );
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
) => _formatInteractionCosts(context, details?.interactions ?? const []);

String _formatInteractionCosts(
  BuildContext context,
  Iterable<AiConsumptionEvent> interactions,
) {
  final values = interactions.map((event) => event.credits).whereType<double>();
  if (values.isEmpty) return context.messages.aiAttributionCostUnknown;
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

String _formatPillLabel(
  BuildContext context, {
  required String prefix,
  required Iterable<AiConsumptionEvent> interactions,
}) {
  final values = interactions.toList();
  // A cost nobody reported is left out rather than spelled "Cost unknown" on
  // every free or unbilled output; the details sheet still says so.
  final parts = [
    prefix,
    if (_hasKnownCost(values)) _formatInteractionCosts(context, values),
  ];
  final energy = values
      .map((interaction) => interaction.energyKwh)
      .whereType<double>();
  if (energy.isNotEmpty) {
    parts.add(formatEnergyKwh(energy.fold(0, (sum, value) => sum + value)));
  }
  final carbon = values
      .map((interaction) => interaction.carbonGCo2)
      .whereType<double>();
  if (carbon.isNotEmpty) {
    parts.add(formatCarbonGrams(carbon.fold(0, (sum, value) => sum + value)));
  }
  return parts.join(' · ');
}

bool _hasImpact(AiConsumptionEvent interaction) =>
    interaction.energyKwh != null ||
    interaction.carbonGCo2 != null ||
    interaction.waterLiters != null;

bool _hasTokenBreakdown(AiConsumptionEvent interaction) =>
    interaction.inputTokens != null ||
    interaction.outputTokens != null ||
    interaction.cachedInputTokens != null ||
    interaction.thoughtsTokens != null;

String _formatTokenMetric(int? value) =>
    value == null ? '—' : NumberFormat.decimalPattern().format(value);

String _formatImpactMetric(
  double? value,
  String Function(double value) formatter,
) => value == null ? '—' : formatter(value);

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
    deviceTimestampLabel(context, timestamp);

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
