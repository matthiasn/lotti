import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/summary_read_aloud_button.dart';
import 'package:lotti/features/ai/ui/ai_response_summary.dart';
import 'package:lotti/features/design_system/components/motion/size_fade_entrance.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/linked_ai_responses_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/widgets/layout/viewport_stable_animated_size.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:material_ui/material_ui.dart';

/// The AI responses linked to an entry (a recording's summary and coding
/// prompts, a photo's analysis), stacked under it on the entry's own gutter.
///
/// Each response is an [AiResponseSummary] that names its own job and
/// collapses by itself, so the stack has no header and no toggle of its own.
/// Renders nothing while the entry has no responses, and says so when they
/// could not be loaded. A response arriving later is animated in.
class NestedAiResponsesWidget extends ConsumerStatefulWidget {
  const NestedAiResponsesWidget({
    required this.parentEntryId,
    required this.linkedFromEntity,
    this.contextTaskId,
    super.key,
  });

  /// The ID of the parent entry (e.g., audio entry) to fetch linked AI responses for.
  final String parentEntryId;

  /// The parent entity that AI responses are linked from (used for context in AI response display).
  final JournalEntity linkedFromEntity;

  /// The task the parent entry is shown in, or null when it is shown on its
  /// own. Coding prompts another task owns are left out of a task's view
  /// ([taskScopedAiResponsesProvider]).
  final String? contextTaskId;

  /// The responses this widget lists: everything the entry carries when it
  /// is shown on its own, the task's share of it inside a task.
  ProviderListenable<AsyncValue<List<AiResponseEntry>>> get _responses {
    final taskId = contextTaskId;
    return taskId == null
        ? linkedAiResponsesControllerProvider(parentEntryId)
        : taskScopedAiResponsesProvider((
            entryId: parentEntryId,
            taskId: taskId,
          ));
  }

  @override
  ConsumerState<NestedAiResponsesWidget> createState() =>
      _NestedAiResponsesWidgetState();
}

class _NestedAiResponsesWidgetState
    extends ConsumerState<NestedAiResponsesWidget> {
  ProviderSubscription<AsyncValue<List<AiResponseEntry>>>?
  _responsesSubscription;
  final Set<String> _seenResponseIds = {};
  Set<String> _newlyArrivedResponseIds = const {};
  bool _receivedInitialResponses = false;
  bool _animateSection = false;

  @override
  void initState() {
    super.initState();
    _listenToResponses();
  }

  @override
  void didUpdateWidget(covariant NestedAiResponsesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parentEntryId == widget.parentEntryId &&
        oldWidget.contextTaskId == widget.contextTaskId) {
      return;
    }

    _responsesSubscription?.close();
    _seenResponseIds.clear();
    _newlyArrivedResponseIds = const {};
    _receivedInitialResponses = false;
    _animateSection = false;
    _listenToResponses();
  }

  @override
  void dispose() {
    _responsesSubscription?.close();
    super.dispose();
  }

  void _listenToResponses() {
    _responsesSubscription = ref.listenManual(
      widget._responses,
      (_, next) => _trackResponses(next.value),
      fireImmediately: true,
    );
  }

  void _trackResponses(List<AiResponseEntry>? responses) {
    if (responses == null) return;

    final currentIds = responses.map((response) => response.meta.id).toSet();
    final isInitialResult = !_receivedInitialResponses;
    final animateSection =
        !isInitialResult && _seenResponseIds.isEmpty && currentIds.isNotEmpty;
    _newlyArrivedResponseIds = isInitialResult || animateSection
        ? const {}
        : currentIds.difference(_seenResponseIds);
    _animateSection = animateSection;
    _receivedInitialResponses = true;
    _seenResponseIds
      ..clear()
      ..addAll(currentIds);
  }

  @override
  Widget build(BuildContext context) {
    final asyncAiResponses = ref.watch(widget._responses);
    final tokens = context.designTokens;

    final aiResponses = asyncAiResponses.value;
    if (aiResponses == null) {
      // Still loading renders nothing; a failed first load says so rather
      // than leaving the entry looking as if the agent made nothing of it.
      if (!asyncAiResponses.hasError) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(top: tokens.spacing.cardItemSpacing),
        child: Text(
          context.messages.nestedAiResponsesLoadFailed,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      );
    }

    if (aiResponses.isEmpty) return const SizedBox.shrink();

    final newlyArrived = _newlyArrivedResponseIds;
    // The entrance wrappers are always mounted, keyed, and only told whether
    // to animate: [SizeFadeEntrance] plays once, when it mounts. Adding the
    // wrapper for an arrival and dropping it on the next build would change
    // the widget type at that slot, remount the card under it and throw away
    // its expanded state.
    return SizeFadeEntrance(
      key: ValueKey('nested-ai-section-${widget.parentEntryId}'),
      animate: _animateSection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final response in aiResponses)
            SizeFadeEntrance(
              key: ValueKey('nested-ai-response-${response.meta.id}'),
              animate: newlyArrived.contains(response.meta.id),
              child: Padding(
                padding: EdgeInsets.only(top: tokens.spacing.cardItemSpacing),
                child: _buildAiResponseCard(context, response),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAiResponseCard(BuildContext context, AiResponseEntry response) {
    final tokens = context.designTokens;

    return Dismissible(
      key: Key(response.meta.id),
      dismissThresholds: const {DismissDirection.endToStart: 0.25},
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmAndDelete(context, response.meta.id),
      background: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radii.l),
        child: ColoredBox(
          color: tokens.colors.alert.error.defaultColor,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.step4),
              child: Icon(
                LottiIcons.delete,
                color: tokens.colors.text.onInteractiveAlert,
              ),
            ),
          ),
        ),
      ),
      child: ViewportStableAnimatedSize(
        key: ValueKey('nested-ai-response-size-${response.meta.id}'),
        child: AiResponseSummary(
          response,
          fadeOut: false,
          // Long analyses (e.g. a full OCR extraction) start collapsed to a
          // faded preview so one card cannot dominate the nested thread.
          collapsible: true,
          readAloud: (text) => TaskPromptReadAloudButton(
            taskId: widget.contextTaskId,
            sourceId: response.meta.id,
            text: text,
          ),
        ),
      ),
    );
  }

  /// Confirms deletion with the user and performs the delete operation.
  /// Returns true only if the user confirmed AND the delete succeeded.
  Future<bool> _confirmAndDelete(
    BuildContext context,
    String responseId,
  ) async {
    final errorMessage = context.messages.aiResponseDeleteError;

    final confirmed = await showConfirmationModal(
      context: context,
      title: context.messages.aiResponseDeleteTitle,
      message: context.messages.aiResponseDeleteWarning,
      cancelLabel: context.messages.aiResponseDeleteCancel,
      confirmLabel: context.messages.aiResponseDeleteConfirm,
    );

    if (!confirmed) {
      return false;
    }

    // Perform the delete and only dismiss if successful
    try {
      final success = await ref
          .read(journalRepositoryProvider)
          .deleteJournalEntity(responseId);

      if (!success && context.mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: errorMessage,
        );
      }
      return success;
    } catch (e) {
      if (context.mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: errorMessage,
        );
      }
      return false;
    }
  }
}
