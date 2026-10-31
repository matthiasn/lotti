import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/ai_response_card.dart';
import 'package:lotti/features/ai/ui/ai_response_summary_modal.dart';
import 'package:lotti/features/ai/ui/generated_prompt_card.dart';
import 'package:lotti/widgets/markdown/agent_markdown_view.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

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

/// Renders one AI response (image analysis, task summary, …) on the shared
/// [AiResponseCard] surface.
///
/// The body and the collapsed TLDR both render through [AgentMarkdownView]
/// (the TLDR with subordinate headings) at [AiResponseCard.bodyStyle], so an
/// analysis sits at the same measure as the entry text it belongs to rather
/// than shouting over it.
///
/// Prompt-generation responses short-circuit to [GeneratedPromptCard], which
/// renders on the same card.
///
/// Collapse modes:
/// - [collapsible]: binary show-full-or-collapsed. Long content (by
///   [_collapseCharThreshold] / [_collapseNewlineThreshold]) starts fully
///   collapsed — no body at all, just the "Show more" toggle and the
///   attribution caption identifying the analysis. Short content renders fully
///   with no toggle.
/// - [fadeOut]: legacy always-faded preview without a toggle, used where the
///   response renders as its own journal entry detail. The entry card frames
///   it there, so it renders unframed — AI text colors, no nested card.
///
/// Double-tap on the body opens the full response in a modal.
class AiResponseSummary extends StatefulWidget {
  const AiResponseSummary(
    this.aiResponse, {
    required this.fadeOut,
    this.collapsible = false,
    super.key,
  });

  final AiResponseEntry aiResponse;
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

  /// The TLDR tier, when this response published one and it is non-empty.
  ///
  /// Only summaries carry it. Its presence is what turns a collapsed card
  /// from "no body at all" into "the short version", so it is read once here
  /// rather than re-trimmed at each use.
  String? get _tldr {
    final tldr = widget.aiResponse.data.tldr?.trim();
    return (tldr == null || tldr.isEmpty) ? null : tldr;
  }

  /// A response with a TLDR is always collapsible, however short its body:
  /// the tiers exist precisely so the reader can choose the short version,
  /// and hiding the toggle on a brief summary would take that away for no
  /// gain. Everything else falls back to the length heuristic.
  bool get _canCollapse =>
      widget.collapsible &&
      (_tldr != null || _isLongContent(widget.aiResponse.data.response));

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
        // Lays the content out at its natural height and clips it, instead of
        // squeezing a multi-block markdown column into the preview height.
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: content,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aiResponse = widget.aiResponse;

    // Use specialized card for generated prompts (coding or image)
    if (aiResponse.data.type?.isPromptGenerationType ?? false) {
      return GeneratedPromptCard(aiResponse, framed: !widget.fadeOut);
    }

    final bodyStyle = AiResponseCard.bodyStyle(context);

    final content = SelectionArea(
      child: AgentMarkdownView(aiResponse.data.response, style: bodyStyle),
    );

    final responseContent = GestureDetector(
      onDoubleTap: () {
        ModalUtils.showSinglePageModal<void>(
          context: context,
          builder: (BuildContext _) {
            return AiResponseSummaryModalContent(
              aiResponse,
            );
          },
        );
      },
      child: widget.fadeOut ? _fadedPreview(content) : content,
    );

    // Collapsed rendering depends on whether the response published tiers.
    // A summary collapses to its TLDR — the tier written for exactly this
    // slot. Everything else collapses to no body at all, leaving just the
    // toggle and the attribution caption that identifies the analysis.
    final isCollapsed = _canCollapse && _collapsed;
    final tldr = _tldr;
    final Widget? body;
    if (!isCollapsed) {
      body = responseContent;
    } else if (tldr != null) {
      // The TLDR is model-written markdown just like the body — the agent
      // report card renders its TLDR the same way. Headings stay at body size:
      // a stray `#` in two sentences must not outrank the card it sits in.
      body = SelectionArea(
        child: AgentMarkdownView(
          tldr,
          style: bodyStyle,
          subordinateHeadings: true,
        ),
      );
    } else {
      body = null;
    }

    return AiResponseCard(
      aiResponse: aiResponse,
      // The faded preview is the response shown as its own entry: the entry
      // card already frames it, so only the AI text treatment remains.
      framed: !widget.fadeOut,
      body: body,
      collapsed: _canCollapse ? _collapsed : null,
      onToggleCollapsed: _canCollapse
          ? () => setState(() => _collapsed = !_collapsed)
          : null,
    );
  }
}
