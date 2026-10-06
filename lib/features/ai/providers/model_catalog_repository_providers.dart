import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/repository/gemini_models_repository.dart';
import 'package:lotti/features/ai/repository/melious_inference_repository.dart';
import 'package:lotti/features/ai/repository/mistral_inference_repository.dart';
import 'package:lotti/features/ai/repository/omlx_inference_repository.dart';
import 'package:lotti/features/ai/repository/openai_models_repository.dart';
import 'package:lotti/providers/service_providers.dart';

// The repositories the provider settings form fetches live model catalogs
// through. Each is closed when the form no longer watches it.

// Riverpod 3 keeps the concrete auto-dispose provider type internal.
// ignore: specify_nonobvious_property_types
final meliousInferenceRepositoryProvider =
    Provider.autoDispose<MeliousInferenceRepository>((ref) {
      final repository = MeliousInferenceRepository(
        domainLogger: ref.watch(domainLoggerProvider),
      );
      ref.onDispose(repository.close);
      return repository;
    });

// Riverpod 3 keeps the concrete auto-dispose provider type internal.
// ignore: specify_nonobvious_property_types
final omlxInferenceRepositoryProvider =
    Provider.autoDispose<OmlxInferenceRepository>((ref) {
      final repository = OmlxInferenceRepository(
        domainLogger: ref.watch(domainLoggerProvider),
      );
      ref.onDispose(repository.close);
      return repository;
    });

// Riverpod 3 keeps the concrete auto-dispose provider type internal.
// ignore: specify_nonobvious_property_types
final mistralInferenceRepositoryProvider =
    Provider.autoDispose<MistralInferenceRepository>((ref) {
      final repository = MistralInferenceRepository(
        domainLogger: ref.watch(domainLoggerProvider),
      );
      ref.onDispose(repository.close);
      return repository;
    });

// Riverpod 3 keeps the concrete auto-dispose provider type internal.
// ignore: specify_nonobvious_property_types
final geminiModelsRepositoryProvider =
    Provider.autoDispose<GeminiModelsRepository>((ref) {
      final repository = GeminiModelsRepository(
        domainLogger: ref.watch(domainLoggerProvider),
      );
      ref.onDispose(repository.close);
      return repository;
    });

// Riverpod 3 keeps the concrete auto-dispose provider type internal.
// ignore: specify_nonobvious_property_types
final openAiModelsRepositoryProvider =
    Provider.autoDispose<OpenAiModelsRepository>((ref) {
      final repository = OpenAiModelsRepository(
        domainLogger: ref.watch(domainLoggerProvider),
      );
      ref.onDispose(repository.close);
      return repository;
    });
