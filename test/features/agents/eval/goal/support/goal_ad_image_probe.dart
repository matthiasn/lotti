/// The image stage of the goal-agent eval: turns passing `create_goal_ad`
/// briefs into real Nano Banana Pro images, so ad *quality* can be judged
/// by a human next to the objective scorecard.
///
/// [composeGoalAdImagePrompt] is the executable form of the ADR 0056
/// boundary: its parameters are the ONLY brief fields that may reach the
/// image provider. Headline, altText, tone, goal context, user data — none
/// of them are even accepted here, so leaking them is a compile error, not
/// a review finding. The production `GoalAdPipeline` graduates this exact
/// function.
library;

import 'dart:io';

import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';

/// Fixed style contract appended by CODE, never authored by the model —
/// derived from the Flux cover-art skill contract. The headline is the ONE
/// piece of text allowed in the image (it is model-authored, part of the
/// leakage-checked tool arguments, and Nano Banana Pro renders type well —
/// all-image ads read too tame without it, per user 2026-08-08); everything
/// else that could carry text stays banned.
const goalAdImageStyleContract =
    'Design this as a striking, high-impact advertising banner with real '
    'ad-agency attitude: dramatic composition, bold saturated color or '
    'stark contrast, confident graphic design, the headline set as '
    'oversized display typography that dominates the layout. Dare an '
    'unexpected visual treatment — this should feel like an award-winning '
    'print ad, not a stock photo. 16:9 aspect ratio, centre-safe. Apart '
    'from the headline and call-to-action, no other readable text: no '
    'additional words, no digits, no logos, no watermarks. No real '
    "people's faces.";

/// Composes the outbound image prompt from the typed visual brief.
///
/// Accepts ONLY the leakage-checked brief fields of `GoalNudgeBrief` — this
/// signature is the privacy boundary (ADR 0056). [headline] is rendered
/// into the image as advertising type; it is still stored on the entity so
/// history and accessibility never depend on pixels.
String composeGoalAdImagePrompt({
  required String sceneConcept,
  String? headline,
  String? cta,
  String? mood,
  String? stylePreset,
}) {
  final buffer = StringBuffer(sceneConcept.trim());
  if (headline != null && headline.trim().isNotEmpty) {
    buffer.write(
      "\nRender exactly this headline as the banner's display "
      'typography: "${headline.trim()}"',
    );
  }
  if (cta != null && cta.trim().isNotEmpty) {
    buffer.write(
      '\nInclude a small call-to-action element reading exactly: '
      '"${cta.trim()}"',
    );
  }
  if (mood != null && mood.trim().isNotEmpty) {
    buffer.write('\nMood: ${mood.trim()}.');
  }
  if (stylePreset != null && stylePreset.trim().isNotEmpty) {
    buffer.write('\nStyle: ${stylePreset.trim()}.');
  }
  buffer.write('\n$goalAdImageStyleContract');
  return buffer.toString();
}

/// Nano Banana Pro on the direct Gemini route (`known_models_data.dart`).
const goalAdImageModelId = 'models/gemini-3-pro-image-preview';

/// Generates one ad image from a brief and writes it next to the eval
/// artifacts. Returns the written file path.
Future<String> generateGoalAdImage({
  required CloudInferenceRepository repository,
  required AiConfigInferenceProvider geminiProvider,
  required String sceneConcept,
  required String outputPath,
  String? headline,
  String? cta,
  String? mood,
  String? stylePreset,
  String model = goalAdImageModelId,
}) async {
  final image = await repository.generateImage(
    prompt: composeGoalAdImagePrompt(
      sceneConcept: sceneConcept,
      headline: headline,
      cta: cta,
      mood: mood,
      stylePreset: stylePreset,
    ),
    model: model,
    provider: geminiProvider,
  );
  final extension = switch (image.mimeType) {
    'image/jpeg' => 'jpg',
    'image/webp' => 'webp',
    _ => 'png',
  };
  final file = File('$outputPath.$extension');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(image.bytes);
  return file.path;
}
