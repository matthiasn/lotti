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
      initialValue: 0.78,
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
      initialValue: 0.82,
      max: 2.5,
      divisions: 50,
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
      initialValue: 0.64,
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

class _VoiceRecorderDrivenPreview extends StatefulWidget {
  const _VoiceRecorderDrivenPreview({
    required this.config,
    this.compact = false,
  });

  final _VoiceShaderConfig config;
  final bool compact;

  @override
  State<_VoiceRecorderDrivenPreview> createState() =>
      _VoiceRecorderDrivenPreviewState();
}

class _VoiceRecorderDrivenPreviewState
    extends State<_VoiceRecorderDrivenPreview> {
  static const _defaultInputDeviceId = '__default__';
  static const _amplitudeInterval = Duration(milliseconds: 40);

  final record.AudioRecorder _recorder = record.AudioRecorder();
  StreamSubscription<Uint8List>? _streamSubscription;
  Timer? _amplitudeTimer;
  final Stopwatch _amplitudeThrottle = Stopwatch();
  String? _tempRecordingPath;

  var _inputDevices = <record.InputDevice>[];
  String _selectedInputDeviceId = _defaultInputDeviceId;
  bool _isLoadingInputDevices = false;
  bool _isRecording = false;
  bool _isStarting = false;
  double _liveDbfs = -80;
  double _packageDbfs = -80;
  double _pcmDbfs = -80;
  int _pcmChunkCount = 0;
  int _pcmByteCount = 0;
  int _pcmNonZeroSampleCount = 0;
  int _pcmPeakSample = 0;
  double _pcmRmsSample = 0;
  int _amplitudeReadCount = 0;
  String _signalSource = 'idle';
  String? _error;
  String? _deviceError;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInputDevices());
  }

  @override
  void didUpdateWidget(covariant _VoiceRecorderDrivenPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.useLiveRecorder && !widget.config.useLiveRecorder) {
      unawaited(_stopRecorder());
    }
    if (oldWidget.config.useRecorderVoiceProcessing !=
            widget.config.useRecorderVoiceProcessing &&
        _isRecording) {
      unawaited(_restartRecorder());
    }
    if (oldWidget.config.usePcmStreamCapture !=
            widget.config.usePcmStreamCapture &&
        _isRecording) {
      unawaited(_restartRecorder());
    }
  }

  @override
  void dispose() {
    unawaited(_disposeRecorder());
    super.dispose();
  }

  Future<void> _startRecorder() async {
    if (_isRecording || _isStarting) return;
    setState(() {
      _isStarting = true;
      _liveDbfs = widget.config.dbfsFloor;
      _packageDbfs = widget.config.dbfsFloor;
      _pcmDbfs = widget.config.dbfsFloor;
      _pcmChunkCount = 0;
      _pcmByteCount = 0;
      _pcmNonZeroSampleCount = 0;
      _pcmPeakSample = 0;
      _pcmRmsSample = 0;
      _amplitudeReadCount = 0;
      _signalSource = 'starting';
      _error = null;
    });

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!mounted) return;
      if (!hasPermission) {
        setState(() {
          _isStarting = false;
          _error = 'Microphone permission was not granted.';
        });
        return;
      }

      if (widget.config.usePcmStreamCapture) {
        final stream = await _recorder.startStream(_streamRecordConfig);
        _streamSubscription = stream.listen(
          _handlePcmChunk,
          onError: _handleRecorderError,
        );
      } else {
        _tempRecordingPath = _createTempRecordingPath();
        await _recorder.start(_meteredRecordConfig, path: _tempRecordingPath!);
      }
      _amplitudeThrottle.reset();
      _startAmplitudePolling();

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _isStarting = false;
        _signalSource = 'waiting for signal';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isStarting = false;
        _error = 'Recorder failed to start: $error';
      });
    }
  }

  record.RecordConfig get _streamRecordConfig {
    final useVoiceProcessing = widget.config.useRecorderVoiceProcessing;
    return record.RecordConfig(
      encoder: record.AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      device: _selectedInputDevice,
      autoGain: useVoiceProcessing,
      echoCancel: useVoiceProcessing,
      noiseSuppress: useVoiceProcessing,
    );
  }

  record.RecordConfig get _meteredRecordConfig {
    return record.RecordConfig(
      numChannels: 1,
      device: _selectedInputDevice,
    );
  }

  String _createTempRecordingPath() {
    return '${Directory.systemTemp.path}/lotti_widgetbook_voice_meter_'
        '${DateTime.now().microsecondsSinceEpoch}.m4a';
  }

  record.InputDevice? get _selectedInputDevice {
    if (_selectedInputDeviceId == _defaultInputDeviceId) return null;
    for (final device in _inputDevices) {
      if (device.id == _selectedInputDeviceId) return device;
    }
    return null;
  }

  String get _effectiveSelectedInputDeviceId {
    if (_selectedInputDeviceId == _defaultInputDeviceId) {
      return _defaultInputDeviceId;
    }
    final hasSelectedDevice = _inputDevices.any(
      (device) => device.id == _selectedInputDeviceId,
    );
    return hasSelectedDevice ? _selectedInputDeviceId : _defaultInputDeviceId;
  }

  Future<void> _loadInputDevices() async {
    if (!mounted || _isLoadingInputDevices) return;
    setState(() {
      _isLoadingInputDevices = true;
      _deviceError = null;
    });

    try {
      final devices = await _recorder.listInputDevices();
      if (!mounted) return;
      setState(() {
        _inputDevices = devices;
        if (_effectiveSelectedInputDeviceId == _defaultInputDeviceId) {
          _selectedInputDeviceId = _defaultInputDeviceId;
        }
        _isLoadingInputDevices = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingInputDevices = false;
        _deviceError = 'Input device list failed: $error';
      });
    }
  }

  Future<void> _restartRecorder() async {
    if (!_isRecording) return;
    await _stopRecorder();
    if (!mounted || !widget.config.useLiveRecorder) return;
    await _startRecorder();
  }

  Future<void> _stopRecorder() async {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _amplitudeThrottle
      ..stop()
      ..reset();

    try {
      if (await _recorder.isRecording()) {
        final path = await _recorder.stop();
        await _deleteTempRecording(path ?? _tempRecordingPath);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Recorder failed to stop: $error';
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isStarting = false;
      _signalSource = 'idle';
    });
  }

  Future<void> _disposeRecorder() async {
    _amplitudeTimer?.cancel();
    await _streamSubscription?.cancel();
    _amplitudeThrottle.stop();
    try {
      if (await _recorder.isRecording()) {
        final path = await _recorder.stop();
        await _deleteTempRecording(path ?? _tempRecordingPath);
      }
      await _recorder.dispose();
    } catch (_) {}
  }

  Future<void> _deleteTempRecording(String? path) async {
    _tempRecordingPath = null;
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }

  void _startAmplitudePolling() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(
      _amplitudeInterval,
      (_) => unawaited(_pollRecorderAmplitude()),
    );
    unawaited(_pollRecorderAmplitude());
  }

  Future<void> _pollRecorderAmplitude() async {
    if (!mounted || !widget.config.useLiveRecorder) return;

    try {
      final amplitude = await _recorder.getAmplitude();
      if (!mounted || !widget.config.useLiveRecorder) return;

      setState(() {
        _amplitudeReadCount += 1;
        _packageDbfs = _clampDbfs(amplitude.current);
        _updateLiveDbfs();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Amplitude polling failed: $error';
      });
    }
  }

  void _handlePcmChunk(Uint8List chunk) {
    if (!mounted || !widget.config.useLiveRecorder) return;
    final stats = measurePcm16Amplitude(
      chunk,
      floorDbfs: widget.config.dbfsFloor,
    );
    _pcmDbfs = stats.dbfs;
    _pcmNonZeroSampleCount = stats.nonZeroSampleCount;
    _pcmPeakSample = stats.peakSample;
    _pcmRmsSample = stats.rmsSample;

    if (_amplitudeThrottle.isRunning &&
        _amplitudeThrottle.elapsed < _amplitudeInterval) {
      _pcmChunkCount += 1;
      _pcmByteCount += chunk.length;
      return;
    }
    _amplitudeThrottle
      ..reset()
      ..start();

    setState(() {
      _pcmChunkCount += 1;
      _pcmByteCount += chunk.length;
      _updateLiveDbfs();
    });
  }

  void _updateLiveDbfs() {
    if (_pcmDbfs > _packageDbfs) {
      _liveDbfs = _pcmDbfs;
      _signalSource = 'PCM dBFS';
      return;
    }

    _liveDbfs = _packageDbfs;
    if (_amplitudeReadCount > 0) {
      _signalSource = 'package dBFS';
    } else if (_pcmChunkCount > 0) {
      _signalSource = 'PCM dBFS';
    } else {
      _signalSource = 'waiting for signal';
    }
  }

  double _clampDbfs(double dbfs) {
    if (dbfs.isNaN || dbfs.isInfinite) return widget.config.dbfsFloor;
    return dbfs.clamp(widget.config.dbfsFloor, 0.0);
  }

  void _handleRecorderError(Object error) {
    if (!mounted) return;
    setState(() {
      _error = 'Recorder stream failed: $error';
    });
  }

  void _selectInputDevice(String? deviceId) {
    if (deviceId == null || _isRecording || _isStarting) return;
    setState(() {
      _selectedInputDeviceId = deviceId;
    });
  }

  Widget _buildInputDevicePicker(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final textStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Input', style: textStyle),
        SizedBox(width: spacing.step2),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _effectiveSelectedInputDeviceId,
            dropdownColor: tokens.colors.background.level02,
            iconEnabledColor: tokens.colors.text.mediumEmphasis,
            style: textStyle,
            isDense: true,
            onChanged: _isRecording || _isStarting ? null : _selectInputDevice,
            items: [
              const DropdownMenuItem<String>(
                value: _defaultInputDeviceId,
                child: Text('System default'),
              ),
              for (final device in _inputDevices)
                DropdownMenuItem<String>(
                  value: device.id,
                  child: Text(
                    device.label.isEmpty ? device.id : device.label,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String? get _silenceHint {
    if (!_isRecording ||
        !widget.config.usePcmStreamCapture ||
        _pcmChunkCount < 4 ||
        _pcmPeakSample > 0) {
      return null;
    }
    return 'PCM stream contains only zero samples. Try another input device, '
        'or turn PCM stream capture off to use metered mic mode.';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final dbfs = widget.config.useLiveRecorder
        ? _liveDbfs
        : widget.config.manualDbfs;
    final signalMetrics = [
      _SignalMetric(label: 'Level', value: '${dbfs.toStringAsFixed(1)} dBFS'),
      _SignalMetric(
        label: 'Mode',
        value: widget.config.usePcmStreamCapture ? 'PCM stream' : 'metered mic',
      ),
      _SignalMetric(label: 'Source', value: _signalSource),
      _SignalMetric(label: 'Reads', value: '$_amplitudeReadCount'),
      _SignalMetric(label: 'PCM chunks', value: '$_pcmChunkCount'),
      _SignalMetric(label: 'PCM bytes', value: '$_pcmByteCount B'),
      _SignalMetric(
        label: 'Package',
        value: '${_packageDbfs.toStringAsFixed(1)} dBFS',
      ),
      _SignalMetric(label: 'PCM', value: '${_pcmDbfs.toStringAsFixed(1)} dBFS'),
      _SignalMetric(label: 'Peak', value: '$_pcmPeakSample'),
      _SignalMetric(label: 'RMS', value: _pcmRmsSample.toStringAsFixed(0)),
      _SignalMetric(label: 'Non-zero', value: '$_pcmNonZeroSampleCount'),
    ];

    final shader = AiVoiceInputShader(
      dbfs: dbfs,
      dbfsFloor: widget.config.dbfsFloor,
      size: widget.config.size,
      speed: widget.config.speed,
      intensity: widget.config.intensity,
      lineDensity: widget.config.lineDensity,
      orbitalMix: widget.config.orbitalMix,
      route: widget.config.route,
      primaryColor: widget.config.primaryColor,
      secondaryColor: widget.config.secondaryColor,
      backgroundColor: widget.config.backgroundColor,
      semanticsLabel: 'AI voice input shader preview',
    );

    if (widget.compact) {
      return shader;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        shader,
        SizedBox(height: spacing.step5),
        Wrap(
          spacing: spacing.step3,
          runSpacing: spacing.step3,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildInputDevicePicker(context),
            DesignSystemButton(
              label: _isLoadingInputDevices
                  ? 'Loading inputs'
                  : 'Refresh inputs',
              leadingIcon: Icons.refresh_rounded,
              variant: DesignSystemButtonVariant.tertiary,
              onPressed: _isLoadingInputDevices || _isRecording
                  ? null
                  : () => unawaited(_loadInputDevices()),
            ),
            DesignSystemButton(
              label: _isRecording ? 'Stop mic' : 'Start mic',
              leadingIcon: _isRecording
                  ? Icons.stop_rounded
                  : Icons.mic_none_rounded,
              variant: _isRecording
                  ? DesignSystemButtonVariant.danger
                  : DesignSystemButtonVariant.secondary,
              onPressed: !widget.config.useLiveRecorder || _isStarting
                  ? null
                  : _isRecording
                  ? () => unawaited(_stopRecorder())
                  : () => unawaited(_startRecorder()),
            ),
          ],
        ),
        SizedBox(height: spacing.step4),
        SizedBox(
          width: math.max(widget.config.size * 3.4, 520),
          child: _SignalReadoutPanel(metrics: signalMetrics),
        ),
        if (_deviceError != null) ...[
          SizedBox(height: spacing.step3),
          Text(
            _deviceError!,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.alert.error.defaultColor,
            ),
          ),
        ],
        if (_silenceHint != null) ...[
          SizedBox(height: spacing.step3),
          Text(
            _silenceHint!,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
        if (_error != null) ...[
          SizedBox(height: spacing.step3),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.alert.error.defaultColor,
            ),
          ),
        ],
      ],
    );
  }
}

class _SignalMetric {
  const _SignalMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _SignalReadoutPanel extends StatelessWidget {
  const _SignalReadoutPanel({required this.metrics});

  final List<_SignalMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final labelStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final valueStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
      fontFeatures: numericBadgeFontFeatures,
    );
    final rows = <TableRow>[];

    for (var index = 0; index < metrics.length; index += 2) {
      final left = metrics[index];
      final right = index + 1 < metrics.length ? metrics[index + 1] : null;
      rows.add(
        TableRow(
          children: [
            _SignalMetricCell(
              text: left.label,
              style: labelStyle,
              endPadding: spacing.step2,
              bottomPadding: spacing.step2,
            ),
            _SignalMetricCell(
              text: left.value,
              style: valueStyle,
              endPadding: spacing.step6,
              bottomPadding: spacing.step2,
            ),
            _SignalMetricCell(
              text: right?.label,
              style: labelStyle,
              endPadding: spacing.step2,
              bottomPadding: spacing.step2,
            ),
            _SignalMetricCell(
              text: right?.value,
              style: valueStyle,
              bottomPadding: spacing.step2,
            ),
          ],
        ),
      );
    }

    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
        2: IntrinsicColumnWidth(),
        3: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: rows,
    );
  }
}

class _SignalMetricCell extends StatelessWidget {
  const _SignalMetricCell({
    required this.text,
    required this.style,
    this.endPadding,
    this.bottomPadding,
  });

  final String? text;
  final TextStyle style;
  final double? endPadding;
  final double? bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(
        end: endPadding ?? 0,
        bottom: bottomPadding ?? 0,
      ),
      child: Text(
        text ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: style,
      ),
    );
  }
}

class _RoutePreview extends StatelessWidget {
  const _RoutePreview({
    required this.label,
    required this.width,
    required this.child,
  });

  final String label;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          Center(child: child),
        ],
      ),
    );
  }
}

class _WidgetbookCanvas extends StatelessWidget {
  const _WidgetbookCanvas({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DecoratedBox(
      decoration: BoxDecoration(color: tokens.colors.background.level01),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.sectionGap),
        child: child,
      ),
    );
  }
}
