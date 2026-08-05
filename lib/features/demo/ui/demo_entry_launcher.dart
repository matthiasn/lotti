import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/demo/state/demo_mode_gateway.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
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
}) => _launch(context, gateway, (g, locale) => g.enterDemo(locale: locale));

/// Wipes, reseeds and re-enters the demo world. Same progress/failure
/// contract as [launchDemoEnter]. Because the flow ends INSIDE the freshly
/// seeded demo world (a generation switch), no completion toast is possible
/// or needed — the reseeded world itself is the confirmation.
Future<void> launchDemoReset(
  BuildContext context, {
  DemoModeGateway? gateway,
}) => _launch(context, gateway, (g, locale) => g.resetDemo(locale: locale));

Future<void> _launch(
  BuildContext context,
  DemoModeGateway? gateway,
  Future<void> Function(DemoModeGateway gateway, Locale locale) action,
) async {
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
  unawaited(navigator.push(progressRoute));
  try {
    await action(resolved, locale);
    // Success: the profile switch has replaced the whole tree; the old
    // navigator (and its progress route) no longer exists.
  } catch (exception, stackTrace) {
    // Still in the previous world — clear the progress route and log.
    if (progressRoute.isActive) {
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
      leadingIcon: Icons.science_outlined,
      variant: DesignSystemButtonVariant.secondary,
      onPressed: () => unawaited(launchDemoEnter(context, gateway: gateway)),
    );
  }
}
