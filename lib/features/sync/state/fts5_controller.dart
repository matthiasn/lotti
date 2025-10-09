import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/providers/service_providers.dart';

final fts5ControllerProvider =
    NotifierProvider<Fts5Controller, Fts5State>(Fts5Controller.new);

class Fts5State {
  const Fts5State({
    this.progress = 0,
    this.isRecreating = false,
    this.error,
  });

  final double progress;
  final bool isRecreating;
  final String? error;

  Fts5State copyWith({
    double? progress,
    bool? isRecreating,
    String? error,
    bool clearError = false,
  }) {
    return Fts5State(
      progress: progress ?? this.progress,
      isRecreating: isRecreating ?? this.isRecreating,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class Fts5Controller extends Notifier<Fts5State> {
  late final Maintenance _maintenance;

  @override
  Fts5State build() {
    _maintenance = ref.watch(maintenanceProvider);
    return const Fts5State();
  }

  Future<void> recreateFts5() async {
    state = state.copyWith(isRecreating: true, progress: 0, clearError: true);

    try {
      await _maintenance.recreateFts5(
        onProgress: (progress) {
          state = state.copyWith(progress: progress);
        },
      );
    } catch (e) {
      state = state.copyWith(
        isRecreating: false,
        progress: 0,
        error: e.toString(),
      );
      return;
    }
    state = state.copyWith(isRecreating: false);
  }
}
