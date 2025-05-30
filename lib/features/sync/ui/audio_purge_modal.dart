import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/modals.dart';

class AudioPurgeState {
  const AudioPurgeState({
    this.isPurging = false,
    this.progress = 0.0,
    this.error,
  });

  final bool isPurging;
  final double progress;
  final String? error;

  AudioPurgeState copyWith({
    bool? isPurging,
    double? progress,
    String? error,
  }) {
    return AudioPurgeState(
      isPurging: isPurging ?? this.isPurging,
      progress: progress ?? this.progress,
      error: error,
    );
  }
}

final audioPurgeStateProvider = StateProvider<AudioPurgeState>((ref) {
  return const AudioPurgeState();
});

class AudioPurgeModal {
  const AudioPurgeModal._();

  static Future<void> show(BuildContext context) async {
    final container = ProviderScope.containerOf(context);
    final stateProvider = audioPurgeStateProvider;

    await ModalUtils.showConfirmationAndProgressModal(
      context: context,
      message: context.messages.maintenancePurgeAudioModelsMessage,
      confirmLabel: context.messages.maintenancePurgeAudioModelsConfirm,
      operation: () async {
        try {
          container.read(stateProvider.notifier).state = const AudioPurgeState(
            isPurging: true,
          );
          await getIt<Maintenance>().purgeAudioModels();
          container.read(stateProvider.notifier).state = const AudioPurgeState(
            progress: 1,
          );
        } catch (e) {
          container.read(stateProvider.notifier).state = AudioPurgeState(
            error: e.toString(),
          );
        }
      },
      progressBuilder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(stateProvider);
            final progress = state.progress;
            final isPurging = state.isPurging;
            final error = state.error;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                if (error != null)
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  )
                else if (progress == 1 && !isPurging)
                  Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '100%',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 5,
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                if (error != null)
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  )
                else
                  Text(
                    context.messages.maintenancePurgeAudioModels,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
