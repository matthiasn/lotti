/// Test audio data and utilities for Gemma integration tests
///
/// Provides sample audio data in various formats for testing transcription
/// workflows without requiring actual audio files.
class TestAudioData {
  // Audio Type Constants
  static const String wavType = 'wav';
  static const String mp3Type = 'mp3';
  static const String m4aType = 'm4a';
  static const String longType = 'long';
  static const String corruptedType = 'corrupted';
  static const String emptyType = 'empty';

  // Audio Format Constants
  static const String wavFormat = 'wav';
  static const String mp3Format = 'mp3';
  static const String m4aFormat = 'm4a';
  static const String flacFormat = 'flac';
  static const String oggFormat = 'ogg';
  static const String webmFormat = 'webm';

  // MIME Type Constants
  static const String wavMimeType = 'audio/wav';
  static const String mp3MimeType = 'audio/mpeg';
  static const String m4aMimeType = 'audio/mp4';
  static const String flacMimeType = 'audio/flac';
  static const String oggMimeType = 'audio/ogg';
  static const String webmMimeType = 'audio/webm';
  static const String defaultMimeType = 'application/octet-stream';

  // Metadata Keys
  static const String formatKey = 'format';
  static const String durationKey = 'duration_seconds';
  static const String sampleRateKey = 'sample_rate';
  static const String channelsKey = 'channels';
  static const String bitDepthKey = 'bit_depth';
  static const String bitrateKey = 'bitrate';
  static const String codecKey = 'codec';

  // Audio Specifications
  static const double shortDuration = 1;
  static const double longDuration = 30;
  static const int standardSampleRate = 44100;
  static const int lowSampleRate = 16000;
  static const int monoChannels = 1;
  static const int stereoChannels = 2;
  static const int standardBitDepth = 16;
  static const int standardBitrate = 128;
  static const String aacCodec = 'aac';

  // File Size Constants
  static const double defaultMaxSizeMB = 25;
  static const int bytesPerKB = 1024;
  static const int bytesPerMB = 1024 * 1024;
  static const double base64Overhead = 4.0 / 3.0; // Base64 encoding overhead
  static const int base64MaxPaddingChars = 2;

  // Default Messages
  static const String defaultTranscriptionResult =
      'Default transcription result.';
  static const String defaultTranscriptionPrompt =
      'Transcribe this audio clearly and accurately.';

  // Pattern for audio data generation
  static const String wavHeaderPattern = 'UklGRiQAAABXQVZFZm10IBAAAAABAAEA';

  /// Sample base64-encoded WAV audio data (short silence)
  static const String shortSilenceWav =
      'UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+DyvmEZBStX2/LKdygAzVlQSwAAwAD+/9Xr6t5h';

  /// Sample base64-encoded MP3 audio data (short silence)
  static const String shortSilenceMp3 =
      '/+MYxAAAAANIAAAAAExBTUUzLjk4LjIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

  /// Sample base64-encoded M4A audio data header
  static const String shortSilenceM4a =
      'AAAAIGZ0eXBNNEEgAAACAGlzb21pc28yYXZjMW1wNDEAAAAIZnJlZQAACKBtZGF0AAAC';

  /// Longer audio sample for chunking tests
  static const String longAudioSample = '''
UklGRsoDAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YaYDAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
''';

  /// Corrupted audio data for error testing
  static const String corruptedAudio = 'INVALID_BASE64_DATA_CORRUPTED';

  /// Empty audio data
  static const String emptyAudio = '';

  /// Audio metadata for testing
  static const Map<String, Map<String, dynamic>> audioMetadata = {
    'shortSilenceWav': {
      formatKey: wavFormat,
      durationKey: shortDuration,
      sampleRateKey: lowSampleRate,
      channelsKey: monoChannels,
      bitDepthKey: standardBitDepth,
    },
    'shortSilenceMp3': {
      formatKey: mp3Format,
      durationKey: shortDuration,
      sampleRateKey: standardSampleRate,
      channelsKey: stereoChannels,
      bitrateKey: standardBitrate,
    },
    'shortSilenceM4a': {
      formatKey: m4aFormat,
      durationKey: shortDuration,
      sampleRateKey: standardSampleRate,
      channelsKey: stereoChannels,
      codecKey: aacCodec,
    },
    'longAudioSample': {
      formatKey: wavFormat,
      durationKey: longDuration,
      sampleRateKey: standardSampleRate,
      channelsKey: monoChannels,
      bitDepthKey: standardBitDepth,
    },
  };

  /// Expected transcription results for test audio
  static const Map<String, String> expectedTranscriptions = {
    'shortSilenceWav': 'This is a test transcription of a short audio clip.',
    'shortSilenceMp3': 'MP3 audio transcription result.',
    'shortSilenceM4a': 'M4A audio format transcription.',
    'longAudioSample':
        'This is a longer transcription that would result from processing a 30-second audio file with multiple chunks.',
    'corruptedAudio': '', // Should fail
    'emptyAudio': '', // Should fail
  };

  /// Test prompts for context-aware transcription
  static const Map<String, String> testPrompts = {
    'meeting_context':
        'Context: This audio is from a team meeting about project deadlines.',
    'interview_context':
        'Context: This is an interview recording with a job candidate.',
    'lecture_context':
        'Context: This audio contains educational content from a university lecture.',
    'phone_call': 'Context: This is a phone conversation recording.',
    'dictation':
        'Context: This is dictated text that should be transcribed verbatim.',
  };

  /// Get audio data by type
  static String getAudioData(String type) {
    switch (type) {
      case wavType:
        return shortSilenceWav;
      case mp3Type:
        return shortSilenceMp3;
      case m4aType:
        return shortSilenceM4a;
      case longType:
        return longAudioSample;
      case corruptedType:
        return corruptedAudio;
      case emptyType:
        return emptyAudio;
      default:
        return shortSilenceWav;
    }
  }

  /// Get expected transcription for audio type
  static String getExpectedTranscription(String type) {
    return expectedTranscriptions[type] ?? defaultTranscriptionResult;
  }

  /// Get audio metadata
  static Map<String, dynamic>? getMetadata(String type) {
    return audioMetadata[type];
  }

  /// Get test prompt by context
  static String getTestPrompt(String context) {
    return testPrompts[context] ?? defaultTranscriptionPrompt;
  }

  /// Validate base64 audio data format
  static bool isValidBase64(String data) {
    if (data.isEmpty) return false;

    try {
      // Basic regex check for base64 format
      final base64Regex = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');
      return base64Regex.hasMatch(data);
    } catch (e) {
      return false;
    }
  }

  /// Calculate estimated file size for audio data
  static double estimateFileSizeMB(String base64Data) {
    if (base64Data.isEmpty) return 0;

    // Base64 encoding increases size by ~33%
    // Each base64 character represents 6 bits, so 4 chars = 3 bytes
    final originalBytes = (base64Data.length * 3) / 4;
    return originalBytes / bytesPerMB; // Convert to MB
  }

  /// Check if audio data should trigger chunking
  static bool shouldChunk(String base64Data,
      {double maxSizeMB = defaultMaxSizeMB}) {
    return estimateFileSizeMB(base64Data) > maxSizeMB;
  }

  /// Generate audio data of specific size for testing
  static String generateAudioData(double targetSizeMB) {
    // Calculate required base64 length
    final targetBytes = (targetSizeMB * bytesPerMB).round();
    final base64Length = (targetBytes * base64Overhead).round();

    // Generate repeating pattern to reach target size
    final repetitions = (base64Length / wavHeaderPattern.length).ceil();

    final result = List.generate(repetitions, (_) => wavHeaderPattern).join();
    return result.substring(0, base64Length);
  }

  /// Audio format validation
  static bool isValidAudioFormat(String format) {
    const supportedFormats = [
      wavFormat,
      mp3Format,
      m4aFormat,
      flacFormat,
      oggFormat,
      webmFormat,
    ];
    return supportedFormats.contains(format.toLowerCase());
  }

  /// Get MIME type for audio format
  static String getMimeType(String format) {
    switch (format.toLowerCase()) {
      case wavFormat:
        return wavMimeType;
      case mp3Format:
        return mp3MimeType;
      case m4aFormat:
        return m4aMimeType;
      case flacFormat:
        return flacMimeType;
      case oggFormat:
        return oggMimeType;
      case webmFormat:
        return webmMimeType;
      default:
        return defaultMimeType;
    }
  }
}
