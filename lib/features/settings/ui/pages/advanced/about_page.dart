import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:lotti/widgets/misc/tasks_counts.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Mobile / legacy wrapper. Keeps the `SliverBoxAdapterPage` chrome
/// and delegates content to [AboutBody] so the same widget can be
/// rendered inside the Settings V2 detail pane (plan step 7).
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.settingsAboutTitle,
      showBackButton: true,
      child: const AboutBody(),
    );
  }
}

/// Content body for the About page: gradient header with the app
/// name + tagline, version info, and entry/task counts. Extracted
/// from [AboutPage] so the V2 detail pane can host it.
class AboutBody extends ConsumerStatefulWidget {
  const AboutBody({super.key});

  @override
  ConsumerState<AboutBody> createState() => _AboutBodyState();
}

class _AboutBodyState extends ConsumerState<AboutBody> {
  String version = '';
  String buildNumber = '';
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;

  Future<void> getVersions() async {
    if (!(isWindows && isTestEnv)) {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        version = packageInfo.version;
        buildNumber = packageInfo.buildNumber;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _nameFocusNode = FocusNode();
    getVersions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const enhancedIconSize = SpacingConstants.enhancedSmallFontSize * 3;
    const enhancedIconBorderRadius = InputConstants.inputBorderRadius * 1.67;
    const enhancedIconInnerSize = SpacingConstants.enhancedSmallFontSize * 1.5;
    const halfVerticalSpacer = SpacingConstants.verticalModalSpacerHeight / 2;
    const halfSmallSpacer = SpacingConstants.inputSpacerSmallHeight / 2;

    Widget buildCard({required Widget child}) {
      return ModernBaseCard(child: child);
    }

    final tokens = context.designTokens;
    final dailyOsPrefs = ref.watch(dailyOsPreferencesControllerProvider);
    if (!_nameFocusNode.hasFocus &&
        _nameController.text != dailyOsPrefs.userName) {
      _nameController.text = dailyOsPrefs.userName;
    }

    return FutureBuilder<int>(
      future: getIt<JournalDb>().getJournalCount(),
      builder: (context, snapshot) {
        final content = Container(
          decoration: BoxDecoration(
            gradient: GradientThemes.backgroundGradient(context),
          ),
          child: Padding(
            padding: const EdgeInsets.all(SpacingConstants.inputSpacerHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // App Info Card
                EnhancedModernCard(
                  child: Padding(
                    padding: const EdgeInsets.all(
                      SpacingConstants.enhancedSmallFontSize,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: enhancedIconSize,
                          height: enhancedIconSize,
                          decoration: BoxDecoration(
                            gradient: GradientThemes.accentGradient(context),
                            borderRadius: BorderRadius.circular(
                              enhancedIconBorderRadius,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: context.colorScheme.shadow.withValues(
                                  alpha: GradientConstants
                                      .enhancedShadowLightAlpha,
                                ),
                                blurRadius:
                                    GradientConstants.enhancedShadowBlurLight,
                                offset: const Offset(
                                  0,
                                  GradientConstants.enhancedShadowOffsetY / 2,
                                ),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_stories_rounded,
                            size: enhancedIconInnerSize,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: halfVerticalSpacer),
                        const Text(
                          'Lotti',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: halfSmallSpacer),
                        Text(
                          context.messages.settingsAboutAppTagline,
                          style: context.textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: halfVerticalSpacer),
                buildCard(
                  child: _buildDailyOsPersonalizationCard(context, tokens),
                ),
                const SizedBox(height: halfVerticalSpacer),
                // Version Info Card
                buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: context.colorScheme.primary,
                            size: SpacingConstants.inputSpacerHeight,
                          ),
                          const SizedBox(
                            width: SpacingConstants.inputSpacerSmallHeight,
                          ),
                          Text(
                            context.messages.settingsAboutAppInformation,
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: halfVerticalSpacer),
                      _buildInfoRow(
                        context.messages.settingsAboutVersion,
                        '$version ($buildNumber)',
                        context,
                      ),
                      const SizedBox(height: halfSmallSpacer),
                      _buildInfoRow(
                        context.messages.settingsAboutPlatform,
                        _getPlatformName(),
                        context,
                      ),
                      const SizedBox(height: halfSmallSpacer),
                      _buildInfoRow(
                        context.messages.settingsAboutBuildType,
                        _getBuildType(),
                        context,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: halfVerticalSpacer),
                // Statistics Card
                buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.analytics_rounded,
                            color: context.colorScheme.primary,
                            size: SpacingConstants.inputSpacerHeight,
                          ),
                          const SizedBox(
                            width: SpacingConstants.inputSpacerSmallHeight,
                          ),
                          Text(
                            context.messages.settingsAboutYourData,
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: halfVerticalSpacer),
                      _buildInfoRow(
                        context.messages.settingsAboutJournalEntries,
                        '${snapshot.data ?? 0}',
                        context,
                      ),
                      const SizedBox(height: halfSmallSpacer),
                      const FlaggedCount(),
                      const SizedBox(height: halfVerticalSpacer),
                      const TaskCounts(),
                    ],
                  ),
                ),
                const SizedBox(height: halfVerticalSpacer),
              ],
            ),
          ),
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            if (!constraints.hasBoundedHeight) return content;
            return SingleChildScrollView(child: content);
          },
        );
      },
    );
  }

  Widget _buildDailyOsPersonalizationCard(
    BuildContext context,
    DsTokens tokens,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.person_outline_rounded,
              color: tokens.colors.interactive.enabled,
              size: tokens.spacing.step6,
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Text(
                context.messages.settingsAboutDailyOsPersonalizationTitle,
                style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.step4),
        TextField(
          key: const Key('daily_os_user_name_field'),
          controller: _nameController,
          focusNode: _nameFocusNode,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: context.messages.settingsAboutDailyOsUserNameLabel,
            helperText: context.messages.settingsAboutDailyOsUserNameHelper,
            filled: true,
            fillColor: tokens.colors.background.level02,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radii.m),
            ),
          ),
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
          onChanged: ref
              .read(dailyOsPreferencesControllerProvider.notifier)
              .setUserName,
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getPlatformName() {
    if (isMobile) return 'Mobile';
    if (isWindows) return 'Windows';
    if (isMacOS) return 'macOS';
    if (isLinux) return 'Linux';
    return 'Unknown';
  }

  String _getBuildType() {
    if (kReleaseMode) return 'Release';
    if (kProfileMode) return 'Profile';
    return 'Debug';
  }
}
