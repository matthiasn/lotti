import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/ai/ui/inference_profile_form.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';

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
              final profiles =
                  configs.whereType<AiConfigInferenceProfile>().toList();
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
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final profile = profiles[index];
                    return _ProfileCard(profile: profile);
                  },
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('Error: $error')),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openProfileForm(context),
        child: const Icon(Icons.add),
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
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.profile});

  final AiConfigInferenceProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      color: context.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openEditForm(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      profile.name,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (profile.desktopOnly)
                    Chip(
                      label: Text(
                        context.messages.inferenceProfileDesktopOnly,
                        style: context.textTheme.labelSmall,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  if (profile.isDefault)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _SlotRow(
                label: context.messages.inferenceProfileThinking,
                modelId: profile.thinkingModelId,
              ),
              if (profile.imageRecognitionModelId != null)
                _SlotRow(
                  label: context.messages.inferenceProfileImageRecognition,
                  modelId: profile.imageRecognitionModelId!,
                ),
              if (profile.transcriptionModelId != null)
                _SlotRow(
                  label: context.messages.inferenceProfileTranscription,
                  modelId: profile.transcriptionModelId!,
                ),
              if (profile.imageGenerationModelId != null)
                _SlotRow(
                  label: context.messages.inferenceProfileImageGeneration,
                  modelId: profile.imageGenerationModelId!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEditForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InferenceProfileForm(existingProfile: profile),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.label, required this.modelId});

  final String label;
  final String modelId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              modelId,
              style: context.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
