import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/agents/ui/report_content_parser.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays the contents of an agent report with an expandable TLDR section.
///
/// Parses the markdown produced by the agent via the `update_report` tool call
/// to extract the TLDR section (always visible) and additional content
/// (shown on expand). Uses the same expandable pattern as
/// `ExpandableAiResponseSummary`.
class AgentReportSection extends StatefulWidget {
  const AgentReportSection({
    required this.content,
    super.key,
  });

  final String content;

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Extracts the TLDR section and remaining content from the report markdown.
  ///
  /// Delegates to [parseReportContent] for TLDR extraction.
  ({String tldr, String? additional}) _parseContent() =>
      parseReportContent(widget.content);

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

  Future<void> _handleLinkTap(String url, String title) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.content.isEmpty) return const SizedBox.shrink();

    final parsed = _parseContent();

    return ModernBaseCard(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TLDR content (always visible)
                SelectionArea(
                  child: GptMarkdown(
                    parsed.tldr,
                    onLinkTap: _handleLinkTap,
                  ),
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
                          child: GptMarkdown(
                            parsed.additional!,
                            onLinkTap: _handleLinkTap,
                          ),
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
