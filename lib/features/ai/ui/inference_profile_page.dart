import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/ai/ui/inference_profile_form.dart';
import 'package:lotti/features/ai/ui/widgets/profile_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// Embeddable body alias for the Settings V2 detail pane (plan
/// step 9). The V1 page's internal `SettingsPageHeader` overlaps
/// the leaf-panel title; headerless embedded mode comes in step 10
/// polish.
class InferenceProfilesBody extends StatelessWidget {
  const InferenceProfilesBody({super.key});

  @override
  Widget build(BuildContext context) => const InferenceProfilePage();
}

/// Management page listing all inference profiles with create/edit/delete.
class InferenceProfilePage extends ConsumerWidget {
  const InferenceProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(inferenceProfileControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? context.colorScheme.surfaceContainerLowest
          : context.colorScheme.scrim,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SettingsPageHeader(
            title: context.messages.inferenceProfilesTitle,
            showBackButton: true,
          ),
          profilesAsync.when(
            data: (configs) {
              final profiles = configs
                  .whereType<AiConfigInferenceProfile>()
                  .toList();
              if (profiles.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune,
                          size: 48,
                          color: context.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.messages.inferenceProfilesEmpty,
                          style: context.textTheme.bodyLarge?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: profiles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final profile = profiles[index];
                    return ProfileCard(
                      profile: profile,
                      onTap: () => _openEditForm(context, profile),
                    );
                  },
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text(context.messages.commonError)),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: DesignSystemBottomNavigationFabPadding(
        child: FloatingActionButton(
          tooltip: context.messages.inferenceProfileCreateTitle,
          onPressed: () => _openProfileForm(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _openProfileForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const InferenceProfileForm(),
      ),
    );
  }

  void _openEditForm(
    BuildContext context,
    AiConfigInferenceProfile profile,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InferenceProfileForm(existingProfile: profile),
      ),
    );
  }
}
