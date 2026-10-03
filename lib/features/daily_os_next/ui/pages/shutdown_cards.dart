// Shutdown's right-column cards — metrics 2x2, the reflection input,
// and the for-tomorrow note. Split out of the shutdown_page library; the
// page imports these and reuses the shared styling helpers.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_shutdown_service.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/shutdown_controller.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

class MetricsCard extends StatelessWidget {
  const MetricsCard({required this.metrics, super.key});

  final ShutdownMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final h = metrics.focusMinutes ~/ 60;
    final m = metrics.focusMinutes % 60;
    final focus = m == 0 ? '${h}h' : '${h}h ${m}m';
    final switchesAvg = metrics.contextSwitchesWeekAvg;
    final energy = metrics.energyScore;
    final energyDelta = metrics.energyDeltaVsWeek;
    final textScaler = MediaQuery.textScalerOf(context);
    final metricTileHeight =
        textScaler.scale(tokens.typography.lineHeight.overline) * 2 +
        textScaler.scale(tokens.typography.lineHeight.heading3) +
        textScaler.scale(tokens.typography.lineHeight.caption) * 2 +
        tokens.spacing.step1;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.step5),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: GridView(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: tokens.spacing.step5,
          crossAxisSpacing: tokens.spacing.step5,
          mainAxisExtent: metricTileHeight,
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
            sub: switchesAvg == null
                ? null
                : messages.dailyOsNextShutdownMetricSwitchesAvg(
                    switchesAvg.toStringAsFixed(1),
                  ),
          ),
          _MetricTile(
            label: messages.dailyOsNextShutdownMetricEnergy,
            // No session of the day was rated: there is no measured energy to
            // show, and inventing one would be worse than a dash.
            value: energy?.toStringAsFixed(1) ?? '—',
            sub: energy == null
                ? messages.dailyOsNextShutdownMetricEnergyNoRatings
                : energyDelta == null
                ? null
                : messages.dailyOsNextShutdownMetricEnergyDelta(
                    '${energyDelta >= 0 ? '⬆' : '⬇'} '
                    '${energyDelta.abs().toStringAsFixed(1)}',
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

/// Opens the recorder for a spoken reflection, linked under the day's
/// reflection entry; returns the created audio entry's id, or null when the
/// user cancelled.
typedef ShutdownReflectionRecorder =
    Future<String?> Function(BuildContext context, String reflectionEntryId);

class ReflectionCard extends ConsumerStatefulWidget {
  const ReflectionCard({
    required this.forDate,
    this.recordVoice = openShutdownReflectionRecorder,
    super.key,
  });

  final DateTime forDate;
  final ShutdownReflectionRecorder recordVoice;

  @override
  ConsumerState<ReflectionCard> createState() => _ReflectionCardState();
}

class _ReflectionCardState extends ConsumerState<ReflectionCard> {
  final _controller = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ShutdownController get _notifier =>
      ref.read(shutdownControllerProvider(widget.forDate).notifier);

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    try {
      await _notifier.submitReflection(text);
    } on Object {
      if (mounted) showShutdownActionFailed(context);
      return;
    }
    if (!mounted) return;
    setState(() => _submitted = true);
  }

  /// Records a spoken reflection under the day's reflection entry, where its
  /// transcript joins any typed text.
  Future<void> _speak() async {
    final String entryId;
    try {
      entryId = await _notifier.ensureReflectionEntry();
    } on Object {
      if (mounted) showShutdownActionFailed(context);
      return;
    }
    if (!mounted) return;
    final recordedId = await widget.recordVoice(context, entryId);
    if (!mounted || recordedId == null) return;
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
                  icon: const Icon(LottiIcons.mic, size: 14),
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
                  onPressed: _speak,
                ),
                SizedBox(width: tokens.spacing.step3),
                TextButton(
                  onPressed: _save,
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.colors.text.mediumEmphasis,
                  ),
                  child: Text(messages.dailyOsNextShutdownReflectionSave),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The "For tomorrow" note. Loads on its own, so the rest of Shutdown
/// renders while it is being written or when it cannot be.
class TomorrowNoteCard extends ConsumerWidget {
  const TomorrowNoteCard({required this.forDate, super.key});

  final DateTime forDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final note = ref.watch(shutdownTomorrowNoteProvider(forDate));
    final bodyStyle = tokens.typography.styles.body.bodyMedium.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
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
            messages.dailyOsNextShutdownTomorrowOverline,
            style: calmEyebrowStyle(tokens),
          ),
          SizedBox(height: tokens.spacing.step3),
          switch (note) {
            AsyncValue(:final value?) => Text(value.body, style: bodyStyle),
            AsyncValue(
              error: TomorrowNoteUnavailableException(
                failure: TomorrowNoteFailure.noInferenceProvider,
              ),
            ) =>
              Text(
                messages.dailyOsNextShutdownTomorrowNoProvider,
                style: bodyStyle,
              ),
            AsyncValue(hasError: true) => Row(
              children: [
                Expanded(
                  child: Text(
                    messages.dailyOsNextShutdownTomorrowError,
                    style: bodyStyle,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(shutdownTomorrowNoteProvider(forDate)),
                  child: Text(messages.dailyOsNextDraftingRetry),
                ),
              ],
            ),
            _ => const LinearProgressIndicator(),
          },
        ],
      ),
    );
  }
}

/// Tells the user an action did not save, leaving the screen as it was.
void showShutdownActionFailed(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.messages.dailyOsNextGenericError)),
  );
}

/// The real recorder: the standard audio recording sheet, linked under the
/// reflection entry. Pure delegation, excluded like the goal check-in's.
// coverage:ignore-start
Future<String?> openShutdownReflectionRecorder(
  BuildContext context,
  String reflectionEntryId,
) => AudioRecordingModal.show(
  context,
  linkedId: reflectionEntryId,
  useRootNavigator: false,
);
// coverage:ignore-end

class ShutdownFooter extends ConsumerStatefulWidget {
  const ShutdownFooter({required this.forDate, super.key});

  final DateTime forDate;

  @override
  ConsumerState<ShutdownFooter> createState() => _ShutdownFooterState();
}

class _ShutdownFooterState extends ConsumerState<ShutdownFooter> {
  bool _closing = false;

  /// Closing the day writes tomorrow's note from the final facts — after the
  /// carryover decisions and the reflection — so tomorrow's draft reads the
  /// day as it ended. A note that cannot be written does not keep the day
  /// open: the card already says why.
  Future<void> _closeDay() async {
    setState(() => _closing = true);
    final provider = shutdownTomorrowNoteProvider(widget.forDate);
    ref.invalidate(provider);
    try {
      await ref.read(provider.future);
    } on Object {
      // Shown on the note card; closing goes ahead.
    }
    if (!mounted) return;
    await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final messages = context.messages;
    return DesignSystemModalActionBar(
      glass: true,
      layout: DesignSystemModalActionBarLayout.compactPrimary,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step6,
        vertical: tokens.spacing.step4,
      ),
      secondary: [
        TextButton.icon(
          icon: const Icon(LottiIcons.back, size: 16),
          label: Text(messages.dailyOsNextDayBack),
          style: TextButton.styleFrom(
            foregroundColor: tokens.colors.text.mediumEmphasis,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: tokens.colors.text.mediumEmphasis,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(messages.dailyOsNextShutdownSaveAndClose),
        ),
      ],
      primary: FilledButton.icon(
        icon: _closing
            ? SizedBox.square(
                dimension: tokens.spacing.step4,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tokens.colors.text.onInteractiveAlert,
                ),
              )
            : const Icon(LottiIcons.confirm, size: 14),
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
        onPressed: _closing ? null : _closeDay,
      ),
    );
  }
}
