import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class TranscriptionResult {
  final String text;
  final String language;
  final List<TranscriptionSegment> segments;

  TranscriptionResult({
    required this.text,
    required this.language,
    required this.segments,
  });

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) {
    return TranscriptionResult(
      text: json['text'] as String,
      language: json['language'] as String,
      segments: (json['segments'] as List)
          .map((e) => TranscriptionSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TranscriptionSegment {
  final int id;
  final double start;
  final double end;
  final String text;

  TranscriptionSegment({
    required this.id,
    required this.start,
    required this.end,
    required this.text,
  });

  factory TranscriptionSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptionSegment(
      id: json['id'] as int,
      start: json['start'] as double,
      end: json['end'] as double,
      text: json['text'] as String,
    );
  }
}

class FastWhisperService {
  final String baseUrl;
  final http.Client _client;

  FastWhisperService({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<TranscriptionResult> transcribe(String audioFilePath) async {
    final file = File(audioFilePath);
    if (!await file.exists()) {
      throw FileSystemException('Audio file not found', audioFilePath);
    }

    final bytes = await file.readAsBytes();
    final base64Audio = base64Encode(bytes);

    final response = await _client.post(
      Uri.parse('$baseUrl/transcribe'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'audio': base64Audio,
        'model': 'base', // Can be configured based on available models
        'language': 'auto', // Auto-detect language
      }),
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to transcribe audio: ${response.statusCode} ${response.reasonPhrase}',
      );
    }

    final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
    return TranscriptionResult.fromJson(jsonResponse);
  }

  void dispose() {
    _client.close();
  }
}
