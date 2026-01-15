import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/services/whisper_model_service.dart';
import 'package:path/path.dart' as path;

/// Configuration for the whisper server
class WhisperServerConfig {
  const WhisperServerConfig({
    this.host = '127.0.0.1',
    this.port = 8084,
    this.startupTimeoutSeconds = 30,
    this.healthCheckIntervalSeconds = 5,
  });

  final String host;
  final int port;
  final int startupTimeoutSeconds;
  final int healthCheckIntervalSeconds;

  String get baseUrl => 'http://$host:$port';
  String get healthEndpoint => '$baseUrl/health';
}

/// Status of the whisper server
enum WhisperServerStatus {
  /// Server is not running
  stopped,

  /// Server is starting up
  starting,

  /// Server is running and healthy
  running,

  /// Server failed to start or crashed
  error,
}

/// Result of a server operation
class WhisperServerResult {
  const WhisperServerResult({
    required this.success,
    this.message,
    this.error,
  });

  final bool success;
  final String? message;
  final Object? error;
}

/// Manages the lifecycle of the local whisper.cpp server
///
/// This service handles:
/// - Starting and stopping the whisper-server process
/// - Health checks to ensure the server is responsive
/// - Model path resolution
///
/// The server is started as a child process and communicates via HTTP.
class WhisperServerManager {
  WhisperServerManager({
    WhisperServerConfig? config,
    WhisperModelService? modelService,
    http.Client? httpClient,
  })  : _config = config ?? const WhisperServerConfig(),
        _modelService = modelService ?? WhisperModelService(),
        _httpClient = httpClient ?? http.Client();

  final WhisperServerConfig _config;
  final WhisperModelService _modelService;
  final http.Client _httpClient;

  Process? _serverProcess;
  WhisperServerStatus _status = WhisperServerStatus.stopped;
  String? _currentModel;
  final _statusController = StreamController<WhisperServerStatus>.broadcast();

  /// Current status of the server
  WhisperServerStatus get status => _status;

  /// Stream of status changes
  Stream<WhisperServerStatus> get statusStream => _statusController.stream;

  /// The currently loaded model name
  String? get currentModel => _currentModel;

  /// Server configuration
  WhisperServerConfig get config => _config;

  /// Ensures the server is running with the specified model
  ///
  /// If the server is already running with the same model, returns immediately.
  /// If running with a different model, restarts with the new model.
  /// If not running, starts the server.
  ///
  /// Returns a [WhisperServerResult] indicating success or failure.
  Future<WhisperServerResult> ensureRunning({
    String modelName = 'ggml-base.en.bin',
  }) async {
    // If already running with the same model, just verify health
    if (_status == WhisperServerStatus.running && _currentModel == modelName) {
      final isHealthy = await _checkHealth();
      if (isHealthy) {
        return const WhisperServerResult(
          success: true,
          message: 'Server already running',
        );
      }
      // Server is unhealthy, need to restart
      await stop();
    }

    // If running with different model, stop first
    if (_status == WhisperServerStatus.running && _currentModel != modelName) {
      await stop();
    }

    return start(modelName: modelName);
  }

  /// Starts the whisper server with the specified model
  ///
  /// The model will be downloaded if not present locally.
  Future<WhisperServerResult> start({
    String modelName = 'ggml-base.en.bin',
  }) async {
    if (_status == WhisperServerStatus.starting) {
      return const WhisperServerResult(
        success: false,
        message: 'Server is already starting',
      );
    }

    _setStatus(WhisperServerStatus.starting);

    try {
      // Ensure the model is available
      final modelResult = await _modelService.ensureModelAvailable(modelName);
      if (!modelResult.success) {
        _setStatus(WhisperServerStatus.error);
        return WhisperServerResult(
          success: false,
          message: 'Failed to prepare model: ${modelResult.message}',
          error: modelResult.error,
        );
      }

      final modelPath = modelResult.modelPath!;

      // Find the server binary
      final serverPath = await _findServerBinary();
      if (serverPath == null) {
        _setStatus(WhisperServerStatus.error);
        return const WhisperServerResult(
          success: false,
          message: 'whisper-server binary not found',
        );
      }

      developer.log(
        'Starting whisper server with model: $modelPath',
        name: 'WhisperServerManager',
      );

      // Start the server process
      _serverProcess = await Process.start(
        serverPath,
        [
          '--model',
          modelPath,
          '--host',
          _config.host,
          '--port',
          '${_config.port}',
          '--threads',
          '${Platform.numberOfProcessors}',
        ],
        mode: ProcessStartMode.detachedWithStdio,
      );

      // Listen for process output for debugging
      _serverProcess!.stdout.transform(utf8.decoder).listen((data) {
        developer.log(
          'whisper-server stdout: $data',
          name: 'WhisperServerManager',
        );
      });

      _serverProcess!.stderr.transform(utf8.decoder).listen((data) {
        developer.log(
          'whisper-server stderr: $data',
          name: 'WhisperServerManager',
          level: 900,
        );
      });

      // Wait for the server to become healthy
      final healthy = await _waitForHealthy();
      if (!healthy) {
        await stop();
        return const WhisperServerResult(
          success: false,
          message: 'Server failed to become healthy within timeout',
        );
      }

      _currentModel = modelName;
      _setStatus(WhisperServerStatus.running);

      developer.log(
        'Whisper server started successfully on ${_config.baseUrl}',
        name: 'WhisperServerManager',
      );

      return const WhisperServerResult(
        success: true,
        message: 'Server started successfully',
      );
    } catch (e, stackTrace) {
      developer.log(
        'Failed to start whisper server: $e',
        name: 'WhisperServerManager',
        error: e,
        stackTrace: stackTrace,
      );
      _setStatus(WhisperServerStatus.error);
      return WhisperServerResult(
        success: false,
        message: 'Failed to start server: $e',
        error: e,
      );
    }
  }

  /// Stops the whisper server
  Future<void> stop() async {
    if (_serverProcess != null) {
      developer.log(
        'Stopping whisper server',
        name: 'WhisperServerManager',
      );

      _serverProcess!.kill();

      // Wait a bit for graceful shutdown
      await Future<void>.delayed(const Duration(seconds: 2));

      // Force kill if still running
      try {
        _serverProcess!.kill(ProcessSignal.sigkill);
      } catch (_) {
        // Process may have already exited
      }

      _serverProcess = null;
    }

    _currentModel = null;
    _setStatus(WhisperServerStatus.stopped);
  }

  /// Checks if the server is healthy
  Future<bool> isHealthy() => _checkHealth();

  /// Finds the whisper-server binary
  ///
  /// Searches in common locations:
  /// - /app/bin/whisper-server (Flatpak)
  /// - Adjacent to the executable
  /// - In PATH
  Future<String?> _findServerBinary() async {
    final candidates = <String>[
      // Flatpak location
      '/app/bin/whisper-server',
      // Next to the app executable
      path.join(
        path.dirname(Platform.resolvedExecutable),
        'whisper-server',
      ),
      // Development location (if whisper.cpp is built locally)
      path.join(
        Directory.current.path,
        'whisper_server',
        'whisper-server',
      ),
    ];

    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        developer.log(
          'Found whisper-server at: $candidate',
          name: 'WhisperServerManager',
        );
        return candidate;
      }
    }

    // Try to find in PATH
    try {
      final result = await Process.run('which', ['whisper-server']);
      if (result.exitCode == 0) {
        final serverPath = (result.stdout as String).trim();
        if (serverPath.isNotEmpty) {
          developer.log(
            'Found whisper-server in PATH: $serverPath',
            name: 'WhisperServerManager',
          );
          return serverPath;
        }
      }
    } catch (_) {
      // 'which' command not available (Windows)
    }

    developer.log(
      'whisper-server binary not found',
      name: 'WhisperServerManager',
      level: 900,
    );
    return null;
  }

  /// Waits for the server to become healthy
  Future<bool> _waitForHealthy() async {
    final deadline = DateTime.now().add(
      Duration(seconds: _config.startupTimeoutSeconds),
    );

    while (DateTime.now().isBefore(deadline)) {
      if (await _checkHealth()) {
        return true;
      }
      await Future<void>.delayed(
        Duration(seconds: _config.healthCheckIntervalSeconds),
      );
    }

    return false;
  }

  /// Checks the server health endpoint
  Future<bool> _checkHealth() async {
    try {
      final response = await _httpClient
          .get(Uri.parse(_config.healthEndpoint))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void _setStatus(WhisperServerStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
    }
  }

  /// Disposes of resources
  void dispose() {
    stop();
    _statusController.close();
    _httpClient.close();
  }
}
