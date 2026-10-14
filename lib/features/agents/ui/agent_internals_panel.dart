import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_body.dart';
import 'package:lotti/features/agents/ui/agent_maintenance_section.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/side_sheet.dart';
import 'package:lotti/widgets/modal/sized_wolt_side_sheet_type.dart';
import 'package:material_ui/material_ui.dart';

/// Surfaces the agent internals view.
///
/// Opened with [show], in the app's shared side sheet: on a wide window it
/// slides in from the right as a comfortable-width panel (clamped to
/// [minPanelWidth]–[maxPanelWidth]) over the shared scrim; on a phone it is
/// a full-height bottom sheet. Either way the body hosts the same five-tab
/// `AgentInternalsBody` used by the standalone `AgentDetailPage`
/// (Stats / Reports / Conversations / Observations / Activity); this
/// is purely a re-housing of existing content, no functionality is
/// reinvented here.
///
/// A host that governs its agent's report — the task and project summary
/// cards — also passes a [maintenance] scope, which puts that agent's
/// [AgentMaintenanceSection] above the tabs: how the report refreshes, and
/// which AI writes it. It sits *above* the tabs because it is the one thing
/// here the reader changes rather than reads, and because it belongs to the
/// agent as a whole rather than to any one tab's log.
class AgentInternalsPanel extends ConsumerWidget {
  const AgentInternalsPanel({
    required this.agentId,
    required this.agentName,
    this.maintenance,
    super.key,
  });

  /// Narrowest the side panel gets on a wide window; below it the header
  /// would truncate. The sheet still never exceeds the window itself.
  static const double minPanelWidth = 600;

  /// Maximum width of the side panel on very wide screens.
  static const double maxPanelWidth = 800;

  final String agentId;
  final String? agentName;

  /// The agent's maintenance band, when the host offers one. Null for a
  /// surface that only reads the agent — the relationship briefing, the goal
  /// page's activity link — which has no schedule or setup of its own to
  /// govern from here.
  final AgentMaintenanceScope? maintenance;

  /// Opens the internals for [agentId] in the shared side sheet — the same
  /// host the agent conversations use, so every panel beside a page dims the
  /// page and slides in the same way.
  static Future<void> show({
    required BuildContext context,
    required String agentId,
    required String? agentName,
    AgentMaintenanceScope? maintenance,
  }) => showSideSheetPane<void>(
    context: context,
    sideSheet: const SizedWoltSideSheetType(
      widthFraction: 0.5,
      minWidth: minPanelWidth,
      maxWidth: maxPanelWidth,
    ),
    builder: (_) => AgentInternalsPanel(
      agentId: agentId,
      agentName: agentName,
      maintenance: maintenance,
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;

    final identityAsync = ref.watch(agentIdentityProvider(agentId));
    final stateAsync = ref.watch(agentStateProvider(agentId));
    final identity = identityAsync.value?.mapOrNull(agent: (e) => e);
    final resolvedName = agentName?.trim().isNotEmpty == true
        ? agentName!.trim()
        : null;
    final headerSubtitle = resolvedName ?? identity?.displayName;
    // Distinguish "still resolving" from "resolved but unusable" so the
    // body shows a spinner only while in flight; an explicit
    // error / not-found message takes over once the provider settles
    // (mirrors the fallback in `AgentDetailPage`).
    final showLoading = identityAsync.isLoading && identity == null;
    final identityErrorMessage = identityAsync.hasError && identity == null
        ? messages.agentDetailErrorLoading(identityAsync.error.toString())
        : (!identityAsync.isLoading && identity == null)
        ? messages.agentDetailNotFound
        : null;

    // The side sheet owns the panel's width, edge and scrim. The panel owns
    // the ink surface for the tab bodies' ListTiles: a colored DecoratedBox
    // between those tiles and Material hides their ink.
    return Material(
      color: ai.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: messages.aiInternalsTitle,
            subtitle: headerSubtitle,
            onClose: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: showLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : identityErrorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        identityErrorMessage,
                        textAlign: TextAlign.center,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: ai.metaText,
                        ),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (maintenance != null)
                          AgentMaintenanceSection(
                            agentId: agentId,
                            scope: maintenance!,
                          ),
                        AgentInternalsBody(
                          agentId: agentId,
                          lifecycle: identity!.lifecycle,
                          stateAsync: stateAsync,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: ai.borderSoft)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ai.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(LottiIcons.tune, size: 16, color: ai.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: ai.metaText,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonLabel,
            icon: Icon(LottiIcons.close, size: 20, color: ai.metaText),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
