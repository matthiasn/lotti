import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Collapsible "Captures" section for the Day surface.
///
/// Surfaces every persisted capture under the day-agent for the given
/// date, newest-first, with the captured transcript and an inline
/// [AudioPlayerWidget] when the capture has linked audio.
class CapturesPanel extends ConsumerStatefulWidget {
  const CapturesPanel({required this.date, super.key});

  final DateTime date;

  @override
  ConsumerState<CapturesPanel> createState() => _CapturesPanelState();
}

class _CapturesPanelState extends ConsumerState<CapturesPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final asyncCaptures = ref.watch(capturesForDateProvider(widget.date));
    final tokens = context.designTokens;
    return asyncCaptures.maybeWhen(
      skipLoadingOnReload: true,
      skipError: true,
      orElse: () => const SizedBox.shrink(),
      data: (captures) {
        if (captures.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step5,
            vertical: tokens.spacing.step3,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: tokens.colors.background.level02,
              borderRadius: BorderRadius.circular(tokens.radii.l),
              border: Border.all(color: tokens.colors.decorative.level01),
            ),
            child: Column(
              children: [
                _Header(
                  count: captures.length,
                  expanded: _expanded,
                  onToggle: () => setState(() => _expanded = !_expanded),
                ),
                if (_expanded) ...[
                  Divider(
                    height: 1,
                    color: tokens.colors.decorative.level01,
                  ),
                  // Cap the expanded list so a day with many captures
                  // does not push the agenda/timeline off-screen. The
                  // list scrolls internally when it overflows the cap.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: captures.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: tokens.colors.decorative.level01,
                      ),
                      itemBuilder: (_, i) => _CaptureRow(item: captures[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(tokens.radii.l),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step5,
          vertical: tokens.spacing.step4,
        ),
        child: Row(
          children: [
            Icon(
              Icons.mic_none_rounded,
              size: 18,
              color: tokens.colors.interactive.enabled,
            ),
            SizedBox(width: tokens.spacing.step3),
            Text(
              context.messages.dailyOsNextCapturesPanelTitle,
              style: tokens.typography.styles.others.overline.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
            SizedBox(width: tokens.spacing.step2),
            Text(
              '·  $count',
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
            const Spacer(),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: tokens.colors.text.lowEmphasis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureRow extends StatelessWidget {
  const _CaptureRow({required this.item});

  final CaptureWithAudio item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final capture = item.capture;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatTime(capture.capturedAt),
            style: tokens.typography.styles.others.overline.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step2),
          Text(
            capture.transcript,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          if (item.audio != null) ...[
            SizedBox(height: tokens.spacing.step3),
            AudioPlayerWidget(item.audio!),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
