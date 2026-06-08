import 'package:glados/glados.dart' as glados;

// ---------------------------------------------------------------------------
// Generators for formatAudioDuration property tests
// ---------------------------------------------------------------------------

extension AnyAudioDuration on glados.Any {
  /// A duration in seconds drawn uniformly from [−10000, 400010] to exercise
  /// the negative-clamp and the ≥ 359 999 s cap paths.
  glados.Generator<int> get audioSeconds =>
      glados.any.intInRange(-10000, 400010);
}
