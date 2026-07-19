import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/ai_response_summary_modal.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/ai_attribution_summary.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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

  /// Resolves the title shown in the card header.
  ///
  /// When the response carries a `skillId` for a known built-in skill, use
  /// the skill's own name so sibling skills that share an [AiResponseType]
  /// (coding / design / research, all `promptGeneration`) get distinct
  /// titles. Falls back to the legacy localized type label.
  String _cardTitle(BuildContext context) {
    final skillId = widget.aiResponse.data.skillId;
    if (skillId != null) {
      final skill = findBuiltInSkill(skillId);
      if (skill != null) return skill.name;
    }
    return _isImagePrompt
        ? context.messages.imagePromptGenerationCardTitle
        : context.messages.promptGenerationCardTitle;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: MotionDurations.medium2,
      vsync: this,
    );
    // Standard expand/collapse caret: collapsed → right (-0.25 turns
    // from the natural downward `Icons.expand_more`), expanded → down.
    _rotationAnimation =
        Tween<double>(
          begin: -0.25,
          end: 0,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: MotionCurves.standard,
          ),
        );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: MotionCurves.standard,
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

    final summaryMatch = GeneratedPromptCard.summarySectionRegex.firstMatch(
      response,
    );
    final promptMatch = GeneratedPromptCard.promptSectionRegex.firstMatch(
      response,
    );

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
      context.showToast(
        tone: DesignSystemToastTone.success,
        title: _isImagePrompt
            ? context.messages.imagePromptGenerationCopiedSnackbar
            : context.messages.promptGenerationCopiedSnackbar,
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
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
              color: tokens.colors.interactive.enabled,
              size: tokens.spacing.step5,
            ),
            SizedBox(width: tokens.spacing.step2),
            Expanded(
              child: Text(
                _cardTitle(context),
                style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                  color: tokens.colors.interactive.enabled,
                  fontWeight: tokens.typography.weight.semiBold,
                ),
              ),
            ),
            // Copy button (prominent)
            IconButton(
              icon: Icon(
                Icons.copy_rounded,
                color: tokens.colors.interactive.enabled,
                size: tokens.spacing.step5,
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
                  color: tokens.colors.text.mediumEmphasis,
                  size: tokens.spacing.step5,
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
        SizedBox(height: tokens.spacing.step1),
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
            child: AgentMarkdownView(_summary),
          ),
        ),
        AiAttributionSummary(
          artifact: AiArtifactReference(
            type: AiArtifactType.journalAiResponse,
            id: widget.aiResponse.meta.id,
          ),
          attribution: widget.aiResponse.data.aiAttribution,
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
              SizedBox(height: tokens.spacing.step4),
              const Divider(),
              SizedBox(height: tokens.spacing.step2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isImagePrompt
                          ? context
                                .messages
                                .imagePromptGenerationFullPromptLabel
                          : context.messages.promptGenerationFullPromptLabel,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ),
                  DesignSystemButton(
                    onPressed: _copyToClipboard,
                    leadingIcon: Icons.copy_rounded,
                    label: _isImagePrompt
                        ? context.messages.imagePromptGenerationCopyButton
                        : context.messages.promptGenerationCopyButton,
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.step2),
              Container(
                padding: EdgeInsets.all(tokens.spacing.step3),
                decoration: BoxDecoration(
                  color: tokens.colors.background.level02,
                  borderRadius: BorderRadius.circular(tokens.radii.m),
                ),
                child: SelectionArea(
                  child: AgentMarkdownView(_fullPrompt),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
