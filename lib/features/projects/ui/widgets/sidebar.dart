import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/avatars/design_system_avatar.dart';
import 'package:lotti/features/design_system/components/branding/design_system_brand_logo.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The left-hand navigation sidebar for the desktop layout.
class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      decoration: BoxDecoration(
        color: ShowcasePalette.surface(context),
        border: Border(
          right: BorderSide(color: ShowcasePalette.border(context)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 32,
            child: Row(
              children: [
                Icon(
                  Icons.menu_rounded,
                  size: 24,
                  color: ShowcasePalette.highText(context),
                ),
                const SizedBox(width: 16),
                const DesignSystemBrandLogo(),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DesignSystemButton(
                label: context.messages.designSystemNavigationNewLabel,
                size: DesignSystemButtonSize.medium,
                leadingIcon: Icons.add_rounded,
                trailingIcon: Icons.keyboard_arrow_down_rounded,
                onPressed: () {},
              ),
              const Spacer(),
              const _AiAssistantOrb(),
            ],
          ),
          const SizedBox(height: 24),
          _SidebarNavItem(
            icon: Icons.calendar_today_outlined,
            label: context.messages.designSystemNavigationMyDailyLabel,
          ),
          const SizedBox(height: 4),
          _SidebarNavItem(
            icon: Icons.format_list_bulleted_rounded,
            label: context.messages.navTabTitleTasks,
          ),
          const SizedBox(height: 4),
          _SidebarNavItem(
            icon: Icons.folder_rounded,
            label: context.messages.designSystemBreadcrumbProjectsLabel,
            active: true,
          ),
          const SizedBox(height: 4),
          _SidebarNavItem(
            icon: Icons.bar_chart_rounded,
            label: context.messages.designSystemNavigationInsightsLabel,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _AiAssistantOrb extends StatelessWidget {
  const _AiAssistantOrb();

  static const _buttonSize = 56.0;
  static const _assetExtent = 108.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.messages.designSystemNavigationAiAssistantSectionTitle,
      child: SizedBox.square(
        dimension: _buttonSize,
        child: OverflowBox(
          minWidth: _assetExtent,
          maxWidth: _assetExtent,
          minHeight: _assetExtent,
          maxHeight: _assetExtent,
          child: ExcludeSemantics(
            child: Image.asset(
              'assets/design_system/ai_assistant_variant_1.png',
              width: _assetExtent,
              height: _assetExtent,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? ShowcasePalette.activeNav(context) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        width: 288,
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: ShowcasePalette.highText(context),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: ShowcasePalette.highText(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The top bar showing the page title and user controls.
class MainTopBar extends StatelessWidget {
  const MainTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      height: 80,
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ShowcasePalette.border(context)),
        ),
      ),
      child: Row(
        children: [
          Text(
            context.messages.designSystemBreadcrumbProjectsLabel,
            style: tokens.typography.styles.heading.heading3.copyWith(
              color: ShowcasePalette.highText(context),
            ),
          ),
          const Spacer(),
          Icon(
            Icons.notifications_none_rounded,
            size: 28,
            color: ShowcasePalette.highText(context),
          ),
          const SizedBox(width: 16),
          const DesignSystemAvatar(
            image: AssetImage('assets/design_system/avatar_placeholder.png'),
          ),
        ],
      ),
    );
  }
}
