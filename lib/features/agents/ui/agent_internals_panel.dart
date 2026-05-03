import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_body.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Surfaces the agent internals view.
///
/// On wide screens (≥ [mobileBreakpoint]) it slides in from the right
/// as a comfortable-width panel (clamped to
/// [minPanelWidth]–[maxPanelWidth]) over a darkened scrim. On narrow
/// screens — phones in portrait, slim split-view windows — it snaps to
/// a full-screen modal that slides in from the bottom, so the header
/// stays on-screen and the body is comfortable to read on small
/// devices. Either way the body hosts the same five-tab
/// `AgentInternalsBody` used by the standalone `AgentDetailPage`
/// (Stats / Reports / Conversations / Observations / Activity); this
/// is purely a re-housing of existing content, no functionality is
/// reinvented here.
class AgentInternalsPanel extends ConsumerWidget {
  const AgentInternalsPanel({
    required this.agentId,
    required this.agentName,
    super.key,
  });

  /// Minimum width before falling back to a full-screen modal layout.
  /// Below this the side-panel chrome no longer fits without truncating
  /// the header.
  static const double minPanelWidth = 600;

  /// Maximum width of the side-panel layout on very wide screens.
  static const double maxPanelWidth = 800;

  /// Screen-width threshold under which the panel renders as a
  /// full-screen modal instead of a right-aligned side panel.
  static const double mobileBreakpoint = minPanelWidth;

  final String agentId;
  final String? agentName;

  /// Builds a [PageRoute] that fades the scrim in and slides the panel
  /// in from the right on wide screens, or up from the bottom on
  /// narrow screens. Use via `Navigator.of(context).push(...)`.
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
        // Pick the slide direction based on the layout the panel will
        // render in for this screen size.
        final isMobile = MediaQuery.sizeOf(context).width < mobileBreakpoint;
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: isMobile ? const Offset(0, 1) : const Offset(1, 0),
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
    final isMobile = size.width < mobileBreakpoint;
    // On wide screens the panel takes a comfortable reading width
    // clamped between [minPanelWidth] and [maxPanelWidth]. On narrow
    // screens it renders as a full-screen modal at the device width.
    final width = isMobile
        ? size.width
        : size.width.clamp(minPanelWidth, maxPanelWidth);

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

    final panelBody = SizedBox(
      width: width,
      height: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ai.background,
          border: isMobile ? null : Border(left: BorderSide(color: ai.border)),
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
                          style: tokens.typography.styles.body.bodySmall
                              .copyWith(color: ai.metaText),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: AgentInternalsBody(
                        agentId: agentId,
                        lifecycle: identity!.lifecycle,
                        stateAsync: stateAsync,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );

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
            // Mobile: full-screen modal. Wide screens: right-aligned
            // panel that vacates the left side for the underlying page.
            alignment: isMobile ? Alignment.center : Alignment.centerRight,
            child: SafeArea(
              // Cover the left inset on mobile (modal occupies the full
              // width so the system gesture / notch needs padding).
              // Skip it on wide screens — the panel is right-aligned and
              // never overlaps the left inset.
              left: isMobile,
              child: panelBody,
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
