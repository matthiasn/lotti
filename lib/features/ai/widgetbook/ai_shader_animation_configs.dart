part of 'ai_shader_animations_widgetbook.dart';

class _VoiceShaderConfig {
  const _VoiceShaderConfig({
    required this.useLiveRecorder,
    required this.usePcmStreamCapture,
    required this.useRecorderVoiceProcessing,
    required this.manualDbfs,
    required this.dbfsFloor,
    required this.size,
    required this.speed,
    required this.intensity,
    required this.lineDensity,
    required this.orbitalMix,
    required this.route,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
  });

  final bool useLiveRecorder;
  final bool usePcmStreamCapture;
  final bool useRecorderVoiceProcessing;
  final double manualDbfs;
  final double dbfsFloor;
  final double size;
  final double speed;
  final double intensity;
  final double lineDensity;
  final double orbitalMix;
  final AiVoiceShaderRoute route;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
}

class _ThinkingShaderConfig {
  const _ThinkingShaderConfig({
    required this.width,
    required this.height,
    required this.speed,
    required this.amplitude,
    required this.randomness,
    required this.lineCount,
    required this.pulse,
    required this.route,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
  });

  final double width;
  final double height;
  final double speed;
  final double amplitude;
  final double randomness;
  final int lineCount;
  final double pulse;
  final AiThinkingShaderRoute route;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
}

_VoiceShaderConfig _voiceConfigFromKnobs(BuildContext context) {
  final tokens = context.designTokens;
  final primary = tokens.colors.interactive.enabled;
  final secondary = tokens.colors.text.highEmphasis;
  final background = tokens.colors.background.level02.withValues(alpha: 0.10);

  return _VoiceShaderConfig(
    useLiveRecorder: context.knobs.boolean(
      label: 'Voice / use live recorder',
    ),
    usePcmStreamCapture: context.knobs.boolean(
      label: 'Voice / use PCM stream capture',
    ),
    useRecorderVoiceProcessing: context.knobs.boolean(
      label: 'Voice / recorder voice processing',
    ),
    route: context.knobs.object.dropdown(
      label: 'Voice / route',
      options: AiVoiceShaderRoute.values,
      initialOption: AiVoiceShaderRoute.tensionLoop,
      labelBuilder: (route) => route.label,
    ),
    manualDbfs: context.knobs.double.slider(
      label: 'Voice / manual dBFS',
      initialValue: -34,
      min: -80,
      max: 0,
      divisions: 80,
    ),
    dbfsFloor: context.knobs.double.slider(
      label: 'Voice / dBFS floor',
      initialValue: -80,
      min: -96,
      max: -24,
      divisions: 72,
    ),
    size: context.knobs.double.slider(
      label: 'Voice / size',
      initialValue: 168,
      min: 96,
      max: 280,
      divisions: 46,
      precision: 0,
    ),
    speed: context.knobs.double.slider(
      label: 'Voice / speed',
      initialValue: 2,
      max: 2.5,
      divisions: 50,
      precision: 2,
    ),
    intensity: context.knobs.double.slider(
      label: 'Voice / intensity',
      initialValue: 0.82,
      max: 1,
      divisions: 50,
      precision: 2,
    ),
    lineDensity: context.knobs.double.slider(
      label: 'Voice / contour tension',
      initialValue: 24,
      min: 8,
      max: 34,
      divisions: 26,
      precision: 0,
    ),
    orbitalMix: context.knobs.double.slider(
      label: 'Voice / force amount',
      initialValue: 0.72,
      max: 1,
      divisions: 50,
      precision: 2,
    ),
    primaryColor: context.knobs.color(
      label: 'Voice / primary color',
      initialValue: primary,
    ),
    secondaryColor: context.knobs.color(
      label: 'Voice / secondary color',
      initialValue: secondary,
    ),
    backgroundColor: context.knobs.color(
      label: 'Voice / background color',
      initialValue: background.withValues(alpha: 0),
    ),
  );
}

_ThinkingShaderConfig _thinkingConfigFromKnobs(BuildContext context) {
  final tokens = context.designTokens;
  final primary = tokens.colors.interactive.enabled;
  final secondary = tokens.colors.text.highEmphasis;
  final background = tokens.colors.background.level02.withValues(alpha: 0.08);

  return _ThinkingShaderConfig(
    width: context.knobs.double.slider(
      label: 'Thinking / width',
      initialValue: 520,
      min: 240,
      max: 760,
      divisions: 52,
      precision: 0,
    ),
    height: context.knobs.double.slider(
      label: 'Thinking / height',
      initialValue: 64,
      min: 32,
      max: 128,
      divisions: 48,
      precision: 0,
    ),
    speed: context.knobs.double.slider(
      label: 'Thinking / speed',
      initialValue: 3.6,
      max: 5,
      divisions: 80,
      precision: 2,
    ),
    amplitude: context.knobs.double.slider(
      label: 'Thinking / amplitude',
      initialValue: 0.56,
      max: 1,
      divisions: 50,
      precision: 2,
    ),
    randomness: context.knobs.double.slider(
      label: 'Thinking / randomness',
      initialValue: 1,
      max: 1,
      divisions: 50,
      precision: 2,
    ),
    lineCount: context.knobs.int.slider(
      label: 'Thinking / line count',
      initialValue: 3,
      min: 1,
      max: 6,
      divisions: 5,
    ),
    route: context.knobs.object.dropdown(
      label: 'Thinking / route',
      options: AiThinkingShaderRoute.values,
      initialOption: AiThinkingShaderRoute.decoderBars,
      labelBuilder: (route) => route.label,
    ),
    pulse: context.knobs.double.slider(
      label: 'Thinking / pulse',
      initialValue: 0.42,
      max: 1,
      divisions: 50,
      precision: 2,
    ),
    primaryColor: context.knobs.color(
      label: 'Thinking / primary color',
      initialValue: primary,
    ),
    secondaryColor: context.knobs.color(
      label: 'Thinking / secondary color',
      initialValue: secondary,
    ),
    backgroundColor: context.knobs.color(
      label: 'Thinking / background color',
      initialValue: background,
    ),
  );
}
