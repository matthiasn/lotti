import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/ai_response_summary_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Specialized card for displaying AI-generated prompts (coding or image).
///
/// Features:
/// - Brief summary visible by default
/// - Prominent copy button
/// - Expandable full prompt view
/// - Read-only (no editing)
/// - Supports both promptGeneration and imagePromptGeneration types
class GeneratedPromptCard extends StatefulWidget {
  const GeneratedPromptCard(
    this.aiResponse, {
    required this.linkedFromId,
    super.key,
  });

  final AiResponseEntry aiResponse;
  final String? linkedFromId;

  // Static regex patterns compiled once for performance.
  // Public so they can be reused by other widgets (e.g., UnifiedAiProgressView).
  static final summarySectionRegex = RegExp(
    r'##\s*Summary\s*\n+([\s\S]*?)(?=##\s*Prompt|$)',
    caseSensitive: false,
  );
  static final promptSectionRegex = RegExp(
    r'##\s*Prompt\s*\n+([\s\S]*)',
    caseSensitive: false,
  );

  @override
  State<GeneratedPromptCard> createState() => _GeneratedPromptCardState();
}

class _GeneratedPromptCardState extends State<GeneratedPromptCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;
  late String _summary;
  late String _fullPrompt;

  /// Returns true if this is an image prompt generation response
  bool get _isImagePrompt =>
      widget.aiResponse.data.type == AiResponseType.imagePromptGeneration;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _parseContent();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(GeneratedPromptCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aiResponse.meta.id != widget.aiResponse.meta.id ||
        oldWidget.aiResponse.data.response != widget.aiResponse.data.response) {
      _parseContent();
    }
  }

  void _parseContent() {
    final response = widget.aiResponse.data.response;

    // Parse the structured response format using static regex patterns
    // Expected format:
    // ## Summary
    // <summary text>
    //
    // ## Prompt
    // <full prompt>

    final summaryMatch =
        GeneratedPromptCard.summarySectionRegex.firstMatch(response);
    final promptMatch =
        GeneratedPromptCard.promptSectionRegex.firstMatch(response);

    // Fallback: if no Summary section found, use first line as summary.
    // If no Prompt section found, use entire response as the prompt.
    // This handles malformed or non-standard AI responses gracefully.
    _summary =
        summaryMatch?.group(1)?.trim() ?? response.split('\n').first.trim();
    _fullPrompt = promptMatch?.group(1)?.trim() ?? response;
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _fullPrompt));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isImagePrompt
                ? context.messages.imagePromptGenerationCopiedSnackbar
                : context.messages.promptGenerationCopiedSnackbar,
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with title and action buttons
        Row(
          children: [
            Icon(
              _isImagePrompt
                  ? AiResponseType.imagePromptGeneration.icon
                  : AiResponseType.promptGeneration.icon,
              color: context.colorScheme.primary,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _isImagePrompt
                    ? context.messages.imagePromptGenerationCardTitle
                    : context.messages.promptGenerationCardTitle,
                style: context.textTheme.titleSmall?.copyWith(
                  color: context.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Copy button (prominent)
            IconButton(
              icon: Icon(
                Icons.copy_rounded,
                color: context.colorScheme.primary,
                size: 20,
              ),
              visualDensity: VisualDensity.compact,
              tooltip: _isImagePrompt
                  ? context.messages.imagePromptGenerationCopyTooltip
                  : context.messages.promptGenerationCopyTooltip,
              onPressed: _copyToClipboard,
            ),
            // Expand/collapse button
            RotationTransition(
              turns: _rotationAnimation,
              child: IconButton(
                icon: Icon(
                  Icons.expand_more,
                  color: context.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                visualDensity: VisualDensity.compact,
                tooltip: _isImagePrompt
                    ? context.messages.imagePromptGenerationExpandTooltip
                    : context.messages.promptGenerationExpandTooltip,
                onPressed: _toggleExpanded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Summary (always visible)
        GestureDetector(
          onDoubleTap: () {
            ModalUtils.showSinglePageModal<void>(
              context: context,
              builder: (BuildContext _) {
                return AiResponseSummaryModalContent(
                  widget.aiResponse,
                  linkedFromId: widget.linkedFromId,
                );
              },
            );
          },
          child: SelectionArea(
            child: Text(
              _summary,
              style: context.textTheme.bodyMedium,
            ),
          ),
        ),
        // Expandable full prompt
        AnimatedBuilder(
          animation: _expandAnimation,
          builder: (context, child) {
            if (_expandAnimation.value == 0) {
              return const SizedBox.shrink();
            }
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: _expandAnimation.value,
                child: child,
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isImagePrompt
                          ? context
                              .messages.imagePromptGenerationFullPromptLabel
                          : context.messages.promptGenerationFullPromptLabel,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text(
                      _isImagePrompt
                          ? context.messages.imagePromptGenerationCopyButton
                          : context.messages.promptGenerationCopyButton,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectionArea(
                  child: GptMarkdown(_fullPrompt),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
