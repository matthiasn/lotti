/// Starts automatic image analysis for a picture that was just imported.
///
/// The media import paths in `lib/logic` call it after creating an image
/// entry. The AI layer implements it (`AutomaticImageAnalysisTrigger`), and
/// the caller that owns a `Ref` passes that implementation in, so importing a
/// picture does not make `lib/logic` depend on the AI feature.
abstract interface class ImageAnalysisTrigger {
  /// Analyses [imageEntryId] for its subject — [subjectId], defaulting to
  /// [linkedTaskId] — when that subject's profile assigns an image-analysis
  /// skill; otherwise does nothing.
  Future<void> triggerAutomaticImageAnalysis({
    required String imageEntryId,
    String? linkedTaskId,
    String? subjectId,
  });
}
