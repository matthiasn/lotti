import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/latest_summary_controller.dart';
import 'package:lotti/features/ai/ui/ai_response_summary.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsible_task_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class CollapsibleAiSummarySection extends ConsumerStatefulWidget {
  const CollapsibleAiSummarySection({
    required this.taskId,
    required this.scrollController,
    super.key,
  });

  final String taskId;
  final ScrollController scrollController;

  @override
  ConsumerState<CollapsibleAiSummarySection> createState() =>
      _CollapsibleAiSummarySectionState();
}

class _CollapsibleAiSummarySectionState
    extends ConsumerState<CollapsibleAiSummarySection> {
  final GlobalKey _sectionKey = GlobalKey();

  String _extractPreview(String markdown, {int maxLines = 3}) {
    final lines = markdown.split('\n');
    final previewLines = <String>[];
    var lineCount = 0;

    for (final line in lines) {
      // Skip empty lines at the beginning
      if (previewLines.isEmpty && line.trim().isEmpty) continue;

      // Remove markdown formatting for preview
      var cleanLine = line
          .replaceAll(RegExp(r'^#+\s+'), '') // Remove headers
          .replaceAll(RegExp(r'^\s*[-*+]\s+'), '• ') // Convert list items
          .trim();

      // Remove bold markdown
      cleanLine = cleanLine.replaceAllMapped(
        RegExp(r'\*\*(.*?)\*\*'),
        (match) => match.group(1) ?? '',
      );

      // Remove italic markdown
      cleanLine = cleanLine.replaceAllMapped(
        RegExp(r'\*(.*?)\*'),
        (match) => match.group(1) ?? '',
      );

      if (cleanLine.isNotEmpty) {
        previewLines.add(cleanLine);
        lineCount++;
        if (lineCount >= maxLines) break;
      }
    }

    final preview = previewLines.join(' ');
    return preview.length > 200
        ? '${preview.substring(0, 197)}...'
        : '$preview...';
  }

  void _scrollToSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _sectionKey.currentContext;
      if (context != null) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          final position = box.localToGlobal(
            Offset.zero,
            ancestor: widget.scrollController.position.context.storageContext
                .findRenderObject(),
          );

          widget.scrollController.animateTo(
            widget.scrollController.offset + position.dy - 100,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final latestSummaryAsync = ref.watch(
      latestSummaryControllerProvider(
        id: widget.taskId,
        aiResponseType: AiResponseType.taskSummary,
      ),
    );

    final inferenceStatus = ref.watch(
      inferenceStatusControllerProvider(
        id: widget.taskId,
        aiResponseType: AiResponseType.taskSummary,
      ),
    );

    final isRunning = inferenceStatus == InferenceStatus.running;

    return latestSummaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (aiResponse) {
        if (aiResponse == null) {
          return const SizedBox.shrink();
        }

        // Filter the response to remove the title
        final response = aiResponse.data.response;
        final titleRegex = RegExp(r'^#\s+.+$\n*', multiLine: true);
        final filteredResponse = response.replaceFirst(titleRegex, '').trim();

        final preview = _extractPreview(filteredResponse);

        return CollapsibleTaskSection(
          key: _sectionKey,
          title: context.messages.aiTaskSummaryTitle,
          icon: MdiIcons.robotOutline,
          initiallyExpanded: false,
          onExpansionChanged: (isExpanded) {
            if (isExpanded) {
              _scrollToSection();
            }
          },
          trailing: isRunning
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          collapsedChild: Text(
            preview,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          expandedChild: AiResponseSummary(
            aiResponse,
            linkedFromId: widget.taskId,
            fadeOut: false,
          ),
        );
      },
    );
  }
}
