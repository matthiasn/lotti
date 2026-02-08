import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/features/ratings/state/rating_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Modal bottom sheet for rating a work session.
///
/// Presents 4 dimensions: Productivity, Energy, Focus, and Challenge-Skill.
/// The first three use a continuous tap-bar (10 visual ticks, stores exact
/// position as 0.0-1.0). The last uses 3 categorical buttons.
class SessionRatingModal extends ConsumerStatefulWidget {
  const SessionRatingModal({
    required this.timeEntryId,
    super.key,
  });

  final String timeEntryId;

  static Future<void> show(
    BuildContext context,
    String timeEntryId, {
    VoidCallback? onDismissed,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SessionRatingModal(timeEntryId: timeEntryId),
    ).whenComplete(() => onDismissed?.call());
  }

  @override
  ConsumerState<SessionRatingModal> createState() => _SessionRatingModalState();
}

class _SessionRatingModalState extends ConsumerState<SessionRatingModal> {
  double? _productivity;
  double? _energy;
  double? _focus;
  double? _challengeSkill;
  late TextEditingController _noteController;
  bool _isSubmitting = false;
  bool _didPrePopulate = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _prePopulate(JournalEntity? existing) {
    if (_didPrePopulate || existing is! RatingEntry) return;
    _didPrePopulate = true;
    _productivity = existing.data.dimensionValue('productivity');
    _energy = existing.data.dimensionValue('energy');
    _focus = existing.data.dimensionValue('focus');
    _challengeSkill = existing.data.dimensionValue('challenge_skill');
    if (existing.data.note != null) {
      _noteController.text = existing.data.note!;
    }
  }

  bool get _canSubmit =>
      _productivity != null &&
      _energy != null &&
      _focus != null &&
      _challengeSkill != null;

  Future<void> _submit() async {
    if (!_canSubmit || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final dimensions = [
        RatingDimension(key: 'productivity', value: _productivity!),
        RatingDimension(key: 'energy', value: _energy!),
        RatingDimension(key: 'focus', value: _focus!),
        RatingDimension(key: 'challenge_skill', value: _challengeSkill!),
      ];

      final note = _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim();

      await ref
          .read(
            ratingControllerProvider(timeEntryId: widget.timeEntryId).notifier,
          )
          .submitRating(dimensions, note: note);

      await HapticFeedback.heavyImpact();

      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _skip() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    ref
        .watch(ratingControllerProvider(timeEntryId: widget.timeEntryId))
        .whenData(_prePopulate);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLarge),

            // Title
            Text(
              context.messages.sessionRatingTitle,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),

            // Productivity
            _RatingRow(
              label: context.messages.sessionRatingProductivityQuestion,
              value: _productivity,
              onChanged: (v) => setState(() => _productivity = v),
            ),
            const SizedBox(height: AppTheme.spacingLarge),

            // Energy
            _RatingRow(
              label: context.messages.sessionRatingEnergyQuestion,
              value: _energy,
              onChanged: (v) => setState(() => _energy = v),
            ),
            const SizedBox(height: AppTheme.spacingLarge),

            // Focus
            _RatingRow(
              label: context.messages.sessionRatingFocusQuestion,
              value: _focus,
              onChanged: (v) => setState(() => _focus = v),
            ),
            const SizedBox(height: AppTheme.spacingLarge),

            // Challenge-Skill
            _ChallengeSkillRow(
              value: _challengeSkill,
              onChanged: (v) => setState(() => _challengeSkill = v),
            ),
            const SizedBox(height: AppTheme.spacingLarge),

            // Note field
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: context.messages.sessionRatingNoteHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMedium,
                  vertical: AppTheme.spacingSmall,
                ),
              ),
              maxLines: 2,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _skip,
                    child: Text(context.messages.sessionRatingSkipButton),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMedium),
                Expanded(
                  child: FilledButton(
                    onPressed: _canSubmit && !_isSubmitting ? _submit : null,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.messages.sessionRatingSaveButton),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSmall),
          ],
        ),
      ),
    );
  }
}

/// A row with a label and a continuous tap-bar (10 visual ticks).
///
/// Stores the exact tap position as a normalized double 0.0-1.0.
class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double? value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        _TapBar(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// A continuous tap-bar with 10 visual tick marks.
///
/// Tapping stores the exact horizontal position as 0.0-1.0.
/// No snapping - a tap between tick 3 and 4 stores ~0.35.
class _TapBar extends StatelessWidget {
  const _TapBar({
    required this.value,
    required this.onChanged,
  });

  final double? value;
  final ValueChanged<double> onChanged;

  static const int _tickCount = 10;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return GestureDetector(
          onTapDown: (details) {
            final normalized =
                (details.localPosition.dx / width).clamp(0.0, 1.0);
            onChanged(normalized);
            HapticFeedback.selectionClick();
          },
          onHorizontalDragUpdate: (details) {
            final normalized =
                (details.localPosition.dx / width).clamp(0.0, 1.0);
            onChanged(normalized);
          },
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            child: CustomPaint(
              size: Size(width, 40),
              painter: _TapBarPainter(
                value: value,
                tickCount: _tickCount,
                activeColor: colorScheme.primary,
                inactiveColor:
                    colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                fillColor: colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TapBarPainter extends CustomPainter {
  _TapBarPainter({
    required this.value,
    required this.tickCount,
    required this.activeColor,
    required this.inactiveColor,
    required this.fillColor,
  });

  final double? value;
  final int tickCount;
  final Color activeColor;
  final Color inactiveColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final tickSpacing = size.width / tickCount;

    // Draw fill up to value
    if (value != null) {
      final fillWidth = value! * size.width;
      final fillPaint = Paint()..color = fillColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, fillWidth, size.height),
          const Radius.circular(8),
        ),
        fillPaint,
      );
    }

    // Draw tick marks
    final tickPaint = Paint()
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (var i = 1; i < tickCount; i++) {
      final x = i * tickSpacing;
      final isActive = value != null && (i / tickCount) <= value!;
      tickPaint.color = isActive ? activeColor : inactiveColor;
      canvas.drawLine(
        Offset(x, size.height * 0.25),
        Offset(x, size.height * 0.75),
        tickPaint,
      );
    }

    // Draw value indicator
    if (value != null) {
      final indicatorX = value! * size.width;
      final indicatorPaint = Paint()..color = activeColor;
      canvas.drawCircle(
        Offset(indicatorX, size.height / 2),
        6,
        indicatorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_TapBarPainter oldDelegate) =>
      value != oldDelegate.value ||
      activeColor != oldDelegate.activeColor ||
      inactiveColor != oldDelegate.inactiveColor ||
      fillColor != oldDelegate.fillColor;
}

/// Challenge-Skill dimension with 3 categorical buttons.
class _ChallengeSkillRow extends StatelessWidget {
  const _ChallengeSkillRow({
    required this.value,
    required this.onChanged,
  });

  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.sessionRatingDifficultyLabel,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        SegmentedButton<double>(
          segments: [
            ButtonSegment(
              value: 0,
              label: Text(context.messages.sessionRatingChallengeTooEasy),
            ),
            ButtonSegment(
              value: 0.5,
              label: Text(context.messages.sessionRatingChallengeJustRight),
            ),
            ButtonSegment(
              value: 1,
              label: Text(context.messages.sessionRatingChallengeTooHard),
            ),
          ],
          selected: value != null ? {value!} : {},
          onSelectionChanged: (selected) {
            if (selected.isEmpty) {
              onChanged(null);
            } else {
              onChanged(selected.first);
              HapticFeedback.selectionClick();
            }
          },
          emptySelectionAllowed: true,
        ),
      ],
    );
  }
}
