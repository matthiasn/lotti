import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/report_content_parser.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/tasks/ui/widgets/task_detail_section_card.dart';
import 'package:lotti/themes/theme.dart';

/// Displays the contents of an agent report with an expandable TLDR section.
///
/// Parses the markdown produced by the agent via the `update_report` tool call
/// to extract the TLDR section (always visible) and additional content
/// (shown on expand).
class AgentReportSection extends StatefulWidget {
  const AgentReportSection({
    required this.content,
    this.tldr,
    super.key,
  });

  final String content;

  /// Optional pre-extracted TLDR. When provided, used directly instead of
  /// parsing the TLDR from [content].
  final String? tldr;

  @override
  State<AgentReportSection> createState() => _AgentReportSectionState();
}

class _AgentReportSectionState extends State<AgentReportSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation =
        Tween<double>(
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Extracts the TLDR section and remaining content from the report markdown.
  ///
  /// When a pre-extracted [AgentReportSection.tldr] is available, uses it
  /// directly and treats the full [AgentReportSection.content] as the
  /// additional content. Otherwise falls back to [parseReportContent].
  ({String tldr, String? additional}) _parseContent() {
    final explicitTldr = widget.tldr;
    if (explicitTldr != null && explicitTldr.isNotEmpty) {
      final content = widget.content.trim();
      return (
        tldr: explicitTldr,
        additional: content.isNotEmpty ? content : null,
      );
    }
    return parseReportContent(widget.content);
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
    final hasContent = widget.content.trim().isNotEmpty;
    final hasTldr = widget.tldr?.trim().isNotEmpty ?? false;
    if (!hasContent && !hasTldr) return const SizedBox.shrink();

    final parsed = _parseContent();

    return TaskDetailSectionCard(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TLDR content (always visible)
                SelectionArea(
                  child: AgentMarkdownView(parsed.tldr),
                ),
                // Expandable additional content
                if (parsed.additional != null)
                  AnimatedBuilder(
                    animation: _expandAnimation,
                    builder: (context, child) {
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
                          child: AgentMarkdownView(parsed.additional!),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Expand/collapse button
          if (parsed.additional != null)
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
    );
  }
}
