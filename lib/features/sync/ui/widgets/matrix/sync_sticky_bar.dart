import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';

/// The pinned action strip at the foot of a sync modal page.
///
/// The hairline matters: as a bare surface-coloured box over a body painted the
/// same colour, content scrolling underneath was sliced mid-sentence with no
/// cue that the page continued — a truncation bug, not an edge.
class SyncStickyBar extends StatelessWidget {
  const SyncStickyBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        // One level above the page surface, so the bar reads as a distinct
        // opaque shelf rather than page background that happens to cover
        // whatever scrolls beneath it.
        color: tokens.colors.background.level02,
        border: Border(
          top: BorderSide(color: tokens.colors.text.lowEmphasis),
        ),
      ),
      child: Padding(
        padding: WoltModalConfig.pagePadding,
        child: child,
      ),
    );
  }
}
