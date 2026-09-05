import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The joining wizard's three stations, in journey order.
enum SyncWizardStep { getCode, check, connect }

/// The wizard's position, drawn instead of narrated: three labelled track
/// segments — Get code · Check · Connect — where the accent marks the active
/// station, a faded accent marks stations already passed, and a neutral track
/// marks what is still ahead.
///
/// Replaces the "Step n of 3 · …" prose eyebrow, which asked the reader to
/// parse a fraction and a label to learn what a glance at a track shows.
///
/// The position lives in paint — fill and weight — which assistive
/// technology cannot read, so the track announces itself as one localized
/// "Step n of 3: label" node instead of three indistinguishable captions.
class SyncWizardProgressTrack extends StatelessWidget {
  const SyncWizardProgressTrack({required this.active, super.key});

  final SyncWizardStep active;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final labels = [
      messages.syncWizardStepGetCode,
      messages.syncWizardStepCheck,
      messages.syncWizardStepConnect,
    ];

    return Semantics(
      container: true,
      label: messages.syncWizardStepStatus(
        active.index + 1,
        labels[active.index],
      ),
      child: ExcludeSemantics(
        child: Row(
          key: const Key('sync_wizard_progress_track'),
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) SizedBox(width: tokens.spacing.step2),
              Expanded(
                child: _TrackSegment(
                  label: labels[i],
                  isActive: i == active.index,
                  isDone: i < active.index,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackSegment extends StatelessWidget {
  const _TrackSegment({
    required this.label,
    required this.isActive,
    required this.isDone,
  });

  final String label;
  final bool isActive;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // A passed station keeps the accent hue so the track reads as one filled
    // line, but faded — full strength would put three "press this next"
    // signals on a screen that must have exactly one.
    final fill = isActive
        ? tokens.colors.interactive.enabled
        : isDone
        ? tokens.colors.interactive.enabled.withValues(
            alpha: SurfaceAlphas.muted,
          )
        : tokens.colors.surface.hover;
    final labelStyle = tokens.typography.styles.others.caption.copyWith(
      color: isActive
          ? tokens.colors.text.highEmphasis
          : tokens.colors.text.lowEmphasis,
      fontWeight: isActive ? tokens.typography.weight.semiBold : null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
          ),
          child: SizedBox(
            height: tokens.spacing.step2,
            width: double.infinity,
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: labelStyle,
        ),
      ],
    );
  }
}
