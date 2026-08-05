import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/demo/state/demo_mode_gateway.dart';
import 'package:lotti/features/demo/ui/demo_exit_sheet.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Wraps the app shell in the persistent demo banner while a demo world is
/// active; outside demo mode the child is returned unchanged.
///
/// The banner reserves its height structurally (Column, never an overlay)
/// and absorbs the top safe-area inset itself, so the child — which would
/// otherwise pad for a status bar now covered by the banner — sees a zero
/// top padding via `MediaQuery.removePadding`.
///
/// Mounted in EVERY generation's shell, this is also the survivor that
/// surfaces demo copy-apply failures: `exitWithCopy` applies the copy plan
/// after the generation switch has torn down the exit sheet, so the gateway
/// reports failures into [DemoCopyFailureNotices] and the freshly mounted
/// scaffold of the REAL generation toasts them here.
class DemoModeScaffold extends ConsumerStatefulWidget {
  const DemoModeScaffold({
    required this.child,
    this.sheetContext,
    this.gateway,
    super.key,
  });

  final Widget child;

  /// Resolves the context the exit sheet is shown from — a context INSIDE
  /// the router's navigator (this widget sits above it, in
  /// `MaterialApp.router`'s builder, where `Navigator.of` has nothing to
  /// find). Defaults to the banner's own context for hosts that mount it
  /// under a navigator (tests). The copy-failure toast targets the same
  /// context, because that is where the scaffolds live.
  final BuildContext Function()? sheetContext;

  /// Test seam; production resolves the gateway from the ambient
  /// `ProfileSwitcherScope`.
  final DemoModeGateway? gateway;

  @override
  ConsumerState<DemoModeScaffold> createState() => _DemoModeScaffoldState();
}

class _DemoModeScaffoldState extends ConsumerState<DemoModeScaffold> {
  @override
  void initState() {
    super.initState();
    DemoCopyFailureNotices.instance.addListener(_onCopyFailureReported);
    // Drain a failure reported while no scaffold was mounted — the apply
    // can fail in the window between generation teardown and this
    // generation's first frame.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _onCopyFailureReported(),
    );
  }

  @override
  void dispose() {
    DemoCopyFailureNotices.instance.removeListener(_onCopyFailureReported);
    super.dispose();
  }

  void _onCopyFailureReported() {
    if (!mounted || !DemoCopyFailureNotices.instance.consume()) return;
    final target = widget.sheetContext?.call() ?? context;
    if (!target.mounted) return;
    target.showToast(
      tone: DesignSystemToastTone.error,
      title: target.messages.demoCopyFailedToast,
    );
  }

  @override
  Widget build(BuildContext context) {
    final demoActive = ref.watch(demoModeActiveProvider);
    if (!demoActive) return widget.child;

    return Column(
      children: [
        DemoModeBanner(
          sheetContext: widget.sheetContext,
          gateway: widget.gateway,
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

/// The persistent top strip marking demo mode.
///
/// Visual grammar follows the `DesignSystemInlineCallout` contract for a
/// message surface: `background.level02` fill, warning-toned hairline
/// (bottom edge only — the strip spans the full width) and leading glyph in
/// the same tone, body copy in `bodySmall`/high emphasis. The whole strip
/// opens the exit sheet; the trailing button is the explicit affordance for
/// the same action.
class DemoModeBanner extends StatelessWidget {
  const DemoModeBanner({this.sheetContext, this.gateway, super.key});

  final BuildContext Function()? sheetContext;
  final DemoModeGateway? gateway;

  void _openExitSheet(BuildContext context) {
    final target = sheetContext?.call() ?? context;
    showDemoExitSheet(target, gateway: gateway);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final tone = tokens.colors.alert.warning.defaultColor;

    return Material(
      color: tokens.colors.background.level02,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            // Bound to the sizing token, mirroring the inline callout: the
            // hairline must retune with BorderWidths.hairline.
            // ignore: avoid_redundant_argument_values
            bottom: BorderSide(color: tone, width: BorderWidths.hairline),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: InkWell(
            onTap: () => _openExitSheet(context),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step4,
                vertical: tokens.spacing.step2,
              ),
              child: Row(
                children: [
                  Icon(Icons.science_outlined, size: IconSizes.s, color: tone),
                  SizedBox(width: tokens.spacing.step3),
                  Expanded(
                    child: Text(
                      context.messages.demoBannerLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  DesignSystemButton(
                    label: context.messages.demoBannerExit,
                    variant: DesignSystemButtonVariant.tertiary,
                    size: DesignSystemButtonSize.dense,
                    onPressed: () => _openExitSheet(context),
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
