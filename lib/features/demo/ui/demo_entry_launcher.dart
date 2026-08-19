import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/demo/state/demo_mode_gateway.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/domain_logging.dart';

/// Enters the demo world from a UI entry point.
///
/// Pushes a blocking full-screen progress route on the ROOT navigator (the
/// seed run can take a few seconds on first entry), then hands over to the
/// gateway. On success the profile switch replaces the entire widget tree —
/// progress route included — so nothing is popped; on failure the route is
/// removed and the error is logged (the entry points must not crash the
/// host surface).
Future<void> launchDemoEnter(
  BuildContext context, {
  DemoModeGateway? gateway,
}) => _launch(context, gateway, (g, locale, showProgress) {
  showProgress();
  return g.enterDemo(locale: locale);
});

/// Reseeds the demo world the app is ALREADY in when its seed content has
/// gone stale and nothing would be lost — see
/// [DemoModeGateway.refreshStaleDemoWorld] for the decision, which this only
/// drives the UI for.
///
/// Called on the first frame of every generation that boots into the demo,
/// so it must be silent when there is nothing to do: progress is raised only
/// once the gateway commits to reseeding, and an up-to-date world (the
/// overwhelmingly common case) never sees a blocking page.
///
/// A failure is logged but NOT toasted. The user did not ask for this — an
/// error about an automatic repair they never initiated is noise, and the
/// stale world is still perfectly usable.
Future<void> launchStaleDemoRefresh(
  BuildContext context, {
  DemoModeGateway? gateway,
}) => _launch(
  context,
  gateway,
  (g, locale, showProgress) => g.refreshStaleDemoWorld(
    locale: locale,
    onReseedStarted: showProgress,
  ),
  toastFailure: false,
);

/// Wipes, reseeds and re-enters the demo world. Same progress/failure
/// contract as [launchDemoEnter]. Because the flow ends INSIDE the freshly
/// seeded demo world (a generation switch), no completion toast is possible
/// or needed — the reseeded world itself is the confirmation.
Future<void> launchDemoReset(
  BuildContext context, {
  DemoModeGateway? gateway,
}) => _launch(context, gateway, (g, locale, showProgress) {
  showProgress();
  return g.resetDemo(locale: locale);
});

Future<void> _launch(
  BuildContext context,
  DemoModeGateway? gateway,
  Future<void> Function(
    DemoModeGateway gateway,
    Locale locale,
    VoidCallback showProgress,
  )
  action, {

  /// Whether a failure is surfaced to the user. True for taps (a tap must
  /// not fail silently); false for automatic repair the user never asked
  /// for.
  bool toastFailure = true,
}) async {
  final resolved = gateway ?? maybeDemoModeGatewayOf(context);
  if (resolved == null) {
    // No ProfileSwitcherScope above this context — a bare test harness.
    // Production always mounts the scope at the root.
    return;
  }
  final locale = Localizations.localeOf(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final progressRoute = MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => const DemoEnteringProgressPage(),
  );
  // Pushed by the action, not here: an action that may decide to do nothing
  // must not flash a blocking page on the way to that decision.
  var pushed = false;
  void showProgress() {
    if (pushed) return;
    pushed = true;
    navigator.push(progressRoute);
  }

  try {
    await action(resolved, locale, showProgress);
    // A switch has replaced the whole tree, progress route included. An
    // action that decided to do NOTHING leaves this generation alive, so a
    // route raised on the way there has to come back off — otherwise the
    // user is stranded on a progress page that will never resolve.
    if (pushed && progressRoute.isActive) {
      navigator.removeRoute(progressRoute);
    }
  } catch (exception, stackTrace) {
    // Still in the previous world — clear the progress route, log, and (for
    // a user-initiated action) tell them why nothing happened.
    if (pushed && progressRoute.isActive) {
      navigator.removeRoute(progressRoute);
    }
    if (getIt.isRegistered<DomainLogger>()) {
      getIt<DomainLogger>().error(
        LogDomain.general,
        exception,
        stackTrace: stackTrace,
        subDomain: 'demoEntryLauncher',
      );
    }
    if (toastFailure && context.mounted) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.demoEnterFailedToast,
      );
    }
  }
}

/// Full-screen blocking progress shown while a demo world is created and
/// seeded. Back navigation is disabled — the switch must not be interrupted
/// mid-seed.
class DemoEnteringProgressPage extends StatelessWidget {
  const DemoEnteringProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              SizedBox(height: tokens.spacing.step5),
              Text(
                context.messages.demoEnteringProgress,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Try the demo" call to action for empty states.
///
/// Self-gating: renders nothing while the demo world is active (nothing to
/// try — the user is in it) or when the journal is NOT truly empty (an
/// empty list caused by filters must not advertise the demo). Callers drop
/// it into an empty state's `action` slot unconditionally.
class DemoTryButton extends ConsumerWidget {
  const DemoTryButton({this.gateway, super.key});

  /// Test seam; production resolves via the ambient `ProfileSwitcherScope`.
  final DemoModeGateway? gateway;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoActive = ref.watch(demoModeActiveProvider);
    final journalEmpty = ref.watch(demoJournalEmptyProvider).value ?? false;
    if (demoActive || !journalEmpty) return const SizedBox.shrink();

    return DesignSystemButton(
      label: context.messages.demoTryButton,
      leadingIcon: LottiIcons.science,
      variant: DesignSystemButtonVariant.secondary,
      onPressed: () => unawaited(launchDemoEnter(context, gateway: gateway)),
    );
  }
}
