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
  const ImpactCallLedger({required this.range, super.key});

  final InsightsRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(consumptionLedgerProvider(range)).value;
    if (events == null || events.isEmpty) {
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
            for (final event in events) _LedgerRow(event: event),
            if (events.length >= kConsumptionLedgerLimit) ...[
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

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
      child: Row(
        children: [
          Icon(
            _icon,
            size: tokens.spacing.step5,
            color: tokens.colors.text.mediumEmphasis,
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
                Text(
                  '${_typeLabel(context)} · $time',
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          Text(
            _metrics(context),
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}
