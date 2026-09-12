import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/state/ai_runtime_settings_controller.dart';
import 'package:lotti/features/system_health/domain/system_health_range.dart';
import 'package:lotti/features/system_health/domain/system_health_report.dart';
import 'package:lotti/features/system_health/service/log_file_reader.dart';
import 'package:lotti/features/system_health/service/log_redactor.dart';
import 'package:lotti/features/system_health/service/system_health_analyzer.dart';
import 'package:lotti/features/system_health/service/system_health_findings_inference.dart';
import 'package:lotti/features/system_health/service/system_health_report_store.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart' as p;

/// The analyzer wired to this device's log folder and inference stack.
///
/// Auto-disposed because the cloud inference repository it wraps is; the
/// controller holds a subscription for the duration of one run.
final Provider<SystemHealthAnalyzer> systemHealthAnalyzerProvider =
    Provider.autoDispose<SystemHealthAnalyzer>(
      (ref) {
        final inference = SystemHealthFindingsInference(
          inferenceRepository: ref.watch(cloudInferenceRepositoryProvider),
          aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
        );
        return SystemHealthAnalyzer(
          reader: LogFileReader(
            logsDirectory: Directory(
              p.join(getDocumentsDirectory().path, 'logs'),
            ),
          ),
          findingsWriter: inference.write,
        );
      },
      name: 'systemHealthAnalyzerProvider',
    );

/// Where generated reports are kept: a folder beside the log files.
final Provider<SystemHealthReportStore> systemHealthReportStoreProvider =
    Provider<SystemHealthReportStore>(
      (ref) => SystemHealthReportStore(
        directory: Directory(
          p.join(getDocumentsDirectory().path, 'logs', 'system_health'),
        ),
      ),
      name: 'systemHealthReportStoreProvider',
    );

/// The thinking model of the default inference profile, or `null` when no
/// default profile is set or its model is not an agentic text model.
///
/// This is the model the page proposes, the same one the AI popup menu
/// would fall back to.
final systemHealthDefaultModelProvider = FutureProvider<AiConfigModel?>(
  (ref) async {
    final profileId = await ref.watch(
      defaultInferenceProfileControllerProvider.future,
    );
    if (profileId == null) return null;
    final options = await ref.watch(agentSetupOptionsProvider.future);
    final profile = options.profiles.firstWhereOrNull(
      (value) => value.id == profileId,
    );
    if (profile == null) return null;
    return options.models.firstWhereOrNull(
      (value) =>
          value.id == profile.thinkingModelId ||
          value.providerModelId == profile.thinkingModelId,
    );
  },
  name: 'systemHealthDefaultModelProvider',
);

final systemHealthControllerProvider =
    NotifierProvider<SystemHealthController, SystemHealthState>(
      SystemHealthController.new,
      name: 'systemHealthControllerProvider',
    );

/// What the page shows: the chosen window and model, and the last outcome.
class SystemHealthState {
  const SystemHealthState({
    this.preset = SystemHealthPreset.last24Hours,
    this.customFirstDay,
    this.customLastDay,
    this.selectedModelId,
    this.useDefaultModel = true,
    this.isRunning = false,
    this.report,
    this.document,
    this.failure,
  });

  final SystemHealthPreset preset;

  /// Bounds for [SystemHealthPreset.custom], as calendar days.
  final DateTime? customFirstDay;
  final DateTime? customLastDay;

  /// An explicit model choice. Ignored while [useDefaultModel] is true.
  final String? selectedModelId;

  /// True until the user picks a model, in which case the default profile's
  /// thinking model is used.
  final bool useDefaultModel;
  final bool isRunning;

  /// The report produced by the last run in this session, with its request
  /// and digest. Null after a restart even when [document] is restored.
  final SystemHealthReport? report;

  /// What the page shows: the last run's report, or the newest saved one.
  final SystemHealthReportDocument? document;

  /// Redacted description of why the last run failed before producing a
  /// report (reading files, resolving flags). Model failures do not land
  /// here — they produce a digest-only report instead.
  final String? failure;

  SystemHealthState copyWith({
    SystemHealthPreset? preset,
    DateTime? customFirstDay,
    DateTime? customLastDay,
    String? selectedModelId,
    bool? useDefaultModel,
    bool? isRunning,
    SystemHealthReport? report,
    SystemHealthReportDocument? document,
    String? failure,
    bool clearFailure = false,
  }) {
    return SystemHealthState(
      preset: preset ?? this.preset,
      customFirstDay: customFirstDay ?? this.customFirstDay,
      customLastDay: customLastDay ?? this.customLastDay,
      selectedModelId: selectedModelId ?? this.selectedModelId,
      useDefaultModel: useDefaultModel ?? this.useDefaultModel,
      isRunning: isRunning ?? this.isRunning,
      report: report ?? this.report,
      document: document ?? this.document,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  /// The window the next run covers, resolved against [now].
  SystemHealthRange rangeAt(DateTime now) {
    if (preset != SystemHealthPreset.custom) {
      return SystemHealthRange.forPreset(preset, now: now);
    }
    final last = customLastDay ?? now;
    final first = customFirstDay ?? last.subtract(const Duration(days: 6));
    return SystemHealthRange.days(firstDay: first, lastDay: last);
  }
}

/// Owns the page's choices and runs the analysis.
///
/// Kept alive rather than auto-disposed so a report survives navigating
/// away and back — the analysis can take a while and the user should not
/// have to run it twice. Across restarts the newest saved report is
/// restored from disk.
class SystemHealthController extends Notifier<SystemHealthState> {
  static const _redactor = LogRedactor();

  @override
  SystemHealthState build() {
    unawaited(_restoreLatest());
    return const SystemHealthState();
  }

  Future<void> _restoreLatest() async {
    final document = await ref
        .read(systemHealthReportStoreProvider)
        .loadLatest();
    if (document == null || !ref.mounted) return;
    // A run that finished first wins; the saved file is only a fallback.
    if (state.document == null) state = state.copyWith(document: document);
  }

  void selectPreset(SystemHealthPreset preset) {
    if (preset == SystemHealthPreset.custom &&
        state.customLastDay == null &&
        state.customFirstDay == null) {
      final now = clock.now();
      final today = DateTime(now.year, now.month, now.day);
      state = state.copyWith(
        preset: preset,
        customFirstDay: today.subtract(const Duration(days: 6)),
        customLastDay: today,
      );
      return;
    }
    state = state.copyWith(preset: preset);
  }

  void setCustomFirstDay(DateTime day) {
    final last = state.customLastDay;
    state = state.copyWith(
      customFirstDay: day,
      customLastDay: last != null && last.isBefore(day) ? day : null,
    );
  }

  void setCustomLastDay(DateTime day) {
    final first = state.customFirstDay;
    state = state.copyWith(
      customLastDay: day,
      customFirstDay: first != null && first.isAfter(day) ? day : null,
    );
  }

  /// Picks an explicit model. Passing the default model's id keeps the
  /// choice explicit; [useDefaultModel] restores following the default.
  void selectModel(String modelId) {
    state = state.copyWith(selectedModelId: modelId, useDefaultModel: false);
  }

  void useDefaultModel() {
    state = state.copyWith(useDefaultModel: true);
  }

  /// Reads the logging-domain flags, resolves the model and runs the
  /// analysis. Concurrent calls while a run is in flight are ignored.
  Future<void> run() async {
    if (state.isRunning) return;
    state = state.copyWith(isRunning: true, clearFailure: true);

    // Hold the auto-disposed analyzer (and the inference repository behind
    // it) for the whole run; a bare read could let it close mid-stream.
    final subscription = ref.listen(systemHealthAnalyzerProvider, (_, _) {});
    try {
      final request = SystemHealthRequest(
        range: state.rangeAt(clock.now()),
        domains: await _enabledDomains(),
        includeSlowQueries: await getIt<JournalDb>().getConfigFlag(
          logSlowQueriesFlag,
        ),
        model: await _resolveModel(),
      );
      final report = await subscription.read().analyze(request);
      final document = await _save(report);
      if (!ref.mounted) return;
      state = state.copyWith(
        isRunning: false,
        report: report,
        document: document,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isRunning: false,
        failure: _redactor.redact(error.toString()),
      );
    } finally {
      subscription.close();
    }
  }

  /// Saving is best effort: a report the user can read beats one lost to a
  /// full disk, so a write failure only costs the path.
  Future<SystemHealthReportDocument> _save(SystemHealthReport report) async {
    try {
      return await ref.read(systemHealthReportStoreProvider).save(report);
    } on FileSystemException {
      return report.toDocument();
    }
  }

  Future<Set<LogDomain>> _enabledDomains() async {
    final db = getIt<JournalDb>();
    final domains = <LogDomain>{};
    for (final domain in LogDomain.values) {
      if (await db.getConfigFlag(domain.flagName)) domains.add(domain);
    }
    return domains;
  }

  Future<AiConfigModel?> _resolveModel() async {
    if (state.useDefaultModel) {
      return ref.read(systemHealthDefaultModelProvider.future);
    }
    final id = state.selectedModelId;
    if (id == null) return null;
    final options = await ref.read(agentSetupOptionsProvider.future);
    return options.models.firstWhereOrNull((value) => value.id == id);
  }
}
