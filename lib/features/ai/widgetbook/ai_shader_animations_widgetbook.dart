import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lotti/features/ai/ui/animation/ai_state_shader_animation.dart';
import 'package:lotti/features/ai/util/pcm_amplitude.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/widgetbook/widgetbook_helpers.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;
import 'package:record/record.dart' as record;
import 'package:widgetbook/widgetbook.dart';

part 'ai_shader_animation_configs.dart';
part 'ai_shader_animation_use_cases.dart';
part 'ai_shader_animation_recorder_preview.dart';
part 'ai_shader_animation_signal_widgets.dart';

WidgetbookFolder buildAiWidgetbookFolder() {
  return WidgetbookFolder(
    name: 'AI',
    children: [
      buildAiShaderAnimationsWidgetbookComponent(),
    ],
  );
}

WidgetbookComponent buildAiShaderAnimationsWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'State shader animations',
    useCases: [
      WidgetbookUseCase(
        name: 'Voice playground',
        builder: (context) => _VoiceInputOrbUseCase(
          config: _voiceConfigFromKnobs(context),
        ),
      ),
      WidgetbookUseCase(
        name: 'Voice route matrix',
        builder: (context) => _VoiceRouteMatrixUseCase(
          config: _voiceConfigFromKnobs(context),
        ),
      ),
      WidgetbookUseCase(
        name: 'Thinking playground',
        builder: (context) => _ThinkingLineUseCase(
          config: _thinkingConfigFromKnobs(context),
        ),
      ),
      WidgetbookUseCase(
        name: 'Thinking route matrix',
        builder: (context) => _ThinkingRouteMatrixUseCase(
          config: _thinkingConfigFromKnobs(context),
        ),
      ),
      WidgetbookUseCase(
        name: 'Action bar study',
        builder: (context) => _ActionBarStudyUseCase(
          voiceConfig: _voiceConfigFromKnobs(context),
          thinkingConfig: _thinkingConfigFromKnobs(context),
        ),
      ),
    ],
  );
}

@visibleForTesting
const voiceRecorderAmplitudeInterval = Duration(milliseconds: 20);

@visibleForTesting
const voiceRecorderReleaseDbPerSecond = 64.0;

@visibleForTesting
double applyVoiceDbfsEnvelope({
  required double currentDbfs,
  required double targetDbfs,
  required double floorDbfs,
  Duration elapsed = voiceRecorderAmplitudeInterval,
  double releaseDbPerSecond = voiceRecorderReleaseDbPerSecond,
}) {
  final floor = math.min(floorDbfs, -0.001);
  final current = currentDbfs.clamp(floor, 0.0);
  final target = targetDbfs.clamp(floor, 0.0);

  if (target >= current) {
    return target;
  }

  final releaseStep =
      releaseDbPerSecond *
      elapsed.inMicroseconds /
      Duration.microsecondsPerSecond;
  return math.max(target, current - releaseStep);
}
