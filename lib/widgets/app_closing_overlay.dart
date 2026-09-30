import 'package:flutter/foundation.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Covers the app with a blocking "closing" notice while [closing] is set.
///
/// A quit closes every database before the process ends, which takes a few
/// seconds. Without feedback the window looks hung in that time, and the
/// user is tempted to press Cmd+Q again or keep typing into a store that is
/// already shutting down. While the notice is up, [child] keeps its state
/// but receives neither pointer input nor focus.
class AppClosingOverlay extends StatelessWidget {
  const AppClosingOverlay({
    required this.closing,
    required this.child,
    super.key,
  });

  /// Whether a quit is in progress — `WindowService.closing` in the app.
  /// Null in hosts without a window service, which never show the notice.
  final ValueListenable<bool>? closing;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final closing = this.closing;
    if (closing == null) return child;
    return ValueListenableBuilder<bool>(
      valueListenable: closing,
      child: child,
      builder: (context, isClosing, child) => Stack(
        children: [
          ExcludeFocus(excluding: isClosing, child: child!),
          if (isClosing) const Positioned.fill(child: AppClosingNotice()),
        ],
      ),
    );
  }
}

/// The notice itself: an undismissable scrim with a centred card holding a
/// spinner, a heading and a short reassurance.
class AppClosingNotice extends StatelessWidget {
  const AppClosingNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        ModalBarrier(
          dismissible: false,
          color: ModalUtils.getModalBarrierColor(
            isDark: isDark,
            context: context,
          ),
        ),
        Center(
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step6),
            // The notice sits above the router's Navigator, so no page's
            // Material is behind it; without one, Text falls back to the
            // debug style with a yellow underline.
            child: Material(
              type: MaterialType.transparency,
              child: Semantics(
                liveRegion: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: dsCardSurface(context),
                    borderRadius: BorderRadius.circular(tokens.radii.l),
                    border: Border.all(color: tokens.colors.decorative.level01),
                    boxShadow: DsShadows.floatingSurface,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(tokens.spacing.step6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DesignSystemSpinner(
                          semanticsLabel: messages.appClosingTitle,
                        ),
                        SizedBox(height: tokens.spacing.step5),
                        Text(
                          messages.appClosingTitle,
                          textAlign: TextAlign.center,
                          style: tokens.typography.styles.heading.heading3
                              .copyWith(color: tokens.colors.text.highEmphasis),
                        ),
                        SizedBox(height: tokens.spacing.step2),
                        Text(
                          messages.appClosingMessage,
                          textAlign: TextAlign.center,
                          style: tokens.typography.styles.body.bodyMedium
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
