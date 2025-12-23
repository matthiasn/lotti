import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/ai_response_summary_modal.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class ExpandableAiResponseSummary extends StatefulWidget {
  const ExpandableAiResponseSummary(
    this.aiResponse, {
    required this.linkedFromId,
    super.key,
  });

  final AiResponseEntry aiResponse;
  final String? linkedFromId;

  @override
  State<ExpandableAiResponseSummary> createState() =>
      _ExpandableAiResponseSummaryState();
}

const _animationDuration = Duration(milliseconds: 500);

class _ExpandableAiResponseSummaryState
    extends State<ExpandableAiResponseSummary>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;
  late String? _tldrContent;
  late String? _additionalContent;

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
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
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
    var response = widget.aiResponse.data.response;

    // Remove the first H1 header (title) from task summaries
    if (widget.aiResponse.data.type == AiResponseType.taskSummary) {
      final titleRegex = RegExp(r'^#\s+.+$\n*', multiLine: true);
      response = response.replaceFirst(titleRegex, '').trim();
    }

    // Extract TLDR paragraph - match from **TLDR:** to the end of the paragraph
    // A paragraph ends with double newline or end of string
    final tldrRegex = RegExp(
      r'^\*\*TLDR:\*\*[^\n]*(?:\n(?!\n)[^\n]*)*',
      multiLine: true,
    );

    final tldrMatch = tldrRegex.firstMatch(response);
    if (tldrMatch != null) {
      _tldrContent = tldrMatch.group(0)?.trim();
      // Extract the content after TLDR match
      final matchEnd = tldrMatch.end;
      _additionalContent = response.substring(matchEnd).trim();
      if (_additionalContent?.startsWith('\n') ?? false) {
        _additionalContent = _additionalContent?.substring(1).trim();
      }
      if (_additionalContent?.isEmpty ?? true) {
        _additionalContent = null;
      }
    } else {
      // Fallback: if no TLDR found, use first paragraph
      final paragraphs = response.split(RegExp(r'\n\n+'));
      _tldrContent = paragraphs.isNotEmpty ? paragraphs.first.trim() : response;
      // Get remaining paragraphs
      if (paragraphs.length > 1) {
        _additionalContent = paragraphs.skip(1).join('\n\n').trim();
      } else {
        _additionalContent = null;
      }
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      _animationController.duration = _animationDuration;

      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Future<void> _handleLinkTap(String url, String title) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildLink(
    BuildContext context,
    InlineSpan text,
    String url,
    TextStyle style,
  ) {
    final linkColor = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () => _handleLinkTap(url, ''),
      child: Text.rich(
        TextSpan(
          children: [text],
          style: style.copyWith(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ModernBaseCard(
      child: GestureDetector(
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
        child: Stack(
          children: [
            // Content with padding for the button
            Padding(
              padding: const EdgeInsets.only(right: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TLDR content (always visible)
                  SelectionArea(
                    child: GptMarkdown(
                      _tldrContent ?? '',
                      onLinkTap: _handleLinkTap,
                      linkBuilder: _buildLink,
                    ),
                  ),
                  // Accordion-style expanding content
                  if (_additionalContent != null &&
                      _additionalContent!.isNotEmpty)
                    AnimatedBuilder(
                      animation: _expandAnimation,
                      builder: (context, child) {
                        // Use Offstage to prevent widget from being found when collapsed
                        if (_expandAnimation.value == 0) {
                          return const SizedBox.shrink();
                        }
                        return ClipRect(
                          child: Align(
                            alignment: Alignment.topLeft,
                            heightFactor: _expandAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          SelectionArea(
                            child: GptMarkdown(
                              _additionalContent!,
                              onLinkTap: _handleLinkTap,
                              linkBuilder: _buildLink,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Expand/collapse button positioned at top right
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: _toggleExpanded,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: RotationTransition(
                    turns: _rotationAnimation,
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
