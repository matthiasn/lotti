import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Freshness status + manual wake CTA shown directly under the report body
/// while automatic updates are off.
///
/// The strip occupies the same slot with the same geometry in both states so
/// the card never jumps when freshness flips:
///
/// * stale — alert-warning glyph, "This summary is out of date", primary
///   wake CTA;
/// * fresh — quiet accent check, "Summary is up to date", secondary wake CTA
///   for an on-demand refresh.
///
/// The hue lives on the status glyph only — the strip wears the same
/// hairline chrome as the proposal rows below it, so the zones read as one
/// system. The message stays at standard foreground contrast. The CTA is
/// disabled (null [onRunNow]) while no inference setup is available and
/// swaps to a spinner while a wake is running.
class TaskAgentFreshnessStrip extends StatelessWidget {
  const TaskAgentFreshnessStrip({
    required this.isStale,
    required this.isRunning,
    required this.onRunNow,
    super.key,
  });

  final bool isStale;
  final bool isRunning;
  final VoidCallback? onRunNow;

  /// Below this strip width the labeled CTA gives way to a compact circular
  /// reload button on the message line, so the strip stays a single row and
  /// the five-word message never wraps into a one-word widow beside a
  /// full-size pill. Sized for the English message + labeled CTA with
  /// localization headroom; a fixed layout breakpoint like the
  /// reading-measure caps.
  static const double _compactWidth = 440;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final accent = isStale
        ? tokens.colors.alert.warning.defaultColor
        : ai.accent;

    final messageLine = Row(
      children: [
        Icon(
          isStale
              ? Icons.warning_amber_rounded
              : Icons.check_circle_outline_rounded,
          size: tokens.spacing.step5,
          color: accent,
        ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Text(
            isStale
                ? messages.taskAgentReportOutdatedTitle
                : messages.taskAgentReportUpToDate,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: isStale ? ai.bodyText : ai.metaText,
            ),
          ),
        ),
      ],
    );
    final cta = DesignSystemButton(
      key: const ValueKey('taskAgentWakeButton'),
      label: isRunning
          ? messages.aiSummaryThinkingLabel
          : messages.taskAgentWakeAgent,
      leadingIcon: Icons.refresh_rounded,
      variant: isStale
          ? DesignSystemButtonVariant.primary
          : DesignSystemButtonVariant.secondary,
      isLoading: isRunning,
      onPressed: onRunNow,
    );
    // Compact CTA: a circular reload that mirrors the pill's weight logic —
    // filled accent while stale (the state's one loud element), neutral wash
    // when fresh — with the label carried by tooltip + semantics.
    final compactCta = Semantics(
      button: true,
      label: isRunning
          ? messages.aiSummaryThinkingLabel
          : messages.taskAgentWakeAgent,
      enabled: onRunNow != null,
      excludeSemantics: true,
      child: Tooltip(
        message: messages.taskAgentWakeAgent,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            key: const ValueKey('taskAgentWakeIconButton'),
            customBorder: const CircleBorder(),
            onTap: isRunning ? null : onRunNow,
            child: SizedBox(
              width: tokens.spacing.step8,
              height: tokens.spacing.step8,
              child: Center(
                child: Container(
                  width: tokens.spacing.step7,
                  height: tokens.spacing.step7,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: onRunNow == null
                        ? ai.subtleWash
                        : isStale
                        ? ai.accent
                        : ai.subtleWashStrong,
                    shape: BoxShape.circle,
                  ),
                  child: isRunning
                      ? SizedBox(
                          width: tokens.spacing.step4,
                          height: tokens.spacing.step4,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isStale ? ai.background : ai.accent,
                          ),
                        )
                      : Icon(
                          Icons.refresh_rounded,
                          size: tokens.spacing.step5,
                          color: onRunNow == null
                              ? ai.faintMeta
                              : isStale
                              ? ai.background
                              : ai.metaText,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Container(
      key: ValueKey(
        isStale ? 'taskAgentStaleNotice' : 'taskAgentFreshNotice',
      ),
      // Same horizontal inset as the proposal rows below, so the status
      // glyph and the row text share one internal grid line.
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step2,
      ),
      decoration: BoxDecoration(
        color: ai.subtleWashStrong,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        border: Border.all(color: ai.rowBorder),
      ),
      // One row at every width: message leads, the CTA holds the trailing
      // edge — as a labeled pill where it fits, as a compact circular reload
      // below the breakpoint. The message wraps rather than truncates if a
      // translation still overflows.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < _compactWidth;
          return Row(
            children: [
              Expanded(child: messageLine),
              SizedBox(width: tokens.spacing.step3),
              if (compact) compactCta else cta,
            ],
          );
        },
      ),
    );
  }
}
