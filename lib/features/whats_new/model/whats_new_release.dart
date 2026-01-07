import 'package:freezed_annotation/freezed_annotation.dart';

part 'whats_new_release.freezed.dart';
part 'whats_new_release.g.dart';

/// Represents a single release entry from the remote index.json.
@freezed
abstract class WhatsNewRelease with _$WhatsNewRelease {
  const factory WhatsNewRelease({
    required String version,
    required DateTime date,
    required String title,
    required String folder,
  }) = _WhatsNewRelease;

  factory WhatsNewRelease.fromJson(Map<String, dynamic> json) =>
      _$WhatsNewReleaseFromJson(json);
}
