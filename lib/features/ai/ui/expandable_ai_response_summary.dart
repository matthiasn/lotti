import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/ai_response_summary_modal.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

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

class _ExpandableAiResponseSummaryState
    extends State<ExpandableAiResponseSummary>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  bool _isExpanded = false;
  String? _tldrContent;
  String? _fullContent;

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

    // Extract TLDR paragraph using regex
    // Match content starting with **TLDR:** and ending at the first double line break
    final tldrRegex = RegExp(
      r'^\*\*TLDR:\*\*.*?(?=\n\n|\n$|\z)',
      multiLine: true,
      dotAll: true,
    );

    final tldrMatch = tldrRegex.firstMatch(response);
    if (tldrMatch != null) {
      _tldrContent = tldrMatch.group(0)?.trim();
      _fullContent = response;
    } else {
      // Fallback: if no TLDR found, use first paragraph
      final paragraphs = response.split(RegExp(r'\n\n+'));
      _tldrContent = paragraphs.isNotEmpty ? paragraphs.first.trim() : response;
      _fullContent = response;
    }
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: SelectionArea(
                      child: GptMarkdown(
                        _isExpanded ? _fullContent ?? '' : _tldrContent ?? '',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
