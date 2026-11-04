import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
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
/// fields across a void; the [body] scrolling in it; and the footer always on
/// screen on an opaque band — *Cancel* on the leading edge when there is one,
/// the [primary] action at its own width on the trailing edge. While [busy]
/// the body holds still under a save in flight.
class AgentEditorScaffold extends StatelessWidget {
  const AgentEditorScaffold({
    required this.title,
    required this.onBack,
    required this.body,
    required this.primary,
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

  /// The confirming action — a `DesignSystemButton` at its intrinsic width.
  final Widget primary;

  /// The footer's way out; null leaves the footer to [primary] alone.
  final VoidCallback? onCancel;
  final Key? cancelKey;

  /// Pinned above the scrolling body — a wizard's step progress.
  final Widget? header;

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: onBack),
        title: Text(title),
      ),
      body: SafeArea(
        child: DetailContentWidth(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: kActionListContentMaxWidth,
              ),
              child: Column(
                children: [
                  ?header,
                  Expanded(
                    child: AbsorbPointer(
                      absorbing: busy,
                      child: ListView(
                        padding: EdgeInsets.symmetric(
                          vertical: tokens.spacing.step5,
                        ),
                        children: body,
                      ),
                    ),
                  ),
                  _AgentEditorFooter(
                    primary: primary,
                    onCancel: onCancel,
                    cancelKey: cancelKey,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Always on screen, on an opaque band: scrolling content ends at a hairline
/// instead of being guillotined behind a floating pill.
class _AgentEditorFooter extends StatelessWidget {
  const _AgentEditorFooter({
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: tokens.colors.decorative.level01),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: tokens.spacing.step4,
          bottom:
              tokens.spacing.step4 +
              DesignSystemBottomNavigationBar.occupiedHeight(context),
        ),
        child: DesignSystemModalActionBar(
          layout: DesignSystemModalActionBarLayout.compactPrimary,
          secondary: [
            if (onCancel case final onCancel?)
              DesignSystemButton(
                key: cancelKey,
                label: context.messages.cancelButton,
                variant: DesignSystemButtonVariant.secondary,
                onPressed: onCancel,
              ),
          ],
          primary: primary,
        ),
      ),
    );
  }
}
