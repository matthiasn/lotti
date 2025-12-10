import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/ai_response_summary_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Specialized card for displaying AI-generated coding prompts.
///
/// Features:
/// - Brief summary visible by default
/// - Prominent copy button
/// - Expandable full prompt view
/// - Read-only (no editing)
class GeneratedPromptCard extends StatefulWidget {
  const GeneratedPromptCard(
    this.aiResponse, {
    required this.linkedFromId,
    super.key,
  });

  final AiResponseEntry aiResponse;
  final String? linkedFromId;

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

  void _parseContent() {
    final response = widget.aiResponse.data.response;

    // Parse the structured response format
    // Expected format:
    // ## Summary
    // <summary text>
    //
    // ## Prompt
    // <full prompt>

    final summaryRegex = RegExp(
      r'##\s*Summary\s*\n+([\s\S]*?)(?=##\s*Prompt|$)',
      caseSensitive: false,
    );
    final promptRegex = RegExp(
      r'##\s*Prompt\s*\n+([\s\S]*)',
      caseSensitive: false,
    );

    final summaryMatch = summaryRegex.firstMatch(response);
    final promptMatch = promptRegex.firstMatch(response);

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
          content: Text(context.messages.promptGenerationCopiedSnackbar),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModernBaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with title and action buttons
          Row(
            children: [
              Icon(
                AiResponseType.promptGeneration.icon,
                color: context.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.messages.promptGenerationCardTitle,
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
                ),
                tooltip: context.messages.promptGenerationCopyTooltip,
                onPressed: _copyToClipboard,
              ),
              // Expand/collapse button
              GestureDetector(
                onTap: _toggleExpanded,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: RotationTransition(
                    turns: _rotationAnimation,
                    child: Icon(
                      Icons.expand_more,
                      size: 24,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                maxLines: _isExpanded ? null : 3,
                overflow: _isExpanded ? null : TextOverflow.ellipsis,
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
                Text(
                  context.messages.promptGenerationFullPromptLabel,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
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
      ),
    );
  }
}
