import 'package:flutter/foundation.dart';

/// One area the user created in the onboarding category step, offered as a
/// destination for the first captured task. Carried from the category step into
/// the first-task step so the user chooses *which* area the task lands in.
@immutable
class OnboardingCaptureCategory {
  const OnboardingCaptureCategory({required this.id, required this.label});

  final String id;
  final String label;
}
