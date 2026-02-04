// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_plan_voice_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for voice-based day planning.
///
/// Listens to [ChatRecorderController] for completed transcripts and
/// processes them through [DayPlanVoiceService] to execute day plan actions.
///
/// Benefits of this approach:
/// - Avoids duplicating recording/transcription logic
/// - `ChatRecorderController` is battle-tested with proper race condition handling
/// - Separation of concerns: recording vs. LLM processing
/// - Easier to test each component independently

@ProviderFor(DayPlanVoiceController)
final dayPlanVoiceControllerProvider = DayPlanVoiceControllerFamily._();

/// Controller for voice-based day planning.
///
/// Listens to [ChatRecorderController] for completed transcripts and
/// processes them through [DayPlanVoiceService] to execute day plan actions.
///
/// Benefits of this approach:
/// - Avoids duplicating recording/transcription logic
/// - `ChatRecorderController` is battle-tested with proper race condition handling
/// - Separation of concerns: recording vs. LLM processing
/// - Easier to test each component independently
final class DayPlanVoiceControllerProvider
    extends $NotifierProvider<DayPlanVoiceController, DayPlanLlmState> {
  /// Controller for voice-based day planning.
  ///
  /// Listens to [ChatRecorderController] for completed transcripts and
  /// processes them through [DayPlanVoiceService] to execute day plan actions.
  ///
  /// Benefits of this approach:
  /// - Avoids duplicating recording/transcription logic
  /// - `ChatRecorderController` is battle-tested with proper race condition handling
  /// - Separation of concerns: recording vs. LLM processing
  /// - Easier to test each component independently
  DayPlanVoiceControllerProvider._(
      {required DayPlanVoiceControllerFamily super.from,
      required DateTime super.argument})
      : super(
          retry: null,
          name: r'dayPlanVoiceControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dayPlanVoiceControllerHash();

  @override
  String toString() {
    return r'dayPlanVoiceControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  DayPlanVoiceController create() => DayPlanVoiceController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DayPlanLlmState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DayPlanLlmState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DayPlanVoiceControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dayPlanVoiceControllerHash() =>
    r'8d8cb019bf07a312de799f8e428c509d96af3150';

/// Controller for voice-based day planning.
///
/// Listens to [ChatRecorderController] for completed transcripts and
/// processes them through [DayPlanVoiceService] to execute day plan actions.
///
/// Benefits of this approach:
/// - Avoids duplicating recording/transcription logic
/// - `ChatRecorderController` is battle-tested with proper race condition handling
/// - Separation of concerns: recording vs. LLM processing
/// - Easier to test each component independently

final class DayPlanVoiceControllerFamily extends $Family
    with
        $ClassFamilyOverride<DayPlanVoiceController, DayPlanLlmState,
            DayPlanLlmState, DayPlanLlmState, DateTime> {
  DayPlanVoiceControllerFamily._()
      : super(
          retry: null,
          name: r'dayPlanVoiceControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Controller for voice-based day planning.
  ///
  /// Listens to [ChatRecorderController] for completed transcripts and
  /// processes them through [DayPlanVoiceService] to execute day plan actions.
  ///
  /// Benefits of this approach:
  /// - Avoids duplicating recording/transcription logic
  /// - `ChatRecorderController` is battle-tested with proper race condition handling
  /// - Separation of concerns: recording vs. LLM processing
  /// - Easier to test each component independently

  DayPlanVoiceControllerProvider call({
    required DateTime date,
  }) =>
      DayPlanVoiceControllerProvider._(argument: date, from: this);

  @override
  String toString() => r'dayPlanVoiceControllerProvider';
}

/// Controller for voice-based day planning.
///
/// Listens to [ChatRecorderController] for completed transcripts and
/// processes them through [DayPlanVoiceService] to execute day plan actions.
///
/// Benefits of this approach:
/// - Avoids duplicating recording/transcription logic
/// - `ChatRecorderController` is battle-tested with proper race condition handling
/// - Separation of concerns: recording vs. LLM processing
/// - Easier to test each component independently

abstract class _$DayPlanVoiceController extends $Notifier<DayPlanLlmState> {
  late final _$args = ref.$arg as DateTime;
  DateTime get date => _$args;

  DayPlanLlmState build({
    required DateTime date,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<DayPlanLlmState, DayPlanLlmState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<DayPlanLlmState, DayPlanLlmState>,
        DayPlanLlmState,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              date: _$args,
            ));
  }
}
