part of 'ai_shader_animations_widgetbook.dart';

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
  bool _isPollingAmplitude = false;

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
      if (!_isStarting || !widget.config.useLiveRecorder) return;
      if (!hasPermission) {
        setState(() {
          _isStarting = false;
          _error = 'Microphone permission was not granted.';
        });
        return;
      }

      if (widget.config.usePcmStreamCapture) {
        final stream = await _recorder.startStream(_streamRecordConfig);
        if (!mounted || !_isStarting || !widget.config.useLiveRecorder) {
          await _recorder.stop();
          return;
        }
        _streamSubscription = stream.listen(
          _handlePcmChunk,
          onError: _handleRecorderError,
        );
      } else {
        _tempRecordingPath = _createTempRecordingPath();
        await _recorder.start(_meteredRecordConfig, path: _tempRecordingPath!);
        if (!mounted || !_isStarting || !widget.config.useLiveRecorder) {
          final path = _tempRecordingPath;
          await _recorder.stop();
          await _deleteTempRecording(path);
          return;
        }
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
    if (_isStarting) {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      } else {
        _isStarting = false;
      }
    }

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
    _isStarting = false;
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
      await File(path).delete();
    } catch (_) {}
  }

  void _startAmplitudePolling() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(
      voiceRecorderAmplitudeInterval,
      (_) => unawaited(_pollRecorderAmplitude()),
    );
    unawaited(_pollRecorderAmplitude());
  }

  Future<void> _pollRecorderAmplitude() async {
    if (!mounted || !widget.config.useLiveRecorder || _isPollingAmplitude) {
      return;
    }

    _isPollingAmplitude = true;
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
    } finally {
      _isPollingAmplitude = false;
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
        _amplitudeThrottle.elapsed < voiceRecorderAmplitudeInterval) {
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
    late final double targetDbfs;
    if (_pcmDbfs > _packageDbfs) {
      targetDbfs = _pcmDbfs;
      _signalSource = 'PCM dBFS';
    } else {
      targetDbfs = _packageDbfs;
      if (_amplitudeReadCount > 0) {
        _signalSource = 'package dBFS';
      } else if (_pcmChunkCount > 0) {
        _signalSource = 'PCM dBFS';
      } else {
        _signalSource = 'waiting for signal';
      }
    }

    _liveDbfs = applyVoiceDbfsEnvelope(
      currentDbfs: _liveDbfs,
      targetDbfs: targetDbfs,
      floorDbfs: widget.config.dbfsFloor,
    );
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
