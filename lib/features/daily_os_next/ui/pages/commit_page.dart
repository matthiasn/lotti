import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/time_format.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/capacity_donut.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/dashed_border.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/hold_to_confirm.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/lock_in_scene.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Sign-off page — the deliberate transition from "draft" to "my
/// day, that I chose." Mirrors `prototype/screens/commit.jsx`
/// Variant A.
///
/// Two columns: a compressed agenda recap on the left, a sign-off
/// pad on the right with [HoldToConfirm]. After the hold completes
/// the [LockInScene] overlay plays, then the page pops with the
/// committed plan so the host can render it without dashed outlines.
class CommitPage extends ConsumerStatefulWidget {
  const CommitPage({required this.draft, super.key});

  final DraftPlan draft;

  @override
  ConsumerState<CommitPage> createState() => _CommitPageState();
}

class _CommitPageState extends ConsumerState<CommitPage> {
  bool _locking = false;
  DraftPlan? _committed;

  Future<void> _onConfirmed() async {
    if (_locking) return;
    final agent = ref.read(dayAgentProvider);
    final committed = await agent.commitDay(widget.draft);
    if (!mounted) return;
    setState(() {
      _committed = committed;
      _locking = true;
    });
  }

  void _onSceneComplete() {
    if (!mounted) return;
    Navigator.of(context).pop(_committed);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final body = SafeArea(
      child: isWide
          ? Row(
              children: [
                Expanded(flex: 6, child: _DraftRecap(draft: widget.draft)),
                Expanded(
                  flex: 5,
                  child: _SignOffPad(onConfirmed: _onConfirmed),
                ),
              ],
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(tokens.spacing.step6),
              child: Column(
                children: [
                  _DraftRecap(draft: widget.draft),
                  SizedBox(height: tokens.spacing.step6),
                  _SignOffPad(onConfirmed: _onConfirmed),
                ],
              ),
            ),
    );

    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      appBar: AppBar(
        backgroundColor: tokens.colors.background.level01,
        elevation: 0,
        title: Text(
          context.messages.dailyOsNextCommitTitle,
          style: tokens.typography.styles.subtitle.subtitle1.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: context.messages.dailyOsNextDayBack,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Stack(
        children: [
          body,
          if (_locking)
            Positioned.fill(child: LockInScene(onComplete: _onSceneComplete)),
        ],
      ),
    );
  }
}

class _DraftRecap extends StatelessWidget {
  const _DraftRecap({required this.draft});

  final DraftPlan draft;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.spacing.step6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.messages.dailyOsNextCommitDraftOverline,
            style: calmEyebrowStyle(tokens),
          ),
          SizedBox(height: tokens.spacing.step4),
          for (final (index, item) in draft.agendaItems.indexed) ...[
            _RecapRow(index: index + 1, item: item),
            SizedBox(height: tokens.spacing.step3),
          ],
          SizedBox(height: tokens.spacing.step4),
          _CapacityRecap(draft: draft),
        ],
      ),
    );
  }
}

class _RecapRow extends StatelessWidget {
  const _RecapRow({required this.index, required this.item});

  final int index;
  final AgendaItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = categoryColorFromHex(item.category.colorHex);
    // Dashed outline = still a draft; the LockInScene settles these
    // rows into solid surfaces after sign-off.
    return DottedBorder(
      color: tokens.colors.decorative.level02,
      radius: tokens.radii.m,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.colors.background.level02,
          borderRadius: BorderRadius.circular(tokens.radii.m),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        padding: EdgeInsets.all(tokens.spacing.step4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$index',
                style: tokens.typography.styles.others.caption.copyWith(
                  color: color,
                  fontWeight: tokens.typography.weight.semiBold,
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.text.highEmphasis,
                      fontWeight: tokens.typography.weight.semiBold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.outcome != null) ...[
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      item.outcome!,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (item.totalEstimateMinutes != null) ...[
              SizedBox(width: tokens.spacing.step3),
              Text(
                context.messages.dailyOsNextEstimateMinutes(
                  item.totalEstimateMinutes!,
                ),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CapacityRecap extends StatelessWidget {
  const _CapacityRecap({required this.draft});

  final DraftPlan draft;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.step4),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Row(
        children: [
          CapacityDonut(
            scheduledMinutes: draft.scheduledMinutes,
            capacityMinutes: draft.capacityMinutes,
            size: 62,
          ),
          SizedBox(width: tokens.spacing.step4),
          Expanded(
            child: Text(
              context.messages.dailyOsNextCommitCapacityNote(
                formatMinutesCompact(draft.scheduledMinutes),
                formatMinutesCompact(draft.capacityMinutes),
              ),
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignOffPad extends StatelessWidget {
  const _SignOffPad({required this.onConfirmed});

  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final teal = tokens.colors.interactive.enabled;
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: 0.9,
          colors: [
            teal.withValues(alpha: 0.10),
            Colors.transparent,
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Three-tier lead-in: teal eyebrow → display title →
            // one-line explainer (handoff v2 item 4).
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Column(
                children: [
                  Text(
                    messages.dailyOsNextCommitFinalStepEyebrow,
                    style: calmEyebrowStyle(tokens, color: teal),
                  ),
                  SizedBox(height: tokens.spacing.step2),
                  Text(
                    messages.dailyOsNextCommitHeadline,
                    style: calmDisplayStyle(tokens),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: tokens.spacing.step2),
                  Text(
                    messages.dailyOsNextCommitExplainer,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.spacing.step6),
            HoldToConfirm(onConfirmed: onConfirmed),
            SizedBox(height: tokens.spacing.step5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                messages.dailyOsNextCommitSubCaption,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
