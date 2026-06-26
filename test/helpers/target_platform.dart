import 'package:flutter/foundation.dart';

Future<T> withTargetPlatform<T>(
  TargetPlatform targetPlatform,
  Future<T> Function() body,
) async {
  final previousTargetPlatform = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = targetPlatform;
  try {
    return await body();
  } finally {
    debugDefaultTargetPlatformOverride = previousTargetPlatform;
  }
}
