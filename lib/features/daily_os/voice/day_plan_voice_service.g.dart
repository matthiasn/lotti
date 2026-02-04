// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_plan_voice_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Service that orchestrates voice-based day planning.
///
/// Processes transcribed voice commands through an LLM with function calling
/// to manipulate day plan blocks and tasks.

@ProviderFor(DayPlanVoiceService)
final dayPlanVoiceServiceProvider = DayPlanVoiceServiceProvider._();

/// Service that orchestrates voice-based day planning.
///
/// Processes transcribed voice commands through an LLM with function calling
/// to manipulate day plan blocks and tasks.
final class DayPlanVoiceServiceProvider
    extends $NotifierProvider<DayPlanVoiceService, void> {
  /// Service that orchestrates voice-based day planning.
  ///
  /// Processes transcribed voice commands through an LLM with function calling
  /// to manipulate day plan blocks and tasks.
  DayPlanVoiceServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dayPlanVoiceServiceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dayPlanVoiceServiceHash();

  @$internal
  @override
  DayPlanVoiceService create() => DayPlanVoiceService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$dayPlanVoiceServiceHash() =>
    r'22f3b952e730854df00b6ff87e49823b68067d09';

/// Service that orchestrates voice-based day planning.
///
/// Processes transcribed voice commands through an LLM with function calling
/// to manipulate day plan blocks and tasks.

abstract class _$DayPlanVoiceService extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<void, void>, void, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}
