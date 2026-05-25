import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/drafting_controller.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/learning_cards.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/reasoning_panel.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/skeleton_agenda.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Drafting wait screen — the latency-as-reflection beat between
/// Reconcile and the Day view. Variant A of the prototype: reasoning
/// stream + skeleton agenda on the left, learning cards on the right.
///
/// When the controller flips to [DraftingPhase.ready], the screen
/// auto-pushes the [DayPage] and replaces itself in the navigator so
/// the back button from Day returns to Reconcile, not Drafting.
class DraftingPage extends ConsumerStatefulWidget {
  const DraftingPage({
    required this.captureId,
    required this.decidedTaskIds,
    required this.dayDate,
    super.key,
  });

  final CaptureId captureId;
  final List<String> decidedTaskIds;
  final DateTime dayDate;

  @override
  ConsumerState<DraftingPage> createState() => _DraftingPageState();
}

class _DraftingPageState extends ConsumerState<DraftingPage> {
  bool _advanced = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final params = DraftingParams(
      captureId: widget.captureId,
      decidedTaskIds: widget.decidedTaskIds,
      dayDate: widget.dayDate,
    );

    ref.listen<AsyncValue<DraftingState>>(draftingControllerProvider(params), (
      previous,
      next,
    ) {
      final value = next.value;
      if (value == null || _advanced) return;
      if (value.phase == DraftingPhase.ready && value.draft != null) {
        _advanced = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement<void, void>(
            MaterialPageRoute<void>(
              builder: (_) => DayPage(draft: value.draft!),
            ),
          );
        });
      }
    });

    final asyncState = ref.watch(draftingControllerProvider(params));

    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      body: SafeArea(
        child: asyncState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(
              context.messages.dailyOsNextReconcileError(error.toString()),
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          data: (state) => _DraftingBody(state: state),
        ),
      ),
    );
  }
}

class _DraftingBody extends StatelessWidget {
  const _DraftingBody({required this.state});

  final DraftingState state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final progress = state.totalLines == 0
        ? 0.0
        : state.visibleLines.length / state.totalLines;
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReasoningPanel(lines: state.visibleLines),
        SizedBox(height: tokens.spacing.step5),
        const SkeletonAgenda(),
      ],
    );

    final right = state.learningCards == null
        ? const SizedBox.shrink()
        : LearningCardsColumn(cards: state.learningCards!);

    return Column(
      children: [
        // 2 px teal progress bar across the content area.
        SizedBox(
          height: 2,
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            valueColor: AlwaysStoppedAnimation<Color>(teal),
            backgroundColor: teal.withValues(alpha: 0.10),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(tokens.spacing.step6),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: left),
                      SizedBox(width: tokens.spacing.step6),
                      Expanded(child: right),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      left,
                      SizedBox(height: tokens.spacing.step6),
                      right,
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
