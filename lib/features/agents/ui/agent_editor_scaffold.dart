import 'dart:math' as math;

import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:material_ui/material_ui.dart';

/// The page that edits something an agent serves — a goal, a person: one
/// container for both editors, so they are the same kind of screen on the
/// same canvas, not a page beside a sheet.
///
/// An app bar with the way back and the editor's title; a reading column
/// capped at the action-list measure, so a wide window does not stretch the
/// fields across a void; the [body] scrolling in it; and a sticky action bar
/// that the body scrolls behind — *Cancel* on the leading edge when there is
/// one, the primary action on the trailing edge. While [busy] the body holds
/// still and the primary shows its save in flight.
///
/// The bar is the app's sticky action bar, built from the design system's
/// own parts: a [DesignSystemGlassStrip] carrying a
/// [DesignSystemModalActionBar] of [DesignSystemButtonSize.large] buttons —
/// the size every other action bar in the app uses. The scaffold builds the
/// buttons itself from [primaryLabel] and [onPrimary], so an editor cannot
/// hand it a button of another size.
class AgentEditorScaffold extends StatelessWidget {
  const AgentEditorScaffold({
    required this.title,
    required this.onBack,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryKey,
    this.onCancel,
    this.cancelKey,
    this.header,
    this.busy = false,
    super.key,
  });

  final String title;

  /// The app bar's way back; null disables it (a save in flight).
  final VoidCallback? onBack;

  /// The editor's sections, top to bottom.
  final List<Widget> body;

  /// The confirming action's label — *Save*, *Continue*, *Create*.
  final String primaryLabel;

  /// The confirming action; null disables it (nothing to save yet).
  final VoidCallback? onPrimary;
  final Key? primaryKey;

  /// The footer's way out; null leaves the footer to the primary alone.
  final VoidCallback? onCancel;
  final Key? cancelKey;

  /// Pinned above the scrolling body — a wizard's step progress.
  final Widget? header;

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Scaffold(
      // The body scrolls behind the bar, so its glass has something to blur;
      // the body's bottom padding then carries the bar's height.
      extendBody: true,
      appBar: AppBar(
        leading: BackButton(onPressed: onBack),
        title: Text(title),
      ),
      body: SafeArea(
        bottom: false,
        child: _EditorColumn(
          child: Column(
            children: [
              ?header,
              Expanded(
                child: AbsorbPointer(
                  absorbing: busy,
                  child: Builder(
                    // Read under the Scaffold's body, where the bottom
                    // padding includes the bar the body extends behind.
                    builder: (context) => ListView(
                      padding: EdgeInsets.only(
                        top: tokens.spacing.step5,
                        bottom:
                            tokens.spacing.step5 +
                            MediaQuery.paddingOf(context).bottom,
                      ),
                      children: body,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _AgentEditorActionBar(
        primary: DesignSystemButton(
          key: primaryKey,
          label: primaryLabel,
          size: DesignSystemButtonSize.large,
          onPressed: onPrimary,
          isLoading: busy,
        ),
        onCancel: onCancel,
        cancelKey: cancelKey,
      ),
    );
  }
}

/// The editor's reading column: the detail gutter, capped at the
/// action-list measure. The body and the action bar both sit in it, so the
/// bar's buttons line up with the fields above them on any width.
class _EditorColumn extends StatelessWidget {
  const _EditorColumn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DetailContentWidth(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: kActionListContentMaxWidth,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The sticky action bar: always on screen, on glass, with the body
/// scrolling behind it.
class _AgentEditorActionBar extends StatelessWidget {
  const _AgentEditorActionBar({
    required this.primary,
    required this.onCancel,
    required this.cancelKey,
  });

  final Widget primary;
  final VoidCallback? onCancel;
  final Key? cancelKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // A docked launcher already absorbs the safe-area inset into its own
    // height, so the bar clears whichever of the two is taller, never both.
    final bottomClearance = math.max(
      MediaQuery.paddingOf(context).bottom,
      DesignSystemBottomNavigationBar.occupiedHeight(context),
    );
    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.only(
          top: tokens.spacing.step4,
          bottom: tokens.spacing.step4 + bottomClearance,
        ),
        child: _EditorColumn(
          child: DesignSystemModalActionBar(
            layout: DesignSystemModalActionBarLayout.compactPrimary,
            secondary: [
              if (onCancel case final onCancel?)
                DesignSystemButton(
                  key: cancelKey,
                  label: context.messages.cancelButton,
                  variant: DesignSystemButtonVariant.secondary,
                  size: DesignSystemButtonSize.large,
                  onPressed: onCancel,
                ),
            ],
            primary: primary,
          ),
        ),
      ),
    );
  }
}
