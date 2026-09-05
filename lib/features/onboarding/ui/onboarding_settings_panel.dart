import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/demo/ai/demo_ai_gate.dart';
import 'package:lotti/features/demo/state/demo_mode_gateway.dart';
import 'package:lotti/features/demo/ui/demo_ai_setup_sheet.dart';
import 'package:lotti/features/demo/ui/demo_entry_launcher.dart';
import 'package:lotti/features/demo/ui/demo_exit_sheet.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/state/onboarding_trigger_service.dart';
import 'package:lotti/features/onboarding/ui/onboarding_welcome_modal.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:material_ui/material_ui.dart';

/// Mobile / legacy wrapper that keeps the `SliverBoxAdapterPage` chrome and
/// delegates content to [OnboardingSettingsBody], mirroring
/// `OnboardingMetricsPage`.
class OnboardingSettingsPage extends StatelessWidget {
  const OnboardingSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.settingsOnboardingTitle,
      showBackButton: true,
      child: const OnboardingSettingsBody(),
    );
  }
}

/// Top-level Settings surface that lets a user find their way back to the
/// FTUE welcome flow at any time, and manage the demo workspace.
///
/// The replay *entry* is deliberately independent of `OnboardingWelcomeCadence`'s
/// auto-show budget (`state/onboarding_trigger_service.dart`), which only
/// governs *unprompted* re-shows on cold start (capped at
/// `onboardingWelcomeMaxShows` over `onboardingWelcomeWindow`). Tapping the
/// entry always opens the flow regardless of how many times it has already
/// auto-shown — per the plan, "always find a way back to showing this
/// onboarding". Completing the flow here (connecting a provider) does still
/// retire the auto-show gate via [markOnboardingWelcomeCompleted], exactly as
/// the auto-show path does, so a replay-then-connect user is not auto-nagged
/// again on the next cold start.
///
/// The demo rows resolve their [DemoModeGateway] from the ambient
/// `ProfileSwitcherScope`; hosts without one (bare tests) simply don't show
/// the demo section unless [demoGateway] is injected.
class OnboardingSettingsBody extends ConsumerStatefulWidget {
  const OnboardingSettingsBody({this.demoGateway, super.key});

  /// Test seam; production resolves via the ambient `ProfileSwitcherScope`.
  final DemoModeGateway? demoGateway;

  @override
  ConsumerState<OnboardingSettingsBody> createState() =>
      _OnboardingSettingsBodyState();
}

class _OnboardingSettingsBodyState
    extends ConsumerState<OnboardingSettingsBody> {
  late Future<bool> _reachedRealAha;
  DemoModeGateway? _gateway;
  var _gatewayResolved = false;
  Future<bool>? _demoExists;

  @override
  void initState() {
    super.initState();
    _reachedRealAha = _loadReachedRealAha();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_gatewayResolved) return;
    _gatewayResolved = true;
    _gateway = widget.demoGateway ?? maybeDemoModeGatewayOf(context);
    _demoExists = _gateway?.demoProfileExists();
  }

  /// Reads `OnboardingFunnelState.reachedRealAha` for the status row.
  /// Defaults to `false` ("not started yet") when the metrics repository
  /// isn't registered (most unit tests, and any build where the substrate
  /// failed to initialize) or a read throws -- a metrics-store hiccup must
  /// never crash this settings row, only under-report its status.
  Future<bool> _loadReachedRealAha() async {
    if (!getIt.isRegistered<OnboardingMetricsRepository>()) return false;
    try {
      final state = await getIt<OnboardingMetricsRepository>().funnelState();
      return state.reachedRealAha;
    } catch (_) {
      return false;
    }
  }

  Future<void> _replay() async {
    await OnboardingWelcomeModal.show(
      context,
      onDismiss: () {},
      // Connecting a provider during a replay retires the auto-show gate too,
      // so a user who sets up here isn't auto-shown the welcome again on the
      // next cold start. `markOnboardingWelcomeCompleted` logs-and-swallows any
      // `SettingsDb` failure itself, so this fire-and-forget is safe.
      onCompleted: () => unawaited(markOnboardingWelcomeCompleted()),
    );
    if (!mounted) return;
    // The replay may have just landed a real task -- refresh the status row
    // so it reflects the new funnel state immediately rather than waiting
    // for the next time this panel mounts.
    setState(() {
      _reachedRealAha = _loadReachedRealAha();
    });
  }

  Future<void> _resetDemo(DemoModeGateway gateway) async {
    final confirmed = await showConfirmationModal(
      context: context,
      message: context.messages.demoSettingsResetConfirm,
      confirmLabel: context.messages.demoSettingsResetTitle,
    );
    if (!confirmed || !mounted) return;
    // Ends INSIDE the freshly seeded demo world (a generation switch), so
    // no completion toast is possible — the reseeded world is the
    // confirmation.
    await launchDemoReset(context, gateway: gateway);
  }

  Future<void> _deleteDemo(DemoModeGateway gateway) async {
    final confirmed = await showConfirmationModal(
      context: context,
      message: context.messages.demoSettingsDeleteConfirm,
      confirmLabel: context.messages.demoSettingsDeleteTitle,
    );
    if (!confirmed || !mounted) return;
    try {
      await gateway.deleteDemo();
    } catch (exception, stackTrace) {
      if (getIt.isRegistered<DomainLogger>()) {
        getIt<DomainLogger>().error(
          LogDomain.general,
          exception,
          stackTrace: stackTrace,
          subDomain: 'onboardingSettingsDeleteDemo',
        );
      }
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.demoDeleteFailedToast,
        );
      }
      return;
    }
    if (!mounted) return;
    context.showToast(
      tone: DesignSystemToastTone.success,
      title: context.messages.demoSettingsDeleteToast,
    );
    setState(() {
      _demoExists = gateway.demoProfileExists();
    });
  }

  List<DesignSystemListItem> _demoRows(
    BuildContext context,
    DsTokens tokens, {
    required DemoModeGateway gateway,
    required bool demoExists,
    required bool? realAiAvailable,
  }) {
    final m = context.messages;
    if (gateway.isDemoActive) {
      return [
        // Advanced: enable real AI inside the demo. While no real provider
        // exists the row opens the guided setup; once one does it becomes a
        // status row. Hidden while availability is still resolving (null) —
        // a row must not claim either state it cannot know yet.
        if (realAiAvailable != null)
          if (realAiAvailable)
            DesignSystemListItem(
              title: m.demoSettingsRealAiTitle,
              subtitle: m.demoSettingsRealAiActiveSubtitle,
              leading: const SettingsIcon(icon: LottiIcons.confirmCircled),
              showDivider: true,
              dividerIndent: SettingsIcon.dividerIndent(tokens),
            )
          else
            DesignSystemListItem(
              title: m.demoSettingsRealAiTitle,
              subtitle: m.demoSettingsRealAiSubtitle,
              leading: const SettingsIcon(icon: LottiIcons.aiSpark),
              trailing: SettingsIcon.trailingChevron(tokens),
              showDivider: true,
              dividerIndent: SettingsIcon.dividerIndent(tokens),
              onTap: () => unawaited(DemoAiSetupSheet.show(context)),
            ),
        DesignSystemListItem(
          title: m.demoSettingsExitTitle,
          leading: const SettingsIcon(icon: LottiIcons.signOut),
          showDivider: true,
          dividerIndent: SettingsIcon.dividerIndent(tokens),
          onTap: () => showDemoExitSheet(context, gateway: gateway),
        ),
        DesignSystemListItem(
          title: m.demoSettingsResetTitle,
          leading: const SettingsIcon(icon: LottiIcons.replay),
          dividerIndent: SettingsIcon.dividerIndent(tokens),
          onTap: () => unawaited(_resetDemo(gateway)),
        ),
      ];
    }
    return [
      DesignSystemListItem(
        title: demoExists ? m.demoSettingsResumeTitle : m.demoSettingsTryTitle,
        subtitle: m.demoSettingsTrySubtitle,
        leading: const SettingsIcon(icon: LottiIcons.science),
        showDivider: demoExists,
        dividerIndent: SettingsIcon.dividerIndent(tokens),
        onTap: () => unawaited(launchDemoEnter(context, gateway: gateway)),
      ),
      if (demoExists) ...[
        DesignSystemListItem(
          title: m.demoSettingsResetTitle,
          leading: const SettingsIcon(icon: LottiIcons.replay),
          showDivider: true,
          dividerIndent: SettingsIcon.dividerIndent(tokens),
          onTap: () => unawaited(_resetDemo(gateway)),
        ),
        DesignSystemListItem(
          title: m.demoSettingsDeleteTitle,
          leading: const SettingsIcon(icon: LottiIcons.delete),
          dividerIndent: SettingsIcon.dividerIndent(tokens),
          onTap: () => unawaited(_deleteDemo(gateway)),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final m = context.messages;
    final gateway = _gateway;
    // Only resolved while the demo is active — outside it the row never
    // shows, so the AI config database is never touched from here.
    final realAiAvailable = (gateway?.isDemoActive ?? false)
        ? ref.watch(demoRealAiAvailableProvider).value
        : null;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step4),
      child: FutureBuilder<bool>(
        future: _reachedRealAha,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState != ConnectionState.done;
          final activated = snapshot.data ?? false;

          return FutureBuilder<bool>(
            future: _demoExists,
            builder: (context, demoSnapshot) {
              final demoExists = demoSnapshot.data ?? false;
              final demoRows = gateway == null
                  ? const <DesignSystemListItem>[]
                  : _demoRows(
                      context,
                      tokens,
                      gateway: gateway,
                      demoExists: demoExists,
                      realAiAvailable: realAiAvailable,
                    );

              return DesignSystemGroupedList(
                children: [
                  DesignSystemListItem(
                    title: m.settingsOnboardingStatusTitle,
                    subtitle: loading
                        ? m.settingsOnboardingStatusLoading
                        : (activated
                              ? m.settingsOnboardingStatusActivated
                              : m.settingsOnboardingStatusNotActivated),
                    leading: SettingsIcon(
                      icon: activated
                          ? LottiIcons.confirmCircled
                          : LottiIcons.pending,
                    ),
                    showDivider: true,
                    dividerIndent: SettingsIcon.dividerIndent(tokens),
                  ),
                  DesignSystemListItem(
                    title: activated
                        ? m.settingsOnboardingReplayTitle
                        : m.settingsOnboardingStartTitle,
                    subtitle: m.settingsOnboardingActionSubtitle,
                    leading: const SettingsIcon(
                      icon: LottiIcons.rocket,
                    ),
                    trailing: SettingsIcon.trailingChevron(tokens),
                    showDivider: demoRows.isNotEmpty,
                    dividerIndent: SettingsIcon.dividerIndent(tokens),
                    onTap: _replay,
                  ),
                  ...demoRows,
                ],
              );
            },
          );
        },
      ),
    );
  }
}
