import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/whats_new/model/whats_new_release.dart';

part 'whats_new_content.freezed.dart';

/// Represents parsed markdown content for a release.
/// The markdown is split into sections by horizontal dividers (---).
@freezed
abstract class WhatsNewContent with _$WhatsNewContent {
  const factory WhatsNewContent({
    /// The release metadata.
    required WhatsNewRelease release,

    /// The header section (title, date) before the first divider.
    required String headerMarkdown,

    /// Content sections split by horizontal dividers.
    /// Each section becomes a swipable page in the modal.
    required List<String> sections,

    /// URL to the banner image, if available.
    String? bannerImageUrl,
  }) = _WhatsNewContent;
}
