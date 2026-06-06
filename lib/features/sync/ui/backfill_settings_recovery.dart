part of 'backfill_settings_page.dart';

/// Collapsible group containing every recovery action. Header is
/// always visible; body is hidden until tapped open. Order matches
/// the design handoff:
///   1. Catch up now (primary)
///   2. Retry skipped events (visible when skipped > 0)
///   3. Manual backfill (primary)
///   4. Reset unresolvable (primary, disabled when 0)
///   5. Re-request pending (secondary, disabled when 0)
///   6. Ask peers for unresolvable (primary, disabled when 0)
///   7. Retire stuck entries (danger-tertiary, disabled when 0)
class _AdvancedRecoveryGroup extends StatefulWidget {
  const _AdvancedRecoveryGroup({
    required this.stats,
    required this.skipped,
    required this.coordinator,
  });

  final BackfillStatsState stats;
  final int skipped;
  final QueuePipelineCoordinator? coordinator;

  @override
  State<_AdvancedRecoveryGroup> createState() => _AdvancedRecoveryGroupState();
}

class _AdvancedRecoveryGroupState extends State<_AdvancedRecoveryGroup>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late final AnimationController _chevController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  @override
  void dispose() {
    _chevController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _chevController.forward();
    } else {
      _chevController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final actions = _buildActions(context);

    // The outer Container's `clipBehavior` clips its own descendant
    // paint, but [InkWell] splashes are drawn on the nearest ancestor
    // [Material] — which here is the [MaterialApp]'s root Material
    // far up the tree. Without a local [Material] inside the
    // container the splash escapes the rounded corners. Wrapping the
    // header in a transparent [Material] gives ink an in-bounds
    // surface, so the splash is naturally clipped by the Container's
    // rounded shape above it.
    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step5,
                  vertical: tokens.spacing.step4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        messages.backfillAdvancedRecoveryTitle,
                        style: tokens.typography.styles.subtitle.subtitle2
                            .copyWith(
                              color: tokens.colors.text.highEmphasis,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Text(
                      messages.backfillAdvancedRecoveryActions(actions.length),
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.lowEmphasis,
                      ),
                    ),
                    SizedBox(width: tokens.spacing.step2),
                    RotationTransition(
                      turns: Tween<double>(begin: 0, end: 0.25).animate(
                        CurvedAnimation(
                          parent: _chevController,
                          curve: Curves.easeOut,
                        ),
                      ),
                      child: Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_open) ...[
            Container(
              height: 1,
              color: tokens.colors.decorative.level01,
            ),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0)
                Container(
                  height: 1,
                  color: tokens.colors.decorative.level01,
                ),
              actions[i],
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final messages = context.messages;
    final stats = widget.stats;
    final coordinator = widget.coordinator;
    final unresolvable = stats.stats?.totalUnresolvable ?? 0;
    final requested = stats.stats?.totalRequested ?? 0;
    final missing = stats.stats?.totalMissing ?? 0;
    final openCount = missing + requested;
    // The controller serializes every backfill op, so while one is
    // in flight the others would only bounce off its guard. Reflect
    // that in the UI by disabling all controller-backed actions
    // whenever any of them is running — keeps the page from looking
    // actionable when it isn't.
    final controllerBusy =
        stats.isProcessing ||
        stats.isResetting ||
        stats.isReRequesting ||
        stats.isResettingAllUnresolvable ||
        stats.isRetiringStuck;

    return [
      _RecoveryAction(
        icon: Icons.bolt_outlined,
        title: messages.queueCatchUpNowButton,
        description: messages.backfillCatchUpDescription,
        ctaLabel: messages.queueCatchUpNowButton,
        ctaIcon: Icons.bolt_outlined,
        tone: _RecoveryTone.primary,
        onPressed: coordinator == null
            ? null
            : () => _kickCatchUp(context, coordinator),
      ),
      if (widget.skipped > 0)
        _RecoveryAction(
          icon: Icons.refresh_rounded,
          title: messages.queueSkippedCardTitle,
          description: messages.queueSkippedCardBody(widget.skipped),
          ctaLabel: messages.queueSkippedRetryAll,
          ctaIcon: Icons.refresh_rounded,
          tone: _RecoveryTone.primary,
          onPressed: coordinator == null
              ? null
              : () => _retrySkipped(context, coordinator.queue),
        ),
      _RecoveryAction(
        icon: Icons.history_rounded,
        title: messages.backfillManualTitle,
        description: messages.backfillManualDescription,
        ctaLabel: stats.isProcessing
            ? messages.backfillManualProcessing
            : messages.backfillManualTrigger,
        ctaIcon: Icons.sync,
        tone: _RecoveryTone.primary,
        isBusy: stats.isProcessing,
        onPressed: controllerBusy
            ? null
            : () => ProviderScope.containerOf(context)
                  .read(backfillStatsControllerProvider.notifier)
                  .triggerFullBackfill(),
      ),
      _RecoveryAction(
        icon: Icons.restore_rounded,
        title: messages.backfillResetUnresolvableTitle,
        description: messages.backfillResetUnresolvableDescription,
        ctaLabel: stats.isResetting
            ? messages.backfillResetUnresolvableProcessing
            : messages.backfillResetUnresolvableTrigger,
        ctaIcon: Icons.restore_rounded,
        tone: _RecoveryTone.primary,
        isBusy: stats.isResetting,
        onPressed: (controllerBusy || unresolvable == 0)
            ? null
            : () => ProviderScope.containerOf(context)
                  .read(backfillStatsControllerProvider.notifier)
                  .resetUnresolvable(),
      ),
      _RecoveryAction(
        icon: Icons.replay_rounded,
        title: messages.backfillReRequestTitle,
        description: messages.backfillReRequestDescription,
        ctaLabel: stats.isReRequesting
            ? messages.backfillReRequestProcessing
            : messages.backfillReRequestTrigger,
        ctaIcon: Icons.replay_rounded,
        tone: _RecoveryTone.ghost,
        isBusy: stats.isReRequesting,
        onPressed: (controllerBusy || requested == 0)
            ? null
            : () => ProviderScope.containerOf(context)
                  .read(backfillStatsControllerProvider.notifier)
                  .triggerReRequest(),
      ),
      _RecoveryAction(
        icon: Icons.group_outlined,
        title: messages.backfillAskPeersTitle,
        description: messages.backfillAskPeersDescription,
        ctaLabel: stats.isResettingAllUnresolvable
            ? messages.backfillAskPeersProcessing
            : messages.backfillAskPeersTrigger(unresolvable),
        ctaIcon: Icons.group_outlined,
        tone: _RecoveryTone.primary,
        isBusy: stats.isResettingAllUnresolvable,
        onPressed: (controllerBusy || unresolvable == 0)
            ? null
            : () => _confirmAndResetAllUnresolvable(context, unresolvable),
      ),
      _RecoveryAction(
        icon: Icons.block_outlined,
        title: messages.backfillRetireStuckTitle,
        description: messages.backfillRetireStuckDescription,
        ctaLabel: stats.isRetiringStuck
            ? messages.backfillRetireStuckProcessing
            : messages.backfillRetireStuckTrigger(openCount),
        ctaIcon: Icons.block_outlined,
        tone: _RecoveryTone.dangerGhost,
        isBusy: stats.isRetiringStuck,
        onPressed: (controllerBusy || openCount == 0)
            ? null
            : () => _confirmAndRetireStuck(context, openCount),
      ),
    ];
  }

  Future<void> _kickCatchUp(
    BuildContext context,
    QueuePipelineCoordinator coordinator,
  ) async {
    final messages = context.messages;
    try {
      await coordinator.triggerBridge();
      if (!context.mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.success,
        title: messages.queueCatchUpNowDone,
      );
    } catch (e) {
      if (!context.mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: messages.queueCatchUpNowError(e.toString()),
      );
    }
  }

  Future<void> _retrySkipped(BuildContext context, InboundQueue queue) async {
    final messages = context.messages;
    try {
      final count = await queue.resurrectAll();
      if (!context.mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.success,
        title: messages.queueSkippedRetryAllDone(count),
      );
    } catch (e) {
      if (!context.mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: messages.queueSkippedRetryAllError(e.toString()),
      );
    }
  }

  Future<void> _confirmAndResetAllUnresolvable(
    BuildContext context,
    int unresolvable,
  ) async {
    final messages = context.messages;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(messages.backfillAskPeersConfirmTitle),
        content: Text(
          messages.backfillAskPeersConfirmContent(unresolvable),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(messages.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(messages.backfillAskPeersConfirmAccept),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ProviderScope.containerOf(
      context,
    ).read(backfillStatsControllerProvider.notifier).resetAllUnresolvable();
  }

  Future<void> _confirmAndRetireStuck(
    BuildContext context,
    int openCount,
  ) async {
    final messages = context.messages;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(messages.backfillRetireStuckConfirmTitle),
        content: Text(
          messages.backfillRetireStuckConfirmContent(openCount),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(messages.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(messages.backfillRetireStuckConfirmAccept),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ProviderScope.containerOf(
      context,
    ).read(backfillStatsControllerProvider.notifier).retireStuckNow();
  }
}

enum _RecoveryTone { primary, ghost, dangerGhost }

class _RecoveryAction extends StatelessWidget {
  const _RecoveryAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.ctaLabel,
    required this.ctaIcon,
    required this.tone,
    required this.onPressed,
    this.isBusy = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String ctaLabel;
  final IconData ctaIcon;
  final _RecoveryTone tone;
  final VoidCallback? onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isDanger = tone == _RecoveryTone.dangerGhost;
    final iconChipBg = isDanger
        ? tokens.colors.alert.error.defaultColor.withValues(alpha: 0.14)
        : tokens.colors.surface.enabled;
    final iconColor = isDanger
        ? tokens.colors.alert.error.defaultColor
        : tokens.colors.text.mediumEmphasis;

    return Container(
      color: tokens.colors.background.level02,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconChipBg,
                  borderRadius: BorderRadius.circular(tokens.radii.smallChips),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(
                            color: tokens.colors.text.highEmphasis,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      description,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step3),
          DesignSystemButton(
            label: ctaLabel,
            onPressed: onPressed,
            leadingIcon: isBusy ? null : ctaIcon,
            variant: switch (tone) {
              _RecoveryTone.primary => DesignSystemButtonVariant.primary,
              _RecoveryTone.ghost => DesignSystemButtonVariant.secondary,
              _RecoveryTone.dangerGhost =>
                DesignSystemButtonVariant.dangerSecondary,
            },
            size: DesignSystemButtonSize.medium,
          ),
        ],
      ),
    );
  }
}

/// Shared rounded surface card. Background, radius, and outline come
/// from design tokens; the only knob the caller turns is `padding`.
