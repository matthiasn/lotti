import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/ai_response_summary_modal.dart';
import 'package:lotti/features/ai/ui/generated_prompt_card.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/ai_attribution_summary.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/markdown_link_utils.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Character threshold above which a [AiResponseSummary.collapsible] response
/// starts collapsed. Markdown height is unknowable before layout, so the
/// decision is made on the raw response text — deterministic and testable.
const _collapseCharThreshold = 500;

/// Newline threshold above which a [AiResponseSummary.collapsible] response
/// starts collapsed, so many-line content (e.g. OCR of a list) collapses even
/// when it stays under [_collapseCharThreshold].
const _collapseNewlineThreshold = 6;

/// Max height of the faded preview in the legacy
/// [AiResponseSummary.fadeOut] mode (unchanged standalone-entry behavior).
const _fadeOutPreviewMaxHeight = 200.0;

/// Renders one AI response (image analysis, task summary, …) as a flat,
/// non-elevated AI surface.
///
/// Uses the tinted `aiCard` surface (`background` fill + `borderSoft` accent
/// hairline, no shadow) — the same color family as the task-agent report
/// cards, but without their accent-blended fill and badges — so a response
/// nested inside an entry card reads as recognizably AI-generated content
/// without becoming a second elevated card.
///
/// Prompt-generation responses short-circuit to [GeneratedPromptCard].
///
/// Collapse modes:
/// - [collapsible]: binary show-full-or-collapsed. Long content (by
///   [_collapseCharThreshold] / [_collapseNewlineThreshold]) starts fully
///   collapsed — no body at all, just the "Show more" toggle and the
///   attribution pill identifying the analysis. Short content renders fully
///   with no toggle.
/// - [fadeOut]: legacy always-faded preview without a toggle, used where the
///   response renders as its own journal entry detail.
///
/// Double-tap on the body opens the full response in a modal.
class AiResponseSummary extends StatefulWidget {
  const AiResponseSummary(
    this.aiResponse, {
    required this.linkedFromId,
    required this.fadeOut,
    this.collapsible = false,
    super.key,
  });

  /// Key of the "Show more"/"Show less" toggle — used for testing.
  static const collapseToggleKey = Key('ai_response_summary_collapse_toggle');

  final AiResponseEntry aiResponse;
  final String? linkedFromId;
  final bool fadeOut;
  final bool collapsible;

  @override
  State<AiResponseSummary> createState() => _AiResponseSummaryState();
}

class _AiResponseSummaryState extends State<AiResponseSummary> {
  late bool _collapsed;

  static bool _isLongContent(String text) =>
      text.length > _collapseCharThreshold ||
      '\n'.allMatches(text).length > _collapseNewlineThreshold;

  bool get _canCollapse =>
      widget.collapsible && _isLongContent(widget.aiResponse.data.response);

  @override
  void initState() {
    super.initState();
    _collapsed = _canCollapse;
  }

  @override
  void didUpdateWidget(covariant AiResponseSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-derive the default when the card is reused for different content.
    if (oldWidget.aiResponse.meta.id != widget.aiResponse.meta.id) {
      _collapsed = _canCollapse;
    }
  }

  /// Clips [content] to the legacy preview height and fades it out at the
  /// bottom (the [AiResponseSummary.fadeOut] mode).
  Widget _fadedPreview(Widget content) {
    return ShaderMask(
      shaderCallback: (rect) {
        return const LinearGradient(
          begin: Alignment.center,
          end: Alignment.bottomCenter,
          stops: [0.3, 1.0],
          colors: [
            Colors.black,
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromLTRB(0, 0, rect.width, rect.height),
        );
      },
      blendMode: BlendMode.dstIn,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _fadeOutPreviewMaxHeight),
        child: content,
      ),
    );
  }

  Widget _collapseToggle(BuildContext context, DsColorsAiCard ai) {
    final label = _collapsed
        ? context.messages.aiResponseShowMore
        : context.messages.aiResponseShowLess;
    return InkWell(
      key: AiResponseSummary.collapseToggleKey,
      onTap: () => setState(() => _collapsed = !_collapsed),
      borderRadius: BorderRadius.circular(AppTheme.spacingXSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spacingXSmall,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _collapsed ? Icons.expand_more : Icons.expand_less,
              size: 16,
              color: ai.accent,
            ),
            const SizedBox(width: AppTheme.spacingXSmall),
            Text(
              label,
              style: context.textTheme.labelMedium?.copyWith(
                color: ai.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aiResponse = widget.aiResponse;

    // Use specialized card for generated prompts (coding or image)
    if (aiResponse.data.type?.isPromptGenerationType ?? false) {
      return GeneratedPromptCard(
        aiResponse,
        linkedFromId: widget.linkedFromId,
      );
    }

    final ai = context.designTokens.colors.aiCard;

    final content = DefaultTextStyle.merge(
      style: TextStyle(color: ai.bodyText),
      child: SelectionArea(
        child: GptMarkdown(
          aiResponse.data.response,
          onLinkTap: handleMarkdownLinkTap,
        ),
      ),
    );

    final responseContent = GestureDetector(
      onDoubleTap: () {
        ModalUtils.showSinglePageModal<void>(
          context: context,
          builder: (BuildContext _) {
            return AiResponseSummaryModalContent(
              aiResponse,
              linkedFromId: widget.linkedFromId,
            );
          },
        );
      },
      child: widget.fadeOut ? _fadedPreview(content) : content,
    );

    // Binary collapse: a collapsed card carries no body at all — only the
    // toggle and the attribution pill that identifies the analysis.
    final showBody = !(_canCollapse && _collapsed);

    return Container(
      decoration: BoxDecoration(
        color: ai.background,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(color: ai.borderSoft),
      ),
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBody) responseContent,
          if (_canCollapse) _collapseToggle(context, ai),
          AiAttributionSummary(
            artifact: AiArtifactReference(
              type: AiArtifactType.journalAiResponse,
              id: aiResponse.meta.id,
            ),
            attribution: aiResponse.data.aiAttribution,
            asPill: true,
          ),
        ],
      ),
    );
  }
}
