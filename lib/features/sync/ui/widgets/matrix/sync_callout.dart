import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// The sync feature's message grammar: a level02 surface with an alert-toned
/// border and leading icon.
///
/// Deliberately distinct from the `SyncFlowSection` hairline card — a callout is
/// something to read, not something to press — and shared so the roster's
/// paused banner and the add-device security warning cannot drift apart.
class SyncCallout extends StatelessWidget {
  const SyncCallout({
    required this.icon,
    required this.text,
    super.key,
    this.tone,
    this.calloutKey,
  });

  final IconData icon;
  final String text;

  /// Border and icon colour; defaults to the warning tone.
  final Color? tone;

  /// Key applied to the callout container, for tests that assert presence.
  final Key? calloutKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = tone ?? tokens.colors.alert.warning.defaultColor;

    return DecoratedBox(
      key: calloutKey,
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: tokens.spacing.step6, color: color),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Text(
                text,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
