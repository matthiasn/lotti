import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/demo/media/demo_media_hydrator.dart';
import 'package:lotti/features/demo/state/demo_mode_gateway.dart';
import 'package:lotti/features/demo/ui/demo_entry_launcher.dart';
import 'package:lotti/features/demo/ui/demo_exit_sheet.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onCopyFailureReported();
      unawaited(_refreshStaleDemoWorld());
    });
  }

  /// Repairs a demo world that went stale underfoot.
  ///
  /// This scaffold mounts once per service generation, so its first frame IS
  /// the "booted into a world" signal — for a cold launch that resumes the
  /// demo just as much as for a switch into it. That matters because the
  /// active-profile marker persists across restarts: a user who was inside
  /// the demo when an app update bumped the seed version would otherwise
  /// boot back into the stale world forever, with "Try the demo" hidden
  /// (they are already in it) and only an explicit Reset to escape.
  ///
  /// The gateway owns the decision — and refuses to wipe a world holding
  /// user work. Failures are swallowed by the launcher, which logs and
  /// toasts: a stale world that cannot be repaired must still be usable.
  Future<void> _refreshStaleDemoWorld() async {
    if (!mounted || !ref.read(demoModeActiveProvider)) return;
    // The same guard the copy-failure notice needs: `sheetContext` resolves
    // the router's navigator, which on the first frame of a generation may
    // still point at the outgoing tree's dead element. Reading providers or
    // Localizations off that context throws.
    final target = widget.sheetContext?.call() ?? context;
    if (!target.mounted) return;
    await launchStaleDemoRefresh(target, gateway: widget.gateway);
  }

  @override
  void dispose() {
    DemoCopyFailureNotices.instance.removeListener(_onCopyFailureReported);
    super.dispose();
  }

  void _onCopyFailureReported() {
    if (!mounted) return;
    final target = widget.sheetContext?.call() ?? context;
    if (!target.mounted) return;
    // Consumed LAST: `consume` clears the pending flag, so draining it
    // before the target is known to be mountable would swallow the failure
    // and leave the user with no feedback at all. Bailing out first keeps
    // the report pending for the next listener or post-frame drain.
    if (!DemoCopyFailureNotices.instance.consume()) return;
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
/// A compact two-line identity block makes the demo world unmistakable without
/// taking a second app-chrome row. The identity line names the world and the
/// quieter second line reassures the user that the real journal is untouched.
///
/// Visual grammar follows the `DesignSystemInlineCallout` contract for a
/// message surface, using the blue `background.alternative01` fill and an
/// info-toned hairline (bottom edge only — the strip spans the full width).
/// The leading glyph is
/// the 🐧 penguin: Material has no penguin icon and this repo does not add
/// image assets for chrome, so it is rendered as text through the same
/// typography token as the identity line — the token's `fontFamilyFallback`
/// already lists the platform emoji fonts. It is decorative and excluded
/// from semantics; the identity line carries the meaning on its own.
///
/// The whole strip opens the exit sheet; the trailing button is the explicit
/// affordance for the same action.
class DemoModeBanner extends StatelessWidget {
  const DemoModeBanner({this.sheetContext, this.gateway, super.key});

  /// Decorative only, and deliberately NOT an ARB value: a literal in the
  /// catalogs would invite translators to move, replace or drop it.
  static const String _penguin = '\u{1F427}';

  final BuildContext Function()? sheetContext;
  final DemoModeGateway? gateway;

  void _openExitSheet(BuildContext context) {
    final target = sheetContext?.call() ?? context;
    showDemoExitSheet(target, gateway: gateway);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final tone = tokens.colors.alert.info.defaultColor;

    return Material(
      color: tokens.colors.background.alternative01,
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
                  // Sized against the whole two-line block rather than
                  // the identity line alone: an emoji is drawn well inside
                  // its em box, so at the identity line's own size it reads
                  // as a speck beside two lines of text.
                  ExcludeSemantics(
                    child: Text(
                      _penguin,
                      style: tokens.typography.styles.heading.heading2,
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.messages.demoBannerLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tokens
                                    .typography
                                    .styles
                                    .subtitle
                                    .subtitle1
                                    .copyWith(
                                      color: tokens.colors.text.highEmphasis,
                                    ),
                              ),
                            ),
                            SizedBox(width: tokens.spacing.step2),
                            DesignSystemButton(
                              label: context.messages.demoBannerExit,
                              variant: DesignSystemButtonVariant.tertiary,
                              onPressed: () => _openExitSheet(context),
                            ),
                          ],
                        ),
                        SizedBox(height: tokens.spacing.step1),
                        Text(
                          context.messages.demoBannerSubtitle,
                          // The inline action no longer spends a whole row,
                          // so translated reassurance copy may use a second
                          // line instead of being silently ellipsised.
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.body.bodySmall
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                        ),
                        const _DemoMediaProgressLine(),
                      ],
                    ),
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

class _DemoMediaProgressLine extends StatelessWidget {
  const _DemoMediaProgressLine();

  @override
  Widget build(BuildContext context) {
    if (!getIt.isRegistered<DemoMediaHydrator>()) {
      return const SizedBox.shrink();
    }
    final hydrator = getIt<DemoMediaHydrator>();
    final tokens = context.designTokens;

    return ValueListenableBuilder<DemoMediaHydrationProgress>(
      valueListenable: hydrator.progress,
      builder: (context, progress, _) {
        if (progress.isComplete) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(top: tokens.spacing.step1),
          child: DesignSystemProgressBar(
            value: progress.fraction,
            label: progress.hasFailures
                ? context.messages.demoMediaDownloadRetry
                : context.messages.demoMediaDownloadProgress,
            progressText: context.messages.demoMediaDownloadCount(
              progress.completed,
              progress.total,
            ),
          ),
        );
      },
    );
  }
}
