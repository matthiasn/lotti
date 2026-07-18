import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/ai_consumption/logic/consumption_formatting.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/ui/widgets/insights_surfaces.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Per-call ledger for the AI Impact dashboard: the newest individual calls
/// inside the selected period, newest first — time, model, call type, tokens,
/// cost, and energy per row (the Cursor-style request table).
///
/// Watches [consumptionLedgerProvider] for the given [range] itself, so hosts
/// integrate it with a single child. Renders nothing while the first page
/// loads or when the period has no calls (the dashboard's own empty state
/// covers that); shows an explicit "newest N" caption when the page is at the
/// [kConsumptionLedgerLimit] cap, so truncation is never silent.
class ImpactCallLedger extends ConsumerWidget {
  const ImpactCallLedger({
    required this.range,
    this.modelFilter,
    this.categoryFilter,
    super.key,
  });

  final InsightsRange range;

  /// When set, keep only calls made with this provider/model id — the ledger
  /// follows an isolated model so "which calls drove this" is answerable.
  final String? modelFilter;

  /// When set, keep only calls attributed to this category id.
  final String? categoryFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(consumptionLedgerProvider(range)).value;
    if (all == null) return const SizedBox.shrink();
    final events = all.where((e) {
      if (modelFilter != null &&
          (e.providerModelId ?? e.modelId) != modelFilter) {
        return false;
      }
      if (categoryFilter != null && e.categoryId != categoryFilter) {
        return false;
      }
      return true;
    }).toList();
    if (events.isEmpty) {
      return const SizedBox.shrink();
    }
    final tokens = context.designTokens;
    final messages = context.messages;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: insightsCardSurface(context),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              messages.aiConsumptionLedgerTitle,
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.cardItemSpacing),
            for (final group in _groupEvents(events))
              if (group.attributionId == null)
                _LedgerRow(event: group.events.single)
              else
                _AttributionLedgerGroup(group: group),
            // Gate the truncation notice on the unfiltered fetch: a series
            // filter shrinks `events` but the cap was applied to `all`, so a
            // capped-then-filtered list must still disclose the truncation.
            if (all.length >= kConsumptionLedgerLimit) ...[
              SizedBox(height: tokens.spacing.cardItemSpacing),
              Text(
                messages.aiConsumptionLedgerCap(kConsumptionLedgerLimit),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LedgerGroup {
  const _LedgerGroup({required this.attributionId, required this.events});

  final String? attributionId;
  final List<AiConsumptionEvent> events;
}

List<_LedgerGroup> _groupEvents(List<AiConsumptionEvent> events) {
  final groups = <String, List<AiConsumptionEvent>>{};
  final orderedKeys = <String>[];
  for (final event in events) {
    final key = event.attributionId ?? 'legacy:${event.id}';
    if (!groups.containsKey(key)) orderedKeys.add(key);
    groups.putIfAbsent(key, () => []).add(event);
  }
  return [
    for (final key in orderedKeys)
      _LedgerGroup(
        attributionId: key.startsWith('legacy:') ? null : key,
        events: groups[key]!,
      ),
  ];
}

class _AttributionLedgerGroup extends StatelessWidget {
  const _AttributionLedgerGroup({required this.group});

  final _LedgerGroup group;

  String _metrics(BuildContext context) {
    final totalTokens = group.events.fold<int>(
      0,
      (sum, event) => sum + (event.totalTokens ?? 0),
    );
    final credits = group.events.fold<double>(
      0,
      (sum, event) => sum + (event.credits ?? 0),
    );
    final energy = group.events.fold<double>(
      0,
      (sum, event) => sum + (event.energyKwh ?? 0),
    );
    final parts = <String>[
      if (group.events.any((event) => event.totalTokens != null))
        context.messages.aiConsumptionTokensLabel(
          formatTokenCount(totalTokens),
        ),
      if (group.events.any((event) => event.credits != null))
        formatCredits(credits),
      if (group.events.any((event) => event.energyKwh != null))
        formatEnergyKwh(energy),
    ];
    return parts.isEmpty
        ? context.messages.aiConsumptionMetricsNotReported
        : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final attributionId = group.attributionId!;
    final shortId = attributionId.length > 12
        ? attributionId.substring(0, 12)
        : attributionId;
    final metrics = _metrics(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < _kLedgerStackedMaxWidth;
        return Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.only(left: tokens.spacing.step5),
            leading: Icon(
              Icons.auto_awesome_outlined,
              color: tokens.colors.text.mediumEmphasis,
            ),
            title: Text(
              context.messages.aiConsumptionWorkGroup(group.events.length),
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.messages.aiConsumptionAttributionReference(shortId),
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
                if (stacked)
                  Text(
                    metrics,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
              ],
            ),
            trailing: stacked
                ? null
                : Text(
                    metrics,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
            children: [
              for (final event in group.events) _LedgerRow(event: event),
            ],
          ),
        );
      },
    );
  }
}

/// Below this row width the trailing metric string would squeeze the model
/// name into an ellipsis, so the row stacks instead (model on its own line).
const double _kLedgerStackedMaxWidth = 480;

/// One call: type icon · model + type/time line · trailing metrics.
class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.event});

  final AiConsumptionEvent event;

  IconData get _icon => switch (event.responseType) {
    AiConsumptionResponseType.agentTurn => Icons.smart_toy_outlined,
    AiConsumptionResponseType.textGeneration => Icons.notes_outlined,
    AiConsumptionResponseType.audioTranscription => Icons.mic_outlined,
    AiConsumptionResponseType.imageAnalysis => Icons.image_search_outlined,
    AiConsumptionResponseType.imageGeneration => Icons.brush_outlined,
    AiConsumptionResponseType.promptGeneration => Icons.edit_note_outlined,
    AiConsumptionResponseType.embeddingIndexing => Icons.hub_outlined,
  };

  String _typeLabel(BuildContext context) {
    final messages = context.messages;
    return switch (event.responseType) {
      AiConsumptionResponseType.agentTurn =>
        messages.aiConsumptionTypeAgentTurn,
      AiConsumptionResponseType.textGeneration =>
        messages.aiConsumptionTypeTextGeneration,
      AiConsumptionResponseType.audioTranscription =>
        messages.aiConsumptionTypeAudioTranscription,
      AiConsumptionResponseType.imageAnalysis =>
        messages.aiConsumptionTypeImageAnalysis,
      AiConsumptionResponseType.imageGeneration =>
        messages.aiConsumptionTypeImageGeneration,
      AiConsumptionResponseType.promptGeneration =>
        messages.aiConsumptionTypePromptGeneration,
      AiConsumptionResponseType.embeddingIndexing =>
        messages.aiConsumptionTypeEmbeddingIndexing,
    };
  }

  /// Trailing metric summary: tokens always (when reported), then cost and
  /// energy for measured (Melious) calls. Parts absent from the row are
  /// simply omitted rather than rendered as zeros.
  String _metrics(BuildContext context) {
    final parts = <String>[
      if (event.totalTokens != null && event.totalTokens! > 0)
        context.messages.aiConsumptionTokensLabel(
          formatTokenCount(event.totalTokens!),
        ),
      if (event.credits != null) formatCredits(event.credits!),
      if (event.energyKwh != null) formatEnergyKwh(event.energyKwh!),
    ];
    if (parts.isEmpty) return context.messages.aiConsumptionMetricsNotReported;
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toString();
    // toLocal(): locally captured events already carry wall time, but a
    // UTC-stamped event (e.g. from a future capture path) must render in the
    // viewer's timezone, not as raw UTC digits.
    final time = DateFormat.MMMd(
      locale,
    ).add_Hm().format(event.createdAt.toLocal());
    final model = event.providerModelId ?? event.modelId ?? '—';

    final modelText = Text(
      model,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: tokens.typography.styles.body.bodySmall.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
    );
    final subtitleText = Text(
      '${_typeLabel(context)} · $time',
      style: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.lowEmphasis,
      ),
    );
    final metricsText = Text(
      _metrics(context),
      style: tokens.typography.styles.body.bodySmall.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final icon = Icon(
            _icon,
            size: tokens.spacing.step5,
            color: tokens.colors.text.mediumEmphasis,
          );

          // Narrow: the model version owns the first line at full width, with
          // the type/time subtitle and the metric string on the line below —
          // so the identifying field is never the one that truncates.
          if (constraints.maxWidth < _kLedgerStackedMaxWidth) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                SizedBox(width: tokens.spacing.step3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      modelText,
                      SizedBox(height: tokens.spacing.step1),
                      subtitleText,
                      SizedBox(height: tokens.spacing.step1),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: metricsText,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          // Wide: model + subtitle on the left, metric string trailing right.
          return Row(
            children: [
              icon,
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [modelText, subtitleText],
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              metricsText,
            ],
          );
        },
      ),
    );
  }
}
