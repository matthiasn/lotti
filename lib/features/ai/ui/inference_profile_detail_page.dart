import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/inference_profile_form.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// URL-route entry point for the inference profile edit flow.
///
/// `InferenceProfileForm` takes a fully-resolved [AiConfigInferenceProfile]
/// because the legacy `Navigator.push` callers had the config in hand at
/// the call site. URL-based routing (the Settings V2 master/detail panel
/// + the Beamer mobile stack) only carries the profile id, so this
/// wrapper resolves the id via Riverpod and hands the loaded config
/// down. Mirrors how `InferenceModelEditPage` already supports id-only
/// construction; kept as a separate page class so the form's existing
/// `existingProfile`-taking constructor stays unchanged.
class InferenceProfileDetailPage extends ConsumerWidget {
  const InferenceProfileDetailPage({required this.profileId, super.key});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(aiConfigByIdProvider(profileId));
    return configAsync.when(
      data: (config) {
        if (config is! AiConfigInferenceProfile) {
          return Scaffold(
            body: Center(
              child: Text(context.messages.inferenceProfileDetailNotFound),
            ),
          );
        }
        return InferenceProfileForm(existingProfile: config);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Text(
            context.messages.inferenceProfileDetailLoadError(error.toString()),
          ),
        ),
      ),
    );
  }
}
