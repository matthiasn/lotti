// Shutdown's right-column cards — metrics 2x2, the reflection input,
// and the for-tomorrow note. Part of the shutdown_page library so they
// keep the page's private styling helpers in scope.
part of 'shutdown_page.dart';

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.metrics});

  final ShutdownMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final h = metrics.focusMinutes ~/ 60;
    final m = metrics.focusMinutes % 60;
    final focus = m == 0 ? '${h}h' : '${h}h ${m}m';
    final energyDelta = metrics.energyDeltaVsWeek;
    final deltaSign = energyDelta >= 0 ? '⬆' : '⬇';
    return Container(
      padding: EdgeInsets.all(tokens.spacing.step5),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: GridView(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2.4,
        ),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: [
          _MetricTile(
            label: messages.dailyOsNextShutdownMetricFocus,
            value: focus,
          ),
          _MetricTile(
            label: messages.dailyOsNextShutdownMetricFlow,
            value: '${metrics.flowSessions}',
          ),
          _MetricTile(
            label: messages.dailyOsNextShutdownMetricSwitches,
            value: '${metrics.contextSwitches}',
            sub: messages.dailyOsNextShutdownMetricSwitchesAvg(
              metrics.contextSwitchesWeekAvg.toStringAsFixed(1),
            ),
          ),
          _MetricTile(
            label: messages.dailyOsNextShutdownMetricEnergy,
            value: metrics.energyScore.toStringAsFixed(1),
            sub: messages.dailyOsNextShutdownMetricEnergyDelta(
              '$deltaSign ${energyDelta.abs().toStringAsFixed(1)}',
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value, this.sub});

  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: calmEyebrowStyle(tokens),
        ),
        SizedBox(height: tokens.spacing.step1),
        Text(
          value,
          style: monoMetaStyle(
            tokens,
            tokens.colors,
            base: tokens.typography.styles.heading.heading3,
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        if (sub != null)
          Text(
            sub!,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
      ],
    );
  }
}

class _ReflectionCard extends ConsumerStatefulWidget {
  const _ReflectionCard({required this.forDate});

  final DateTime forDate;

  @override
  ConsumerState<_ReflectionCard> createState() => _ReflectionCardState();
}

class _ReflectionCardState extends ConsumerState<_ReflectionCard> {
  final _controller = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(ReflectionSource source) async {
    if (_controller.text.trim().isEmpty) return;
    await ref
        .read(shutdownControllerProvider(widget.forDate).notifier)
        .submitReflection(text: _controller.text.trim(), source: source);
    if (!mounted) return;
    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final messages = context.messages;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.step5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            teal.withValues(alpha: 0.10),
            tokens.colors.alert.info.defaultColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: teal.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            messages.dailyOsNextShutdownReflectionOverline,
            style: calmEyebrowStyle(tokens, color: teal),
          ),
          SizedBox(height: tokens.spacing.step3),
          Text(
            messages.dailyOsNextShutdownReflectionPrompt,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          if (_submitted)
            Text(
              messages.dailyOsNextShutdownReflectionThanks,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: teal,
              ),
            )
          else ...[
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: messages.dailyOsNextShutdownReflectionPlaceholder,
                filled: true,
                fillColor: tokens.colors.background.level02,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radii.m),
                  borderSide: BorderSide.none,
                ),
              ),
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            Row(
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.mic_rounded, size: 14),
                  label: Text(messages.dailyOsNextShutdownReflectionSpeak),
                  style: FilledButton.styleFrom(
                    backgroundColor: teal,
                    foregroundColor: tokens.colors.text.onInteractiveAlert,
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.step3,
                      vertical: tokens.spacing.step2,
                    ),
                    textStyle: tokens.typography.styles.body.bodySmall,
                  ),
                  onPressed: () => _submit(ReflectionSource.voice),
                ),
                SizedBox(width: tokens.spacing.step3),
                TextButton(
                  onPressed: () => _submit(ReflectionSource.typed),
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.colors.text.mediumEmphasis,
                  ),
                  child: Text(messages.dailyOsNextShutdownReflectionSubmit),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TomorrowNoteCard extends StatelessWidget {
  const _TomorrowNoteCard({required this.note});

  final TomorrowNote note;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.step5),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.dailyOsNextShutdownTomorrowOverline,
            style: calmEyebrowStyle(tokens),
          ),
          SizedBox(height: tokens.spacing.step3),
          Text(
            note.body,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShutdownFooter extends StatelessWidget {
  const _ShutdownFooter();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final messages = context.messages;
    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step6,
          vertical: tokens.spacing.step4,
        ),
        child: Row(
          children: [
            TextButton.icon(
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text(messages.dailyOsNextDayBack),
              style: TextButton.styleFrom(
                foregroundColor: tokens.colors.text.mediumEmphasis,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const Spacer(),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: tokens.colors.text.mediumEmphasis,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(messages.dailyOsNextShutdownSaveAndClose),
            ),
            SizedBox(width: tokens.spacing.step3),
            FilledButton.icon(
              icon: const Icon(Icons.check_rounded, size: 14),
              label: Text(messages.dailyOsNextShutdownCloseDay),
              style: FilledButton.styleFrom(
                backgroundColor: teal,
                foregroundColor: tokens.colors.text.onInteractiveAlert,
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step5,
                  vertical: tokens.spacing.step3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(tokens.radii.m),
                ),
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}
