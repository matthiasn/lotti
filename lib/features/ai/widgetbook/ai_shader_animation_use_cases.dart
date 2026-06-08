part of 'ai_shader_animations_widgetbook.dart';

class _VoiceInputOrbUseCase extends StatelessWidget {
  const _VoiceInputOrbUseCase({required this.config});

  final _VoiceShaderConfig config;

  @override
  Widget build(BuildContext context) {
    return _WidgetbookCanvas(
      child: Center(
        child: _VoiceRecorderDrivenPreview(config: config),
      ),
    );
  }
}

class _ThinkingLineUseCase extends StatelessWidget {
  const _ThinkingLineUseCase({required this.config});

  final _ThinkingShaderConfig config;

  @override
  Widget build(BuildContext context) {
    return _WidgetbookCanvas(
      child: Center(
        child: AiThinkingLineShader(
          width: config.width,
          height: config.height,
          speed: config.speed,
          amplitude: config.amplitude,
          randomness: config.randomness,
          lineCount: config.lineCount,
          pulse: config.pulse,
          route: config.route,
          primaryColor: config.primaryColor,
          secondaryColor: config.secondaryColor,
          backgroundColor: config.backgroundColor,
          semanticsLabel: 'AI thinking shader preview',
        ),
      ),
    );
  }
}

class _VoiceRouteMatrixUseCase extends StatelessWidget {
  const _VoiceRouteMatrixUseCase({required this.config});

  final _VoiceShaderConfig config;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;

    return _WidgetbookCanvas(
      child: Wrap(
        spacing: spacing.step8,
        runSpacing: spacing.step7,
        children: [
          for (final route in AiVoiceShaderRoute.values)
            _RoutePreview(
              label: route.label,
              width: 180,
              child: AiVoiceInputShader(
                dbfs: config.manualDbfs,
                dbfsFloor: config.dbfsFloor,
                size: 180,
                speed: config.speed,
                intensity: config.intensity,
                lineDensity: config.lineDensity,
                orbitalMix: config.orbitalMix,
                route: route,
                primaryColor: config.primaryColor,
                secondaryColor: config.secondaryColor,
                backgroundColor: config.backgroundColor,
                semanticsLabel: '${route.label} voice shader preview',
              ),
            ),
        ],
      ),
    );
  }
}

class _ThinkingRouteMatrixUseCase extends StatelessWidget {
  const _ThinkingRouteMatrixUseCase({required this.config});

  final _ThinkingShaderConfig config;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;

    return _WidgetbookCanvas(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final route in AiThinkingShaderRoute.values) ...[
            _RoutePreview(
              label: route.label,
              width: config.width,
              child: AiThinkingLineShader(
                width: config.width,
                height: config.height,
                speed: config.speed,
                amplitude: config.amplitude,
                randomness: config.randomness,
                lineCount: config.lineCount,
                pulse: config.pulse,
                route: route,
                primaryColor: config.primaryColor,
                secondaryColor: config.secondaryColor,
                backgroundColor: config.backgroundColor,
                semanticsLabel: '${route.label} thinking shader preview',
              ),
            ),
            SizedBox(height: spacing.step5),
          ],
        ],
      ),
    );
  }
}

class _ActionBarStudyUseCase extends StatelessWidget {
  const _ActionBarStudyUseCase({
    required this.voiceConfig,
    required this.thinkingConfig,
  });

  final _VoiceShaderConfig voiceConfig;
  final _ThinkingShaderConfig thinkingConfig;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;

    return _WidgetbookCanvas(
      child: WidgetbookViewport(
        width: 720,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.colors.background.level02,
            borderRadius: BorderRadius.circular(tokens.radii.l),
            border: Border.all(color: tokens.colors.decorative.level01),
          ),
          child: Padding(
            padding: EdgeInsets.all(spacing.step5),
            child: Row(
              children: [
                _VoiceRecorderDrivenPreview(
                  config: _VoiceShaderConfig(
                    useLiveRecorder: false,
                    usePcmStreamCapture: voiceConfig.usePcmStreamCapture,
                    useRecorderVoiceProcessing:
                        voiceConfig.useRecorderVoiceProcessing,
                    manualDbfs: voiceConfig.manualDbfs,
                    dbfsFloor: voiceConfig.dbfsFloor,
                    size: math.min(voiceConfig.size, 132),
                    speed: voiceConfig.speed,
                    intensity: voiceConfig.intensity,
                    lineDensity: voiceConfig.lineDensity,
                    orbitalMix: voiceConfig.orbitalMix,
                    route: voiceConfig.route,
                    primaryColor: voiceConfig.primaryColor,
                    secondaryColor: voiceConfig.secondaryColor,
                    backgroundColor: voiceConfig.backgroundColor,
                  ),
                  compact: true,
                ),
                SizedBox(width: spacing.step5),
                Expanded(
                  child: AiThinkingLineShader(
                    width: double.infinity,
                    height: thinkingConfig.height,
                    speed: thinkingConfig.speed,
                    amplitude: thinkingConfig.amplitude,
                    randomness: thinkingConfig.randomness,
                    lineCount: thinkingConfig.lineCount,
                    pulse: thinkingConfig.pulse,
                    route: thinkingConfig.route,
                    primaryColor: thinkingConfig.primaryColor,
                    secondaryColor: thinkingConfig.secondaryColor,
                    backgroundColor: thinkingConfig.backgroundColor,
                    semanticsLabel: 'AI thinking shader action bar preview',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
