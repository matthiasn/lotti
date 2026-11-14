part of 'front_entity_preview_card.dart';

/// A task's card content with what is generated for it: the cover's place
/// marked while it is drawn, then a line per generation still running or
/// failed, and the coding prompt's summary once there is one. Nothing is
/// added for a task nothing was asked for.
///
/// The runs report under the task's id as they do on its page
/// ([inferenceStatusControllerProvider]), so a run started from either place
/// shows here. A status is kept in memory only: after a restart a cover or a
/// prompt that arrived still shows, a run that never finished says nothing.
class _TaskWithGenerated extends ConsumerWidget {
  const _TaskWithGenerated({
    required this.task,
    required this.onTap,
    this.note,
  });

  final FrontTaskPreview task;
  final String? note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final id = task.entityId;
    InferenceStatus statusOf(AiResponseType type) => ref.watch(
      inferenceStatusControllerProvider((id: id, aiResponseType: type)),
    );
    // A cover that arrived is the whole story: its run no longer matters.
    final cover = task.coverArtId == null
        ? statusOf(AiResponseType.imageGeneration)
        : InferenceStatus.idle;
    // `.value`: a reload keeps the summary shown until the new one lands.
    final prompt = ref.watch(frontTaskCodingPromptProvider(id)).value;
    final writing = prompt == null
        ? statusOf(AiResponseType.promptGeneration)
        : InferenceStatus.idle;

    final caption = tokens.typography.styles.others.caption;
    Widget line(
      String name,
      IconData glyph,
      String text, {
      bool failed = false,
    }) {
      final ink = failed
          ? tokens.colors.alert.error.ink
          : tokens.colors.aiCard.accent;
      return Row(
        key: FrontEntityPreviewKeys.generated(id, name),
        spacing: tokens.spacing.step2,
        children: [
          Icon(glyph, size: IconSizes.xs, color: ink),
          Expanded(
            child: Text(text, style: caption.copyWith(color: ink)),
          ),
        ],
      );
    }

    final lines = [
      if (cover == InferenceStatus.running)
        line(
          'cover-drawing',
          LottiIcons.image,
          messages.frontPreviewCoverDrawing,
        )
      else if (cover == InferenceStatus.error)
        line(
          'cover-failed',
          LottiIcons.image,
          messages.frontPreviewCoverFailed,
          failed: true,
        ),
      if (prompt != null)
        Column(
          key: FrontEntityPreviewKeys.generated(id, 'prompt'),
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: tokens.spacing.step1,
          children: [
            Row(
              spacing: tokens.spacing.step2,
              children: [
                Icon(
                  LottiIcons.code,
                  size: IconSizes.xs,
                  color: tokens.colors.aiCard.accent,
                ),
                Text(
                  messages.promptGenerationCardTitle,
                  style: caption.copyWith(color: tokens.colors.aiCard.accent),
                ),
              ],
            ),
            Text(
              prompt,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: caption.copyWith(color: tokens.colors.text.mediumEmphasis),
            ),
          ],
        )
      else if (writing == InferenceStatus.running)
        line(
          'prompt-writing',
          LottiIcons.code,
          messages.frontPreviewPromptWriting,
        )
      else if (writing == InferenceStatus.error)
        line(
          'prompt-failed',
          LottiIcons.code,
          messages.frontPreviewPromptFailed,
          failed: true,
        ),
    ];

    final content = _TaskPreviewContent(
      task: task,
      note: note,
      onTap: onTap,
      drawingCover: cover == InferenceStatus.running,
    );
    if (lines.isEmpty) return content;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        content,
        const DesignSystemDivider(),
        // Part of the card: a tap on it opens the task, as the row does.
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step4,
                vertical: tokens.spacing.step3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: tokens.spacing.step2,
                children: lines,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
