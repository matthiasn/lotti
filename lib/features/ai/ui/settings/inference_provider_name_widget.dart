import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class InferenceProviderNameWidget extends ConsumerWidget {
  const InferenceProviderNameWidget({
    required this.providerId,
    super.key,
  });

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(aiConfigByIdProvider(providerId));

    return config.when(
      data: (config) =>
          Text(config?.name ?? context.messages.aiConfigSelectProviderNotFound),
      error: (err, stack) =>
          Text(context.messages.aiConfigSelectProviderNotFound),
      loading: () => const Text(''),
    );
  }
}
