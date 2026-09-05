import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/ui/debug_overlay.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';
import 'package:material_ui/material_ui.dart';

/// The chrome over the world: project title and counts, the three
/// buttons, the toast, the morning-walk chip, the key legend and the
/// lantern legend. Everything here is pointer-transparent except the
/// buttons, so the world underneath stays walkable.
class PlazaHud extends StatelessWidget {
  const PlazaHud({
    required this.projectLabel,
    required this.taskCount,
    required this.weekCount,
    required this.attentionCount,
    required this.onMorningWalk,
    required this.onOverview,
    required this.onHome,
    required this.frameRate,
    required this.onFrameRateChanged,
    required this.showDebug,
    required this.onShowDebugChanged,
    this.toast,
    this.walkChip,
    super.key,
  });

  final String projectLabel;
  final int taskCount;
  final int weekCount;
  final int attentionCount;
  final VoidCallback onMorningWalk;
  final VoidCallback onOverview;
  final VoidCallback onHome;

  /// The frame-rate cap and its setter: auto, 60 or 30.
  final PlazaFrameRate frameRate;
  final ValueChanged<PlazaFrameRate> onFrameRateChanged;

  /// Whether the debug overlay shows, and its setter.
  final bool showDebug;
  final ValueChanged<bool> onShowDebugChanged;
  final String? toast;
  final String? walkChip;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 20,
          top: 16,
          child: IgnorePointer(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text('‹ Tasks', style: _subtitle),
                const SizedBox(width: 14),
                Text(
                  '$projectLabel — plaza',
                  style: _subtitle.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 14),
                Text(
                  '$taskCount tasks · $weekCount weeks · '
                  '$attentionCount need attention',
                  style: _caption,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 20,
          top: 14,
          child: Row(
            children: [
              DsSegmentedToggle<PlazaFrameRate>(
                segments: [
                  for (final rate in PlazaFrameRate.values)
                    DsSegment(rate, rate.label),
                ],
                selected: frameRate,
                onChanged: onFrameRateChanged,
              ),
              const SizedBox(width: 10),
              DesignSystemCheckbox(
                value: showDebug,
                label: 'Debug',
                onChanged: (value) => onShowDebugChanged(value ?? false),
              ),
              const SizedBox(width: 14),
              _HudButton(
                label: 'Morning walk',
                primary: true,
                onPressed: onMorningWalk,
              ),
              const SizedBox(width: 10),
              _HudButton(label: 'Overview', onPressed: onOverview),
              const SizedBox(width: 10),
              _HudButton(label: 'Home', onPressed: onHome),
            ],
          ),
        ),
        if (toast != null)
          Positioned(
            left: 0,
            right: 0,
            top: 64,
            child: IgnorePointer(
              child: Center(
                child: _Pill(
                  text: toast!,
                  border: PlazaStyle.teal.withValues(alpha: 0.4),
                  bold: true,
                ),
              ),
            ),
          ),
        if (walkChip != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 64,
            child: IgnorePointer(
              child: Center(
                child: _Pill(
                  text: walkChip!,
                  border: const Color(0x29FFFFFF),
                  bold: false,
                ),
              ),
            ),
          ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 18,
          child: IgnorePointer(child: Center(child: _KeyLegend())),
        ),
        const Positioned(
          right: 20,
          bottom: 18,
          child: IgnorePointer(child: _LanternLegend()),
        ),
      ],
    );
  }
}

const _subtitle = TextStyle(
  fontFamily: PlazaStyle.fontText,
  fontSize: 16,
  letterSpacing: 0.5,
  color: Colors.white,
);
const _caption = TextStyle(
  fontFamily: PlazaStyle.fontText,
  fontSize: 12,
  letterSpacing: 0.25,
  color: Color(0x99FFFFFF),
);

class _HudButton extends StatelessWidget {
  const _HudButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: primary ? PlazaStyle.teal : const Color(0x990D1018),
        foregroundColor: primary ? const Color(0xFF0D0D0D) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: primary
              ? BorderSide.none
              : const BorderSide(color: Color(0x3DFFFFFF)),
        ),
        textStyle: const TextStyle(
          fontFamily: PlazaStyle.fontText,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.border, required this.bold});

  final String text;
  final Color border;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xD10D1018),
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: PlazaStyle.fontText,
          fontSize: bold ? 14 : 13,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          color: bold ? Colors.white : const Color(0xD9FFFFFF),
        ),
      ),
    );
  }
}

class _KeyLegend extends StatelessWidget {
  const _KeyLegend();

  static const _keys = [
    ('WASD', 'walk'),
    ('drag', 'look'),
    ('Tab', 'next beacon'),
    ('H', 'home'),
    ('M', 'overview'),
    ('/', 'search'),
    ('⌫', 'back'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      children: [
        for (final (key, what) in _keys)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  key,
                  style: const TextStyle(
                    fontFamily: PlazaStyle.fontMono,
                    fontSize: 12,
                    color: PlazaStyle.textFaint,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                what,
                style: const TextStyle(
                  fontFamily: PlazaStyle.fontText,
                  fontSize: 12,
                  color: PlazaStyle.textFaint,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _LanternLegend extends StatelessWidget {
  const _LanternLegend();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final state in const [
          LanternState.inProgress,
          LanternState.open,
          LanternState.blocked,
          LanternState.overdue,
          LanternState.off,
        ])
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PlazaStyle.lantern(state),
                    boxShadow: state == LanternState.off
                        ? null
                        : [
                            BoxShadow(
                              color: PlazaStyle.lantern(state),
                              blurRadius: 6,
                            ),
                          ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  state.word,
                  style: const TextStyle(
                    fontFamily: PlazaStyle.fontText,
                    fontSize: 11,
                    color: Color(0x99FFFFFF),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
