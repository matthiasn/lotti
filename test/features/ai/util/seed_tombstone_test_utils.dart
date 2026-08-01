abstract final class TestSeedTombstoneIdentities {
  static String profile(String profileId) => 'profile:$profileId';

  static String model({
    required String inferenceProviderId,
    required String providerModelId,
  }) => 'model:$inferenceProviderId:$providerModelId';
}
