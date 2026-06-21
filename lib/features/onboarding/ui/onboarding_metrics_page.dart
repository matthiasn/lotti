import 'package:flutter/material.dart';
import 'package:lotti/database/onboarding_metrics_db.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';

/// Mobile / legacy wrapper that keeps the `SliverBoxAdapterPage` chrome and
/// delegates content to [OnboardingMetricsBody], mirroring `MaintenancePage`.
class OnboardingMetricsPage extends StatelessWidget {
  const OnboardingMetricsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.settingsOnboardingMetricsTitle,
      showBackButton: true,
      child: const OnboardingMetricsBody(),
    );
  }
}

/// Read-only developer surface that renders the FTUE funnel derived from
/// [OnboardingMetricsDb]: a summary (install date, active days, baseline
/// cohort, real-aha reached) plus per-event counts, with a debug "clear"
/// action.
///
/// Body copy is intentionally plain English diagnostic text (matching the
/// repaint-rainbow tile in the Maintenance page) — only the navigable tree
/// leaf title is localized.
class OnboardingMetricsBody extends StatefulWidget {
  const OnboardingMetricsBody({super.key});

  @override
  State<OnboardingMetricsBody> createState() => _OnboardingMetricsBodyState();
}

class _OnboardingMetricsBodyState extends State<OnboardingMetricsBody> {
  late Future<_FunnelReport> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_FunnelReport> _load() async {
    final state = await getIt<OnboardingMetricsRepository>().funnelState();
    final events = await getIt<OnboardingMetricsDb>().getAllEvents();
    return _FunnelReport(state: state, eventCount: events.length);
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _clearAll() async {
    final confirmed = await showConfirmationModal(
      context: context,
      message: 'Clear all stored onboarding metrics events?',
      confirmLabel: 'Clear',
    );
    if (!confirmed) return;
    await getIt<OnboardingMetricsDb>().clearAll();
    if (!mounted) return;
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step4),
      child: FutureBuilder<_FunnelReport>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          final report = snapshot.data!;
          final state = report.state;

          final summary = <({IconData icon, String title, String value})>[
            (
              icon: Icons.event_available_outlined,
              title: 'Install first seen (UTC)',
              value: state.installFirstSeen?.toUtc().toIso8601String() ?? '—',
            ),
            (
              icon: Icons.calendar_today_outlined,
              title: 'Active days',
              value: '${state.activeDaysCount}',
            ),
            (
              icon: Icons.looks_one_outlined,
              title: 'Active days in first 7',
              value: '${state.activeDaysInFirst7}',
            ),
            (
              icon: Icons.flag_outlined,
              title: 'Baseline cohort (pre-FTUE)',
              value: state.isBaselineCohort ? 'yes' : 'no',
            ),
            (
              icon: Icons.auto_awesome,
              title: 'Reached real aha',
              value: state.reachedRealAha ? 'yes' : 'no',
            ),
          ];

          return DesignSystemGroupedList(
            children: [
              for (final row in summary)
                DesignSystemListItem(
                  title: row.title,
                  subtitle: row.value,
                  leading: SettingsIcon(icon: row.icon),
                  showDivider: true,
                  dividerIndent: SettingsIcon.dividerIndent(tokens),
                ),
              for (final name in OnboardingEventName.values)
                DesignSystemListItem(
                  title: name.wireName,
                  subtitle: '${state.countOf(name)}',
                  leading: const SettingsIcon(icon: Icons.bar_chart_rounded),
                  showDivider: true,
                  dividerIndent: SettingsIcon.dividerIndent(tokens),
                ),
              DesignSystemListItem(
                title: 'Clear all events',
                subtitle: '${report.eventCount} stored — remove all (debug)',
                leading: const SettingsIcon(icon: Icons.delete_outline_rounded),
                trailing: SettingsIcon.trailingChevron(tokens),
                dividerIndent: SettingsIcon.dividerIndent(tokens),
                onTap: _clearAll,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FunnelReport {
  const _FunnelReport({required this.state, required this.eventCount});

  final OnboardingFunnelState state;
  final int eventCount;
}
