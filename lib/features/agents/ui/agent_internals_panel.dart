import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_body.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Right-side overlay that surfaces the agent internals view.
///
/// Slides in from the right over a darkened scrim, sized to a
/// comfortable reading width (clamped to [minPanelWidth]–[maxPanelWidth]).
/// The body hosts the same five-tab `AgentInternalsBody` used by the
/// standalone `AgentDetailPage` (Stats / Reports / Conversations /
/// Observations / Activity) — this is purely a re-housing of existing
/// content into a side panel; no functionality is reinvented here.
class AgentInternalsPanel extends ConsumerWidget {
  const AgentInternalsPanel({
    required this.agentId,
    required this.agentName,
    super.key,
  });

  static const double minPanelWidth = 600;
  static const double maxPanelWidth = 800;

  final String agentId;
  final String? agentName;

  /// Builds a [PageRoute] that fades the scrim in and slides the panel
  /// in from the right. Use via `Navigator.of(context).push(...)`.
  static PageRoute<void> route({
    required String agentId,
    required String? agentName,
  }) {
    return PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AgentInternalsPanel(agentId: agentId, agentName: agentName);
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final size = MediaQuery.sizeOf(context);
    final width = size.width.clamp(minPanelWidth, maxPanelWidth);

    final identityAsync = ref.watch(agentIdentityProvider(agentId));
    final stateAsync = ref.watch(agentStateProvider(agentId));
    final identity = identityAsync.value?.mapOrNull(agent: (e) => e);
    final resolvedName = agentName?.trim().isNotEmpty == true
        ? agentName!.trim()
        : null;
    final headerSubtitle = resolvedName ?? identity?.displayName;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SafeArea(
              left: false,
              child: SizedBox(
                width: width,
                height: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ai.background,
                    border: Border(
                      left: BorderSide(color: ai.border),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(
                        title: messages.aiInternalsTitle,
                        subtitle: headerSubtitle,
                        onClose: () => Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: identity == null
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                child: AgentInternalsBody(
                                  agentId: agentId,
                                  lifecycle: identity.lifecycle,
                                  stateAsync: stateAsync,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
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
            child: Icon(Icons.tune_rounded, size: 16, color: ai.accent),
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
            icon: Icon(Icons.close_rounded, size: 20, color: ai.metaText),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
