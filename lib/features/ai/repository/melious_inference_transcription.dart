part of 'melious_inference_repository.dart';

/// Audio transcription transport for Melious: chunked uploads and raw-bytes requests.
extension _MeliousTranscription on MeliousInferenceRepository {
  Stream<CreateChatCompletionStreamResponse> _transcribeAudioUploads({
    required String model,
    required String audioBase64,
    required String baseUrl,
    required String apiKey,
    required String responseFormat,
    List<String>? contextBiasTerms,
    Duration? timeout,
    InferenceImpactCollector? impactCollector,
    void Function(List<AudioTimedSegment>)? onSegments,
  }) {
    var canceled = false;
    final abortTrigger = Completer<void>();
    final incurredImpact = impactCollector ?? InferenceImpactCollector();
    var completedSegments = 0;
    CompletionUsage? usage;
    final timedSegments = <AudioTimedSegment>[];
    late final StreamController<CreateChatCompletionStreamResponse> controller;
    Future<void> run() async {
      try {
        final bytes = base64Decode(audioBase64);
        Future<CreateChatCompletionStreamResponse> upload(
          Uint8List payload,
          String filename,
        ) async {
          if (payload.length >
              MeliousInferenceRepository.maxTranscriptionUploadBytes) {
            throw TranscriptionException(
              'Prepared audio exceeds Melious’s 25 MB upload limit. Use a shorter recording or another transcription provider.',
              provider: MeliousInferenceRepository._providerName,
              statusCode: 413,
            );
          }
          return _transcribeAudioBytes(
            model: model,
            audioBytes: payload,
            filename: filename,
            normalizedBaseUrl: baseUrl,
            normalizedApiKey: apiKey,
            responseFormat: onSegments == null
                ? responseFormat
                : 'verbose_json',
            contextBiasTerms: contextBiasTerms,
            timeout: timeout,
            impactCollector: incurredImpact,
            abortTrigger: abortTrigger.future,
            onSegments: onSegments == null
                ? null
                : (segments) {
                    final offset =
                        completedSegments *
                        transcriptionUploadSegmentDuration.inMilliseconds;
                    if (bytes.length >
                            MeliousInferenceRepository
                                .maxTranscriptionUploadBytes &&
                        segments.last.endMilliseconds >
                            transcriptionUploadSegmentDuration.inMilliseconds) {
                      throw const FormatException(
                        'Timing exceeds its upload part',
                      );
                    }
                    timedSegments.addAll(
                      segments.map(
                        (segment) => segment.copyWith(
                          startMilliseconds: segment.startMilliseconds + offset,
                          endMilliseconds: segment.endMilliseconds + offset,
                        ),
                      ),
                    );
                    if (timedSegments.length > 30000) {
                      throw const FormatException(
                        'Excessive transcript segments',
                      );
                    }
                  },
          ).first;
        }

        if (bytes.length <=
            MeliousInferenceRepository.maxTranscriptionUploadBytes) {
          final result = await upload(bytes, 'audio.m4a');
          if (!canceled) {
            onSegments?.call(timedSegments);
            controller.add(result);
          }
        } else {
          final texts = <String>[];
          CreateChatCompletionStreamResponse? last;
          await for (final file in _audioSegmentEncoder(bytes)) {
            if (canceled) break;
            final payload = await _temporaryFileReader(file);
            if (canceled) break;
            final result = await upload(payload, 'audio.mp3');
            completedSegments++;
            texts.add(result.choices?.first.delta?.content ?? '');
            usage = combineCompletionUsage(usage, result.usage);
            last = result;
            if (canceled) break;
          }
          if (!canceled) {
            if (last == null) {
              throw const FormatException(
                'Audio preparation produced no segments',
              );
            }
            onSegments?.call(timedSegments);
            controller.add(
              last.copyWith(
                choices: [
                  ChatCompletionStreamResponseChoice(
                    delta: ChatCompletionStreamResponseDelta(
                      content: texts.join('\n\n'),
                    ),
                    index: 0,
                  ),
                ],
                usage: usage,
              ),
            );
          }
        }
      } catch (error, stackTrace) {
        if (!canceled) {
          final failure = error is TranscriptionException
              ? error
              : TranscriptionException(
                  'Failed to prepare or transcribe audio. Try another transcription provider or a shorter recording.',
                  provider: MeliousInferenceRepository._providerName,
                  originalError: error,
                );
          controller.addError(
            completedSegments == 0
                ? failure
                : TranscriptionException(
                    failure.message,
                    provider: failure.provider,
                    statusCode: failure.statusCode,
                    originalError: failure.originalError ?? failure,
                    completedSegments: completedSegments,
                    partialUsage: usage,
                    partialImpact: incurredImpact.impact,
                  ),
            stackTrace,
          );
        }
      } finally {
        unawaited(controller.close());
      }
    }

    controller = StreamController<CreateChatCompletionStreamResponse>(
      onListen: () => unawaited(run()),
      onCancel: () {
        canceled = true;
        if (!abortTrigger.isCompleted) abortTrigger.complete();
      },
    );
    return controller.stream;
  }

  Stream<CreateChatCompletionStreamResponse> _transcribeAudioBytes({
    required String model,
    required Uint8List audioBytes,
    required String filename,
    required Future<void> abortTrigger,
    required String normalizedBaseUrl,
    required String normalizedApiKey,
    required String responseFormat,
    List<String>? contextBiasTerms,
    Duration? timeout,
    InferenceImpactCollector? impactCollector,
    void Function(List<AudioTimedSegment>)? onSegments,
  }) {
    return executeTranscription(
      providerName: MeliousInferenceRepository._providerName,
      responseIdPrefix: 'melious-transcription-',
      audioLengthForLog: audioBytes.length,
      timeout: timeout,
      onSuccessResponse: (decoded, response) {
        if (impactCollector != null) {
          final impact = MeliousCallImpact.fromResponseJson(
            decoded,
            costCreditsDecimal: MeliousCallImpact.costDecimalFromResponseBody(
              response.body,
            ),
          );
          if (impact.hasData) {
            impactCollector.impact = MeliousCallImpact.combine(
              impactCollector.impact,
              impact,
            );
          }
        }
        if (onSegments != null) {
          onSegments(parseTimedTranscriptSegments(decoded['segments']));
        }
      },
      sendRequest: (requestTimeout, timeoutErrorMessage) async {
        final uri = MeliousInferenceRepository._buildEndpointUri(
          normalizedBaseUrl,
          'audio/transcriptions',
        );
        final request =
            http.AbortableMultipartRequest(
                'POST',
                uri,
                abortTrigger: abortTrigger,
              )
              // Timing requests must not redirect private audio off HTTPS.
              ..followRedirects = onSegments == null
              ..headers['Authorization'] = 'Bearer $normalizedApiKey'
              ..files.add(
                http.MultipartFile.fromBytes(
                  'file',
                  audioBytes,
                  filename: filename,
                ),
              )
              ..fields['model'] = model
              ..fields['response_format'] = responseFormat;

        final biasTerms = contextBiasTerms
            ?.map((term) => term.trim())
            .where((term) => term.isNotEmpty)
            .take(MeliousInferenceRepository._maxContextBiasTerms)
            .toList(growable: false);
        if (biasTerms != null && biasTerms.isNotEmpty) {
          request.fields['prompt'] = biasTerms.join(', ');
        }

        return httpClient
            .send(request)
            .then(http.Response.fromStream)
            .timeout(
              requestTimeout,
              onTimeout: () {
                throw TranscriptionException(
                  timeoutErrorMessage,
                  provider: MeliousInferenceRepository._providerName,
                  statusCode: httpStatusRequestTimeout,
                );
              },
            );
      },
    );
  }
}
